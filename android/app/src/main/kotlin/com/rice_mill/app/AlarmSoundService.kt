package com.rice_mill.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.util.Log

class AlarmSoundService : Service() {

    private var mediaPlayer: MediaPlayer? = null
    private val handler = Handler(Looper.getMainLooper())
    private var cycleCount = 0
    private var isRunning = false
    private var wakeLock: PowerManager.WakeLock? = null

    companion object {
        const val ACTION_STOP = "com.rice_mill.app.STOP_ALARM_SERVICE"
        const val NOTIF_ID = 999
        const val ALARM_CHANNEL_ID = "grid_pulse_critical_alarm_v14"
        private const val TAG = "AlarmSoundService"
        private const val MAX_CYCLES = 4
        private const val PLAY_DURATION_MS = 90_000L
        private const val SILENCE_DURATION_MS = 60_000L
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createAlarmNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            Log.d(TAG, "STOP action received — stopping service")
            handleStop()
            return START_NOT_STICKY
        }

        if (!isRunning) {
            Log.d(TAG, "Starting alarm foreground service")
            isRunning = true
            cycleCount = 0

            // 1. Acquire CPU WakeLock so audio loops and doesn't get killed when phone sleeps
            try {
                val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                if (wakeLock == null) {
                    wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "RiceMill:AlarmCpuWakeLock").apply {
                        setReferenceCounted(false)
                        acquire(10 * 60 * 1000L)
                    }
                }
                // Also turn physical screen ON immediately so lock screen activity shows
                @Suppress("DEPRECATION")
                val screenLock = pm.newWakeLock(
                    PowerManager.SCREEN_BRIGHT_WAKE_LOCK or
                    PowerManager.ACQUIRE_CAUSES_WAKEUP or
                    PowerManager.ON_AFTER_RELEASE,
                    "RiceMill:AlarmScreenWakeLock"
                )
                screenLock.acquire(15000L)
            } catch (e: Throwable) {
                Log.e(TAG, "WakeLock acquire error: ${e.message}")
            }

            // 2. Build high-priority notification with full-screen intent
            try {
                val alarmNotification = buildAlarmNotification()
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    startForeground(
                        NOTIF_ID,
                        alarmNotification,
                        android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
                    )
                } else {
                    startForeground(NOTIF_ID, alarmNotification)
                }

                // Post explicitly to NotificationManager to trigger heads-up & full-screen intent dispatch
                val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                nm.notify(NOTIF_ID, alarmNotification)
            } catch (e: Throwable) {
                Log.e(TAG, "Error starting foreground notification: ${e.message}")
            }

            runCycle()

            // 3. Launch LockScreenAlarmActivity directly so the red emergency screen pops up immediately
            try {
                val lockIntent = Intent(this, LockScreenAlarmActivity::class.java).apply {
                    setFlags(
                        Intent.FLAG_ACTIVITY_NEW_TASK or 
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or 
                        Intent.FLAG_ACTIVITY_SINGLE_TOP
                    )
                }
                val options = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                    android.app.ActivityOptions.makeBasic().apply {
                        setPendingIntentBackgroundActivityStartMode(android.app.ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED)
                    }.toBundle()
                } else {
                    null
                }
                startActivity(lockIntent, options)
            } catch (e: Throwable) {
                Log.e(TAG, "Direct startActivity error (fullScreenIntent will handle it): ${e.message}")
            }
        } else {
            // Already running - refresh single notification content
            try {
                val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                nm.notify(NOTIF_ID, buildAlarmNotification())
            } catch (e: Throwable) {
                Log.e(TAG, "Error refreshing notification: ${e.message}")
            }
        }

        return START_STICKY
    }

    private fun runCycle() {
        if (!isRunning) return

        if (cycleCount >= MAX_CYCLES) {
            Log.d(TAG, "Max cycles ($MAX_CYCLES) reached — stopping")
            handleStop()
            return
        }

        cycleCount++
        Log.d(TAG, "Starting cycle $cycleCount / $MAX_CYCLES")

        playAudio()

        // After 90 s: silence the audio
        handler.postDelayed({
            if (isRunning) {
                Log.d(TAG, "90 s elapsed — silencing cycle $cycleCount")
                mediaPlayer?.pause()
                // After 1 min silence: next cycle
                handler.postDelayed({
                    if (isRunning) {
                        runCycle()
                    }
                }, SILENCE_DURATION_MS)
            }
        }, PLAY_DURATION_MS)
    }

    private fun playAudio() {
        try {
            if (mediaPlayer == null) {
                val resId = resources.getIdentifier("alarm", "raw", packageName)
                if (resId == 0) {
                    Log.e(TAG, "alarm.mp3 not found in res/raw")
                    return
                }

                mediaPlayer = MediaPlayer().apply {
                    setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_ALARM)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build()
                    )
                    val afd = resources.openRawResourceFd(resId)
                    setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                    afd.close()
                    isLooping = true
                    prepare()
                }
            }

            mediaPlayer?.start()
            Log.d(TAG, "Audio playing (cycle $cycleCount)")
        } catch (e: Exception) {
            Log.e(TAG, "Error playing audio: ${e.message}", e)
        }
    }

    private fun handleStop() {
        try {
            isRunning = false
            handler.removeCallbacksAndMessages(null)

            try {
                mediaPlayer?.stop()
            } catch (e: Throwable) {
                Log.e(TAG, "Error stopping mediaPlayer: ${e.message}")
            }
            try {
                mediaPlayer?.release()
            } catch (e: Throwable) {
                Log.e(TAG, "Error releasing mediaPlayer: ${e.message}")
            }
            mediaPlayer = null

            try {
                if (wakeLock?.isHeld == true) {
                    wakeLock?.release()
                }
            } catch (e: Throwable) {
                Log.e(TAG, "Error releasing wakeLock: ${e.message}")
            }
            wakeLock = null

            try {
                val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                nm.cancel(NOTIF_ID)
                nm.cancel(889)
                nm.cancel(888)
            } catch (e: Throwable) {
                Log.e(TAG, "Error cancelling notifications: ${e.message}")
            }

            try {
                val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
                prefs.edit()
                    .putBoolean("flutter.alarm_playing", false)
                    .putBoolean("alarm_playing", false)
                    .putBoolean("flutter.isAlarmStopped", true)
                    .putBoolean("isAlarmStopped", true)
                    .apply()
            } catch (e: Throwable) {
                Log.e(TAG, "Error saving prefs: ${e.message}")
            }

            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    stopForeground(STOP_FOREGROUND_REMOVE)
                } else {
                    @Suppress("DEPRECATION")
                    stopForeground(true)
                }
            } catch (e: Throwable) {
                Log.e(TAG, "Error stopForeground: ${e.message}")
            }
            stopSelf()
            Log.d(TAG, "Service stopped cleanly")
        } catch (e: Throwable) {
            Log.e(TAG, "Error in handleStop: ${e.message}")
        }
    }

    override fun onDestroy() {
        handleStop()
        super.onDestroy()
    }

    private fun buildAlarmNotification(): Notification {
        val stopIntent = PendingIntent.getService(
            this, 100,
            Intent(this, AlarmSoundService::class.java).apply { action = ACTION_STOP },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val options = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            android.app.ActivityOptions.makeBasic().apply {
                setPendingIntentBackgroundActivityStartMode(android.app.ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED)
            }.toBundle()
        } else {
            null
        }

        val fullScreenIntent = PendingIntent.getActivity(
            this, 101,
            Intent(this, LockScreenAlarmActivity::class.java).apply {
                setFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or 
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or 
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
                )
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            options
        )

        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val notifTitle = prefs.getString("flutter.latest_alarm_title", null)
            ?: prefs.getString("latest_alarm_title", "⚠️ THRESHOLD BREACH ALERT")
        val notifBody = prefs.getString("flutter.latest_alarm_body", null)
            ?: prefs.getString("latest_alarm_body", "Critical electrical threshold exceeded! Tap to inspect.")

        val actionIcon = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            android.graphics.drawable.Icon.createWithResource(this, android.R.drawable.ic_media_pause)
        } else {
            null
        }

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val builder = Notification.Builder(this, ALARM_CHANNEL_ID)
                .setContentTitle(notifTitle)
                .setContentText(notifBody)
                .setSmallIcon(R.mipmap.launcher_icon)
                .setContentIntent(fullScreenIntent)
                .setFullScreenIntent(fullScreenIntent, true)
                .setOngoing(true)
                .setAutoCancel(false)
                .setVisibility(Notification.VISIBILITY_PUBLIC)
                .setCategory(Notification.CATEGORY_ALARM)
                .setPriority(Notification.PRIORITY_MAX)

            if (actionIcon != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                builder.addAction(
                    Notification.Action.Builder(
                        actionIcon, "🔕 STOP ALARM", stopIntent
                    ).build()
                )
            }
            builder.build()
        } else {
            @Suppress("DEPRECATION")
            android.app.Notification.Builder(this)
                .setContentTitle(notifTitle)
                .setContentText(notifBody)
                .setSmallIcon(R.mipmap.launcher_icon)
                .setContentIntent(fullScreenIntent)
                .setFullScreenIntent(fullScreenIntent, true)
                .setOngoing(true)
                .setAutoCancel(false)
                .setVisibility(Notification.VISIBILITY_PUBLIC)
                .setCategory(Notification.CATEGORY_ALARM)
                .setPriority(Notification.PRIORITY_MAX)
                .addAction(android.R.drawable.ic_media_pause, "🔕 STOP ALARM", stopIntent)
                .build()
        }
    }

    private fun createAlarmNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                val nm = getSystemService(NotificationManager::class.java) ?: return

                val channel = NotificationChannel(
                    ALARM_CHANNEL_ID,
                    "Critical Threshold Alerts",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                    enableVibration(true)
                    vibrationPattern = longArrayOf(0, 500, 200, 500)
                    // Notification channel is silent; AlarmSoundService MediaPlayer handles looping audio exclusively
                    setSound(null, null)
                    setBypassDnd(true)
                }
                nm.createNotificationChannel(channel)
            } catch (e: Throwable) {
                Log.e(TAG, "Error creating notification channel: ${e.message}")
            }
        }
    }
}
