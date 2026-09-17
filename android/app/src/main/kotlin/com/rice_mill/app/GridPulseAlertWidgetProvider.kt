package com.rice_mill.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.util.Log
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

class GridPulseAlertWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val TAG = "GridPulseAlertWidget"

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

        fun getSafeString(prefs: SharedPreferences, key: String, defaultVal: String): String {
            return try {
                val value = prefs.all[key] ?: return defaultVal
                value.toString()
            } catch (e: Throwable) {
                defaultVal
            }
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: android.os.Bundle
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        onUpdate(context, appWidgetManager, intArrayOf(appWidgetId))
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            try {
                val views = RemoteViews(context.packageName, R.layout.grid_pulse_alert_widget)

                // Read alert widget data safely without ClassCastException
                val widgetData = HomeWidgetPlugin.getData(context)

                val isBreach = getSafeBoolean(widgetData, "alert_is_breach", false)
                val alertTitle = getSafeString(widgetData, "alert_title", "⚠️ THRESHOLD EXCEEDED")
                val alertDesc = getSafeString(widgetData, "alert_message", "Operating metrics exceeded safe limits")
                val kw = getSafeString(widgetData, "widget_kw", "0.0 kW")
                val kva = getSafeString(widgetData, "widget_kva", "0.0 kVA")
                val pf = getSafeString(widgetData, "widget_pf", "0.000")
                val updatedTime = getSafeString(widgetData, "widget_updated_time", "Just now")
                val devicesSummary = getSafeString(widgetData, "alert_devices_summary", "All Devices Monitored")

                val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
                val minWidth = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH) ?: 0
                val isShrunken = minWidth in 1..240

                if (isBreach) {
                    // Switch to Emergency RED breach state (Child 1)
                    views.setInt(R.id.alert_view_flipper, "setDisplayedChild", 1)

                    views.setTextViewText(R.id.alert_breach_title, alertTitle)
                    views.setTextViewText(R.id.alert_breach_desc, alertDesc)
                    views.setTextViewText(R.id.alert_breach_time, "Breach active • $updatedTime")
                } else {
                    // Switch to Premium Green/White gradient normal state (Child 0)
                    views.setInt(R.id.alert_view_flipper, "setDisplayedChild", 0)

                    if (isShrunken) {
                        views.setTextViewText(R.id.alert_normal_badge, "● SECURE")
                    } else {
                        views.setTextViewText(R.id.alert_normal_badge, "🛡️ ALL SYSTEMS SECURE")
                    }

                    views.setTextViewText(R.id.alert_normal_title, alertTitle)
                    views.setTextViewText(R.id.alert_normal_desc, alertDesc)
                    views.setTextViewText(
                        R.id.alert_normal_metrics,
                        "⚡ $kw   │   📊 $kva   │   ✨ PF $pf"
                    )
                    views.setTextViewText(R.id.alert_normal_devices_label, devicesSummary)
                    views.setTextViewText(R.id.alert_normal_time, "Updated: $updatedTime")
                }

                // Tap widget to launch main app
                val intent = Intent(context, MainActivity::class.java).apply {
                    setFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                }
                val pendingIntent = PendingIntent.getActivity(
                    context,
                    101,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.alert_widget_root, pendingIntent)
                views.setOnClickPendingIntent(R.id.alert_normal_container, pendingIntent)
                views.setOnClickPendingIntent(R.id.alert_breach_container, pendingIntent)

                appWidgetManager.updateAppWidget(appWidgetId, views)
            } catch (t: Throwable) {
                Log.e(TAG, "Error updating GridPulseAlertWidget", t)
            }
        }
    }
}
