package com.rice_mill.app

import android.content.Intent
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.media.AudioAttributes
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant
import android.os.PowerManager
import android.provider.Settings
import android.content.Context
import android.app.KeyguardManager
import android.os.Handler
import android.os.Looper

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.rice_mill.app/alarm"
    private val NOTIF_CHANNEL_ID = "grid_pulse_critical_alarm_v14"
    private val SILENT_CHANNEL_ID = "grid_pulse_silent_alarm_v14"
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "startAlarm" -> {
                        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                        val title = prefs.getString("flutter.latest_alarm_title", null)
                            ?: prefs.getString("latest_alarm_title", "⚠️ THRESHOLD BREACH ALERT")
                            ?: "⚠️ THRESHOLD BREACH ALERT"
                        val body = prefs.getString("flutter.latest_alarm_body", null)
                            ?: prefs.getString("latest_alarm_body", "Critical electrical threshold exceeded! Tap to inspect.")
                            ?: "Critical electrical threshold exceeded! Tap to inspect."
                        val alertId = prefs.getString("flutter.latest_alert_id", null)
                            ?: prefs.getString("latest_alert_id", "ALARM_ID")
                            ?: "ALARM_ID"
                        AlarmHelper.triggerAlarm(this@MainActivity, title, body, alertId)
                        result.success(true)
                    }
                    "stopAlarm" -> {
                        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                        val alertId = prefs.getString("flutter.latest_alert_id", null)
                            ?: prefs.getString("latest_alert_id", "ALARM_ID")
                        AlarmHelper.stopAlarm(this@MainActivity, alertId)
                        result.success(true)
                    }
                    "checkFullScreenPermission" -> {
                        result.success(checkFullScreenPermission())
                    }
                    "openFullScreenSettings" -> {
                        openFullScreenSettings()
                        result.success(true)
                    }
                    "checkBatteryOptimization" -> {
                        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                        result.success(pm.isIgnoringBatteryOptimizations(packageName))
                    }
                    "requestIgnoreBatteryOptimization" -> {
                        requestIgnoreBatteryOptimization()
                        result.success(true)
                    }
                    "openAutoStartSettings" -> {
                        openAutoStartSettings()
                        result.success(true)
                    }
                    "openNotificationSettings" -> {
                        val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                        intent.putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        try {
                            startActivity(intent)
                        } catch (e: Exception) {
                            val fallbackIntent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                            fallbackIntent.data = Uri.parse("package:$packageName")
                            fallbackIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(fallbackIntent)
                        }
                        result.success(true)
                    }
                    "closeApp" -> {
                        finishAndRemoveTask()
                        result.success(true)
                    }
                    "isScreenLocked" -> {
                        val km = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
                        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                        result.success(km.isKeyguardLocked || !pm.isInteractive)
                    }
                    "removeLockScreenFlags" -> {
                        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O_MR1) {
                            setShowWhenLocked(false)
                            setTurnScreenOn(false)
                        }
                        window.clearFlags(
                            android.view.WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                            android.view.WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                            android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                            android.view.WindowManager.LayoutParams.FLAG_ALLOW_LOCK_WHILE_SCREEN_ON
                        )
                        result.success(true)
                    }
                    "checkAlarmStatus" -> {
                        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                        val isPlaying = RiceMillApplication.getSafeBoolean(prefs, "flutter.alarm_playing", false) || RiceMillApplication.getSafeBoolean(prefs, "alarm_playing", false)
                        result.success(isPlaying)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        configureLockScreenFlags()

        if (intent.getBooleanExtra("finish", false)) {
            finishAndRemoveTask()
        }
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        configureLockScreenFlags()
        volumeControlStream = android.media.AudioManager.STREAM_ALARM
        createAlarmNotificationChannel()
    }

    private fun checkFullScreenPermission(): Boolean {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            val manager = getSystemService(NotificationManager::class.java)
            return manager?.canUseFullScreenIntent() ?: true
        }
        return true
    }

    private fun openFullScreenSettings() {
        try {
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                val intent = Intent(android.provider.Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT)
                intent.data = Uri.parse("package:$packageName")
                startActivity(intent)
            } else {
                val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                intent.data = Uri.parse("package:$packageName")
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
            }
        } catch (e: Exception) {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
            intent.data = Uri.parse("package:$packageName")
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        }
    }

    private fun createAlarmNotificationChannel() {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java) ?: return

            if (manager.getNotificationChannel(NOTIF_CHANNEL_ID) == null) {
                val channel = NotificationChannel(
                    NOTIF_CHANNEL_ID,
                    "Critical Alerts (Loud)",
                    NotificationManager.IMPORTANCE_HIGH
                )
                channel.setSound(null, null)
                channel.enableVibration(true)
                channel.lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                manager.createNotificationChannel(channel)
            }

            if (manager.getNotificationChannel(SILENT_CHANNEL_ID) == null) {
                val silentChannel = NotificationChannel(
                    SILENT_CHANNEL_ID,
                    "Critical Alerts (Silent)",
                    NotificationManager.IMPORTANCE_HIGH
                )
                silentChannel.setSound(null, null)
                silentChannel.enableVibration(false)
                silentChannel.lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                manager.createNotificationChannel(silentChannel)
            }
        }
    }

    private fun configureLockScreenFlags() {
        // MainActivity (Flutter) must NEVER display over the lock screen.
        // The lock screen is reserved EXCLUSIVELY for LockScreenAlarmActivity (Kotlin).
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(false)
            setTurnScreenOn(false)
        }
        window.clearFlags(
            android.view.WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            android.view.WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
            android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
            android.view.WindowManager.LayoutParams.FLAG_ALLOW_LOCK_WHILE_SCREEN_ON
        )
    }

    private fun openAutoStartSettings() {
        val intents = arrayOf(
            Intent().setComponent(android.content.ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity")),
            Intent().setComponent(android.content.ComponentName("com.letv.android.letvsafe", "com.letv.android.letvsafe.AutobootManageActivity")),
            Intent().setComponent(android.content.ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.optimize.process.ProtectActivity")),
            Intent().setComponent(android.content.ComponentName("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity")),
            Intent().setComponent(android.content.ComponentName("com.coloros.safecenter", "com.coloros.safecenter.startupapp.StartupAppListActivity")),
            Intent().setComponent(android.content.ComponentName("com.oppo.safe", "com.oppo.safe.permission.startup.StartupAppListActivity")),
            Intent().setComponent(android.content.ComponentName("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity")),
            Intent().setComponent(android.content.ComponentName("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.BgStartUpManager")),
            Intent().setComponent(android.content.ComponentName("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.BgStartUpManagerActivity")),
            Intent().setComponent(android.content.ComponentName("com.samsung.android.lool", "com.samsung.android.sm.ui.battery.BatteryActivity")),
            Intent().setComponent(android.content.ComponentName("com.htc.pitroad", "com.htc.pitroad.landingpage.activity.LandingPageActivity")),
            Intent().setComponent(android.content.ComponentName("com.asus.mobilemanager", "com.asus.mobilemanager.entry.FunctionActivity")).setData(Uri.parse("mobilemanager://function/entry/AutoStart"))
        )

        var found = false
        for (intent in intents) {
            if (packageManager.resolveActivity(intent, android.content.pm.PackageManager.MATCH_DEFAULT_ONLY) != null) {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
                found = true
                break
            }
        }

        if (!found) {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
            intent.data = Uri.parse("package:$packageName")
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        }
    }

    private fun requestIgnoreBatteryOptimization() {
        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
        intent.data = Uri.parse("package:$packageName")
        startActivity(intent)
    }
}
