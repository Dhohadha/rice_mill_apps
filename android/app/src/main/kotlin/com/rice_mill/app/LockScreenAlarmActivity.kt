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
import android.view.View
import android.view.WindowManager
import android.widget.ImageView
import android.widget.TextView

class LockScreenAlarmActivity : Activity() {

    private lateinit var prefs: SharedPreferences
    private val listener = SharedPreferences.OnSharedPreferenceChangeListener { sharedPreferences, key ->
        if (key == "flutter.alarm_playing") {
            val isPlaying = sharedPreferences.getBoolean(key, false)
            if (!isPlaying) {
                android.util.Log.d("LockScreenAlarmActivity", "Alarm stopped externally — finishing activity")
                finish()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Ensure activity shows over the lock screen and turns the screen on
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        }
        @Suppress("DEPRECATION")
        window.addFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_ALLOW_LOCK_WHILE_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
        )

        // Block system back/swipe-back gesture on Android 13+ (API 33+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            onBackInvokedDispatcher.registerOnBackInvokedCallback(
                android.window.OnBackInvokedDispatcher.PRIORITY_DEFAULT
            ) {
                // Do nothing to restrict back navigation
            }
        }

        // WakeLock to force screen on
        try {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            @Suppress("DEPRECATION")
            val wakeLock = pm.newWakeLock(
                PowerManager.SCREEN_BRIGHT_WAKE_LOCK or
                PowerManager.ACQUIRE_CAUSES_WAKEUP or
                PowerManager.ON_AFTER_RELEASE,
                "RiceMill:NativeAlarmWakeLock"
            )
            wakeLock.acquire(10000L) // 10 seconds
        } catch (e: Exception) {
            e.printStackTrace()
        }

        setContentView(R.layout.activity_lock_screen_alarm)

        // Read FCM message from SharedPreferences
        prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        prefs.registerOnSharedPreferenceChangeListener(listener)
        
        val title = prefs.getString("flutter.latest_alarm_title", "⚠️ Grid Pulse Alert!")
        val body = prefs.getString("flutter.latest_alarm_body", "Threshold breached. Tap STOP to acknowledge.")

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

        // CRITICAL ALERT text breathing animation
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

        // STOP Button Ring Pulse
        val btnStopPulse = findViewById<View>(R.id.btnStopPulse)
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

        // STOP Button Container Breathing
        val btnStop = findViewById<View>(R.id.btnStopContainer)
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
            // Send STOP intent to AlarmSoundService
            val stopIntent = Intent(this, AlarmSoundService::class.java).apply {
                action = AlarmSoundService.ACTION_STOP
            }
            startService(stopIntent)
            
            // Instantly destroy this native screen
            finish()
        }
    }

    // Disable the physical back button so they MUST hit STOP
    @Suppress("MissingSuperCall")
    override fun onBackPressed() {
        // Do nothing! They must press the STOP button.
    }

    override fun onDestroy() {
        if (::prefs.isInitialized) {
            prefs.unregisterOnSharedPreferenceChangeListener(listener)
        }
        super.onDestroy()
    }
}
