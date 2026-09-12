package com.rice_mill.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log

class AlarmSoundService : Service() {

    private var mediaPlayer: MediaPlayer? = null
    private val handler = Handler(Looper.getMainLooper())
    private var cycleCount = 0
    private var isRunning = false

    companion object {
        const val ACTION_STOP = "com.rice_mill.app.STOP_ALARM_SERVICE"
        const val NOTIF_ID = 889
        const val SERVICE_CHANNEL_ID = "alarm_sound_service_channel"
        private const val TAG = "AlarmSoundService"
        private const val MAX_CYCLES = 4
        private const val PLAY_DURATION_MS = 90_000L
        private const val SILENCE_DURATION_MS = 60_000L
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createServiceNotificationChannel()
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
            startForeground(NOTIF_ID, buildForegroundNotification())
            runCycle()
        } else {
            Log.d(TAG, "Service already running — ignoring duplicate start")
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
            mediaPlayer?.stop()
            mediaPlayer?.release()
            
            val mp = MediaPlayer()
            mp.setAudioAttributes(
                AudioAttributes.Builder()
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .build()
            )
            
            val fd = resources.openRawResourceFd(R.raw.alarm)
            mp.setDataSource(fd.fileDescriptor, fd.startOffset, fd.length)
            fd.close()
            
            mp.isLooping = true
            mp.prepare()
            mp.start()
            
            mediaPlayer = mp
            Log.d(TAG, "Audio started for cycle $cycleCount on ALARM stream")
        } catch (e: Exception) {
            Log.e(TAG, "Error playing audio: ${e.message}")
        }
    }

    private fun handleStop() {
        isRunning = false
        handler.removeCallbacksAndMessages(null)

        mediaPlayer?.stop()
        mediaPlayer?.release()
        mediaPlayer = null

        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.cancel(999)

        val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
        prefs.edit()
            .putBoolean("flutter.alarm_playing", false)
            .putBoolean("flutter.isAlarmStopped", true)
            .apply()

        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
        Log.d(TAG, "Service stopped cleanly")
    }

    override fun onDestroy() {
        handleStop()
        super.onDestroy()
    }

    private fun buildForegroundNotification(): Notification {
        val stopIntent = PendingIntent.getService(
            this, 100,
            Intent(this, AlarmSoundService::class.java).apply { action = ACTION_STOP },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val openIntent = PendingIntent.getActivity(
            this, 101,
            Intent(this, LockScreenAlarmActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, SERVICE_CHANNEL_ID)
                .setContentTitle("⚠️ CRITICAL ALARM!")
                .setContentText("Power threshold exceeded. Tap to view.")
                .setSmallIcon(R.mipmap.launcher_icon)
                .setContentIntent(openIntent)
                .setFullScreenIntent(openIntent, true)
                .setOngoing(true)
                .setVisibility(Notification.VISIBILITY_PUBLIC)
                .setCategory(Notification.CATEGORY_ALARM)
                .addAction(
                    Notification.Action.Builder(
                        null, "🔕 STOP ALARM", stopIntent
                    ).build()
                )
                .build()
        } else {
            @Suppress("DEPRECATION")
            android.app.Notification.Builder(this)
                .setContentTitle("⚠️ CRITICAL ALARM!")
                .setContentText("Power threshold exceeded.")
                .setSmallIcon(R.mipmap.launcher_icon)
                .setContentIntent(openIntent)
                .setFullScreenIntent(openIntent, true)
                .setOngoing(true)
                .setVisibility(Notification.VISIBILITY_PUBLIC)
                .setCategory(Notification.CATEGORY_ALARM)
                .addAction(android.R.drawable.ic_media_pause, "🔕 STOP ALARM", stopIntent)
                .build()
        }
    }

    private fun createServiceNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                SERVICE_CHANNEL_ID,
                "Alarm Service",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                setSound(null, null)
                enableVibration(false)
            }
            val nm = getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(channel)
        }
    }
}
