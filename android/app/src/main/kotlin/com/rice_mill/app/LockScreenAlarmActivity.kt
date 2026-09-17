package com.rice_mill.app

import android.animation.ObjectAnimator
import android.animation.PropertyValuesHolder
import android.animation.ValueAnimator
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.util.Log
import android.view.View
import android.view.WindowManager
import android.widget.ImageView
import android.widget.TextView

class LockScreenAlarmActivity : Activity() {

    private lateinit var prefs: SharedPreferences
    private val listener = SharedPreferences.OnSharedPreferenceChangeListener { sharedPreferences, key ->
        if (key == "flutter.alarm_playing" || key == "alarm_playing") {
            val isPlaying = RiceMillApplication.getSafeBoolean(sharedPreferences, key, false)
            if (!isPlaying) {
                Log.d(TAG, "Alarm stopped externally — finishing activity")
                finish()
            }
        }
    }

    companion object {
        private const val TAG = "LockScreenAlarmActivity"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 1. Ensure activity shows over the lock screen and turns the screen on
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        }
        @Suppress("DEPRECATION")
        window.addFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_ALLOW_LOCK_WHILE_SCREEN_ON
        )

        // 2. Block system back/swipe-back gesture on Android 13+ (API 33+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            try {
                onBackInvokedDispatcher.registerOnBackInvokedCallback(
                    android.window.OnBackInvokedDispatcher.PRIORITY_DEFAULT
                ) {
                    // Do nothing to restrict back navigation
                }
            } catch (e: Throwable) {
                e.printStackTrace()
            }
        }

        // 3. WakeLock to force physical screen on immediately
        try {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            @Suppress("DEPRECATION")
            val wakeLock = pm.newWakeLock(
                PowerManager.SCREEN_BRIGHT_WAKE_LOCK or
                PowerManager.ACQUIRE_CAUSES_WAKEUP or
                PowerManager.ON_AFTER_RELEASE,
                "RiceMill:NativeAlarmWakeLock"
            )
            wakeLock.acquire(15000L) // 15 seconds
        } catch (e: Exception) {
            e.printStackTrace()
        }

        setContentView(R.layout.activity_lock_screen_alarm)

        // 4. Read FCM message from Intent or SharedPreferences
        prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        prefs.registerOnSharedPreferenceChangeListener(listener)
        
        val title = intent?.getStringExtra("title")
            ?: prefs.getString("flutter.latest_alarm_title", null)
            ?: prefs.getString("latest_alarm_title", "⚠️ Grid Pulse Alert!")
            ?: "⚠️ Grid Pulse Alert!"

        val body = intent?.getStringExtra("body")
            ?: prefs.getString("flutter.latest_alarm_body", null)
            ?: prefs.getString("latest_alarm_body", "Critical electrical threshold exceeded! Tap to inspect.")
            ?: "Critical electrical threshold exceeded! Tap to inspect."

        val alertId = intent?.getStringExtra("alertId")
            ?: prefs.getString("flutter.latest_alert_id", null)
            ?: prefs.getString("latest_alert_id", "ALARM_ID")
            ?: "ALARM_ID"

        val tvCriticalAlert = findViewById<TextView>(R.id.tvCriticalAlert)
        val tvAlertTitle = findViewById<TextView>(R.id.tvAlertTitle)
        val tvAlertBody = findViewById<TextView>(R.id.tvAlertBody)
        val tvAlertIcon = findViewById<ImageView>(R.id.tvAlertIcon)
        
        tvAlertIcon.outlineProvider = object : android.view.ViewOutlineProvider() {
            override fun getOutline(view: View, outline: android.graphics.Outline) {
                outline.setOval(0, 0, view.width, view.height)
            }
        }
        tvAlertIcon.clipToOutline = true

        tvAlertTitle.text = title
        tvAlertBody.text = body

        // UI Animations
        // CRITICAL ALERT text breathing animation
        if (tvCriticalAlert != null) {
            ObjectAnimator.ofPropertyValuesHolder(
                tvCriticalAlert,
                PropertyValuesHolder.ofFloat("scaleX", 1.0f, 1.2f),
                PropertyValuesHolder.ofFloat("scaleY", 1.0f, 1.2f)
            ).apply {
                duration = 1000
                repeatMode = ValueAnimator.REVERSE
                repeatCount = ValueAnimator.INFINITE
                start()
            }
        }

        // STOP Button Ring Pulse
        val btnStopPulse = findViewById<View>(R.id.btnStopPulse)
        if (btnStopPulse != null) {
            ObjectAnimator.ofPropertyValuesHolder(
                btnStopPulse,
                PropertyValuesHolder.ofFloat("scaleX", 1.0f, 1.3f),
                PropertyValuesHolder.ofFloat("scaleY", 1.0f, 1.3f),
                PropertyValuesHolder.ofFloat("alpha", 1.0f, 0.0f)
            ).apply {
                duration = 1000
                repeatMode = ValueAnimator.RESTART
                repeatCount = ValueAnimator.INFINITE
                start()
            }
        }

        // STOP Button Container Breathing
        val btnStop = findViewById<View>(R.id.btnStopContainer) ?: findViewById<View>(R.id.btnStop)
        if (btnStop != null) {
            ObjectAnimator.ofPropertyValuesHolder(
                btnStop,
                PropertyValuesHolder.ofFloat("scaleX", 1.0f, 1.05f),
                PropertyValuesHolder.ofFloat("scaleY", 1.0f, 1.05f)
            ).apply {
                duration = 800
                repeatMode = ValueAnimator.REVERSE
                repeatCount = ValueAnimator.INFINITE
                start()
            }

            // Handle Stop Button Tap
            btnStop.setOnClickListener {
                Log.d(TAG, "STOP button clicked by user")
                val currentAlertId = intent?.getStringExtra("alertId")
                    ?: prefs.getString("flutter.latest_alert_id", null)
                    ?: prefs.getString("latest_alert_id", "ALARM_ID")
                    ?: "ALARM_ID"
                AlarmHelper.stopAlarm(this, currentAlertId)
                finish()
            }
        }
    }

    // Disable the physical back button so the user MUST hit STOP
    @Suppress("MissingSuperCall")
    override fun onBackPressed() {
        // Must tap STOP
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        }
        @Suppress("DEPRECATION")
        window.addFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_ALLOW_LOCK_WHILE_SCREEN_ON
        )
    }

    override fun onResume() {
        super.onResume()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        }
        @Suppress("DEPRECATION")
        window.addFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_ALLOW_LOCK_WHILE_SCREEN_ON
        )
    }

    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        }
        @Suppress("DEPRECATION")
        window.addFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_ALLOW_LOCK_WHILE_SCREEN_ON
        )
        val title = intent?.getStringExtra("title")
            ?: prefs.getString("flutter.latest_alarm_title", null)
            ?: prefs.getString("latest_alarm_title", "⚠️ Grid Pulse Alert!")
        val body = intent?.getStringExtra("body")
            ?: prefs.getString("flutter.latest_alarm_body", null)
            ?: prefs.getString("latest_alarm_body", "Threshold breached. Tap STOP to acknowledge.")
        val alertId = intent?.getStringExtra("alertId")
            ?: prefs.getString("flutter.latest_alert_id", null)
            ?: prefs.getString("latest_alert_id", "ALARM_ID")
            ?: "ALARM_ID"
        findViewById<TextView>(R.id.tvAlertTitle)?.text = title
        findViewById<TextView>(R.id.tvAlertBody)?.text = body
    }

    override fun onDestroy() {
        if (::prefs.isInitialized) {
            prefs.unregisterOnSharedPreferenceChangeListener(listener)
        }
        super.onDestroy()
    }
}
