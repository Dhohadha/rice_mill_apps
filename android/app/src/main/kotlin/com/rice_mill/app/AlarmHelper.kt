package com.rice_mill.app

import android.app.KeyguardManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.drawable.Icon
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.util.Log

object AlarmHelper {
    private const val TAG = "AlarmHelper"
    const val ALARM_CHANNEL_ID = "grid_pulse_critical_alarm_v12"
    const val NOTIF_ID = 999

    private var cpuWakeLock: PowerManager.WakeLock? = null

    fun triggerAlarm(context: Context, title: String, body: String, alertId: String? = "ALARM_ID") {
        Log.d(TAG, "triggerAlarm called: title=$title, body=$body, alertId=$alertId")

        try {
            // 1. Force screen wake up and CPU awake
            wakeScreenAndCpu(context)

            // 2. Create high priority alarm channel
            createAlarmChannel(context)

            // 3. Prepare LockScreenAlarmActivity Intent
            val lockIntent = Intent(context, LockScreenAlarmActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP or
                        Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
                putExtra("title", title)
                putExtra("body", body)
                putExtra("alertId", alertId ?: "ALARM_ID")
            }

            // Both contentIntent (tapping notification) and fullScreenIntent open LockScreenAlarmActivity
            val lockPendingIntent = PendingIntent.getActivity(
                context,
                101,
                lockIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val stopBroadcastIntent = PendingIntent.getBroadcast(
                context,
                100,
                Intent(context, AlarmBroadcastReceiver::class.java).apply {
                    action = AlarmBroadcastReceiver.ACTION_STOP
                    putExtra("alertId", alertId ?: "ALARM_ID")
                },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            // 4. Build and post the Full-Screen Critical Alarm Notification
            val actionIcon = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                Icon.createWithResource(context, android.R.drawable.ic_media_pause)
            } else {
                null
            }

            val notifBuilder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(context, ALARM_CHANNEL_ID)
                    .setContentTitle(title)
                    .setContentText(body)
                    .setSmallIcon(R.mipmap.launcher_icon)
                    .setContentIntent(lockPendingIntent)
                    .setFullScreenIntent(lockPendingIntent, true)
                    .setOngoing(true)
                    .setAutoCancel(false)
                    .setVisibility(Notification.VISIBILITY_PUBLIC)
                    .setCategory(Notification.CATEGORY_ALARM)
                    .apply {
                        @Suppress("DEPRECATION")
                        setPriority(Notification.PRIORITY_MAX)
                        if (actionIcon != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            addAction(Notification.Action.Builder(actionIcon, "🔕 STOP ALARM", stopBroadcastIntent).build())
                        }
                    }
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(context)
                    .setContentTitle(title)
                    .setContentText(body)
                    .setSmallIcon(R.mipmap.launcher_icon)
                    .setContentIntent(lockPendingIntent)
                    .setFullScreenIntent(lockPendingIntent, true)
                    .setOngoing(true)
                    .setAutoCancel(false)
                    .setVisibility(Notification.VISIBILITY_PUBLIC)
                    .setCategory(Notification.CATEGORY_ALARM)
                    .setPriority(Notification.PRIORITY_MAX)
                    .addAction(android.R.drawable.ic_media_pause, "🔕 STOP ALARM", stopBroadcastIntent)
            }

            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.notify(NOTIF_ID, notifBuilder.build())
            Log.d(TAG, "Posted alarm notification #$NOTIF_ID (pointing directly to LockScreenAlarmActivity)")

            // 5. Launch LockScreenAlarmActivity directly
            try {
                context.startActivity(lockIntent)
                Log.d(TAG, "Directly launched LockScreenAlarmActivity")
            } catch (t: Throwable) {
                Log.d(TAG, "Direct startActivity note: ${t.message}")
            }

            // 6. Start foreground service for background audio loop
            try {
                val serviceIntent = Intent(context, AlarmSoundService::class.java)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(serviceIntent)
                } else {
                    context.startService(serviceIntent)
                }
            } catch (t: Throwable) {
                Log.w(TAG, "startForegroundService note: ${t.message}")
            }

        } catch (e: Throwable) {
            Log.e(TAG, "Error in triggerAlarm: ${e.message}", e)
        }
    }

    fun stopAlarm(context: Context, alertId: String? = null) {
        Log.d(TAG, "stopAlarm called, alertId=$alertId")
        try {
            // Cancel all notifications
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.cancel(NOTIF_ID)
            nm.cancel(889)
            nm.cancel(888)

            // Release wake locks
            try {
                if (cpuWakeLock?.isHeld == true) {
                    cpuWakeLock?.release()
                }
            } catch (e: Throwable) {
                Log.e(TAG, "Error releasing wake lock: ${e.message}")
            }
            cpuWakeLock = null

            // Stop foreground service
            try {
                val stopServiceIntent = Intent(context, AlarmSoundService::class.java).apply {
                    action = AlarmSoundService.ACTION_STOP
                }
                context.startService(stopServiceIntent)
            } catch (t: Throwable) {
                Log.e(TAG, "Error stopping service: ${t.message}")
            }

            // Update SharedPreferences
            try {
                val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val resolvedAlertId = alertId 
                    ?: prefs.getString("flutter.latest_alert_id", null)
                    ?: prefs.getString("latest_alert_id", null)
                    ?: "ALARM_ID"
                prefs.edit()
                    .putBoolean("flutter.alarm_playing", false)
                    .putBoolean("alarm_playing", false)
                    .putBoolean("flutter.isAlarmStopped", true)
                    .putBoolean("isAlarmStopped", true)
                    .apply()

                // Notify server in background thread
                notifyServerStop(resolvedAlertId)
            } catch (t: Throwable) {
                Log.e(TAG, "Error updating prefs: ${t.message}")
            }
        } catch (e: Throwable) {
            Log.e(TAG, "Error in stopAlarm: ${e.message}", e)
        }
    }

    private fun notifyServerStop(alertId: String) {
        Thread {
            try {
                val url = java.net.URL("http://10.83.170.35:7007/api/stop-alert")
                val conn = url.openConnection() as java.net.HttpURLConnection
                conn.requestMethod = "POST"
                conn.setRequestProperty("Content-Type", "application/json")
                conn.doOutput = true
                conn.connectTimeout = 3000
                conn.readTimeout = 3000
                val body = "{\"alertId\":\"$alertId\"}"
                conn.outputStream.use { os ->
                    os.write(body.toByteArray(Charsets.UTF_8))
                }
                val responseCode = conn.responseCode
                Log.d(TAG, "notifyServerStop responseCode: $responseCode for alertId: $alertId")
                conn.disconnect()
            } catch (e: Throwable) {
                Log.d(TAG, "notifyServerStop note: ${e.message}")
            }
        }.start()
    }

    private fun wakeScreenAndCpu(context: Context) {
        try {
            val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager

            // CPU Wakelock
            if (cpuWakeLock == null) {
                cpuWakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "RiceMill:AlarmCpuWakeLock").apply {
                    setReferenceCounted(false)
                    acquire(10 * 60 * 1000L)
                }
            }

            // Screen Wakelock to turn display ON
            @Suppress("DEPRECATION")
            val screenLock = pm.newWakeLock(
                PowerManager.SCREEN_BRIGHT_WAKE_LOCK or
                PowerManager.ACQUIRE_CAUSES_WAKEUP or
                PowerManager.ON_AFTER_RELEASE,
                "RiceMill:AlarmScreenWakeLock"
            )
            screenLock.acquire(15000L)
        } catch (e: Throwable) {
            Log.e(TAG, "wakeScreenAndCpu error: ${e.message}")
        }
    }

    fun createAlarmChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                val nm = context.getSystemService(NotificationManager::class.java) ?: return

                val audioAttributes = AudioAttributes.Builder()
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .build()

                val soundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                    ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)

                val channel = NotificationChannel(
                    ALARM_CHANNEL_ID,
                    "Critical Threshold Alerts",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                    enableVibration(true)
                    vibrationPattern = longArrayOf(0, 500, 200, 500)
                    setSound(soundUri, audioAttributes)
                    setBypassDnd(true)
                }
                nm.createNotificationChannel(channel)
            } catch (e: Throwable) {
                Log.e(TAG, "createAlarmChannel error: ${e.message}")
            }
        }
    }
}
