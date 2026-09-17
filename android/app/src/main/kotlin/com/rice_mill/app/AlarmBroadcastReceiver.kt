package com.rice_mill.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class AlarmBroadcastReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_STOP = "com.rice_mill.app.STOP_ALARM"
        const val ACTION_TRIGGER = "com.rice_mill.app.TRIGGER_ALARM"
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ACTION_STOP -> {
                val alertId = intent.getStringExtra("alertId")
                AlarmHelper.stopAlarm(context, alertId)
            }
            ACTION_TRIGGER -> {
                val title = intent.getStringExtra("title") ?: "⚠️ THRESHOLD BREACH ALERT"
                val body = intent.getStringExtra("body") ?: "Critical electrical threshold exceeded!"
                val alertId = intent.getStringExtra("alertId") ?: "ALARM_ID"
                AlarmHelper.triggerAlarm(context, title, body, alertId)
            }
        }
    }
}
