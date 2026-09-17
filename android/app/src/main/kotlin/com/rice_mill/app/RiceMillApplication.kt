package com.rice_mill.app

import android.app.Activity
import android.app.Application
import android.content.Context
import android.content.SharedPreferences
import android.os.Bundle
import android.util.Log

class RiceMillApplication : Application() {
    private lateinit var prefs: SharedPreferences

    companion object {
        private const val TAG = "RiceMillApp"
        var isAppInForeground = false

        /** Safely read a boolean from SharedPreferences, handling String/Number types
         *  stored by Flutter's home_widget plugin to avoid ClassCastException. */
        fun getSafeBoolean(prefs: SharedPreferences, key: String, defaultVal: Boolean): Boolean {
            return try {
                val value = prefs.all[key] ?: return defaultVal
                when (value) {
                    is Boolean -> value
                    is String -> value.equals("true", ignoreCase = true)
                    is Number -> value.toInt() != 0
                    else -> defaultVal
                }
            } catch (e: Throwable) {
                defaultVal
            }
        }
    }

    private val listener = SharedPreferences.OnSharedPreferenceChangeListener { sharedPreferences, key ->
        if (key == "flutter.alarm_playing" || key == "alarm_playing") {
            try {
                val isPlaying = getSafeBoolean(sharedPreferences, key, false)
                val soundEnabled = if (sharedPreferences.contains("flutter.alert_sound_enabled")) {
                    getSafeBoolean(sharedPreferences, "flutter.alert_sound_enabled", true)
                } else {
                    getSafeBoolean(sharedPreferences, "alert_sound_enabled", true)
                }
                
                if (isPlaying && soundEnabled) {
                    val title = sharedPreferences.getString("flutter.latest_alarm_title", null)
                        ?: sharedPreferences.getString("latest_alarm_title", "⚠️ THRESHOLD BREACH ALERT")
                        ?: "⚠️ THRESHOLD BREACH ALERT"
                    val body = sharedPreferences.getString("flutter.latest_alarm_body", null)
                        ?: sharedPreferences.getString("latest_alarm_body", "Critical electrical threshold exceeded! Tap to inspect.")
                        ?: "Critical electrical threshold exceeded! Tap to inspect."
                    val alertId = sharedPreferences.getString("flutter.latest_alert_id", null)
                        ?: sharedPreferences.getString("latest_alert_id", "ALARM_ID")
                        ?: "ALARM_ID"
                    AlarmHelper.triggerAlarm(this, title, body, alertId)
                } else {
                    val alertId = sharedPreferences.getString("flutter.latest_alert_id", null)
                        ?: sharedPreferences.getString("latest_alert_id", "ALARM_ID")
                    AlarmHelper.stopAlarm(this, alertId)
                }
            } catch (e: Throwable) {
                Log.e(TAG, "Listener error: ${e.message}")
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        prefs.registerOnSharedPreferenceChangeListener(listener)

        // Track foreground status of the main Flutter app
        registerActivityLifecycleCallbacks(object : ActivityLifecycleCallbacks {
            private var startedActivities = 0
            override fun onActivityStarted(activity: Activity) {
                if (activity !is LockScreenAlarmActivity) {
                    startedActivities++
                    isAppInForeground = startedActivities > 0
                }
            }
            override fun onActivityStopped(activity: Activity) {
                if (activity !is LockScreenAlarmActivity) {
                    startedActivities = maxOf(0, startedActivities - 1)
                    isAppInForeground = startedActivities > 0
                }
            }
            override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) {}
            override fun onActivityResumed(activity: Activity) {
                if (activity !is LockScreenAlarmActivity) {
                    isAppInForeground = true
                }
            }
            override fun onActivityPaused(activity: Activity) {}
            override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) {}
            override fun onActivityDestroyed(activity: Activity) {}
        })
    }
}
