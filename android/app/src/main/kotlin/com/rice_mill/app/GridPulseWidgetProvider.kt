package com.rice_mill.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Color
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

class GridPulseWidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_CYCLE_DEVICE = "com.rice_mill.app.ACTION_CYCLE_DEVICE"
        private const val TAG = "GridPulseWidget"

        fun getSafeString(prefs: SharedPreferences, key: String, defaultVal: String): String {
            return try {
                val value = prefs.all[key] ?: return defaultVal
                value.toString()
            } catch (e: Throwable) {
                defaultVal
            }
        }

        fun getSafeInt(prefs: SharedPreferences, key: String, defaultVal: Int): Int {
            return try {
                val value = prefs.all[key] ?: return defaultVal
                when (value) {
                    is Number -> value.toInt()
                    is String -> value.toIntOrNull() ?: defaultVal
                    else -> defaultVal
                }
            } catch (e: Throwable) {
                defaultVal
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        try {
            if (intent.action == ACTION_CYCLE_DEVICE) {
                val widgetData = HomeWidgetPlugin.getData(context)
                val deviceCount = getSafeInt(widgetData, "widget_device_count", 1)
                if (deviceCount > 1) {
                    val currentIndex = getSafeInt(widgetData, "widget_selected_device_index", 0)
                    val nextIndex = (currentIndex + 1) % deviceCount
                    widgetData.edit().putInt("widget_selected_device_index", nextIndex).apply()

                    val appWidgetManager = AppWidgetManager.getInstance(context)
                    val componentName = ComponentName(context, GridPulseWidgetProvider::class.java)
                    val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
                    onUpdate(context, appWidgetManager, appWidgetIds)
                }
            }
        } catch (t: Throwable) {
            Log.e(TAG, "Error handling onReceive in GridPulseWidget", t)
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
                val views = RemoteViews(context.packageName, R.layout.grid_pulse_widget)

                // Read widget data safely without ClassCastException
                val widgetData = HomeWidgetPlugin.getData(context)
                val deviceCount = getSafeInt(widgetData, "widget_device_count", 1)
                val selectedIndex = getSafeInt(widgetData, "widget_selected_device_index", 0)

                // Fetch device-specific or fallback global metrics
                val deviceName = getSafeString(
                    widgetData,
                    "dev_${selectedIndex}_name",
                    getSafeString(widgetData, "widget_device_name", "MAIN METER")
                )

                val kw = getSafeString(
                    widgetData,
                    "dev_${selectedIndex}_kw",
                    getSafeString(widgetData, "widget_kw", "0.0 kW")
                )

                val kva = getSafeString(
                    widgetData,
                    "dev_${selectedIndex}_kva",
                    getSafeString(widgetData, "widget_kva", "0.0 kVA")
                )

                val pf = getSafeString(
                    widgetData,
                    "dev_${selectedIndex}_pf",
                    getSafeString(widgetData, "widget_pf", "0.000")
                )

                val status = getSafeString(
                    widgetData,
                    "dev_${selectedIndex}_status",
                    getSafeString(widgetData, "widget_status", "🟢 ONLINE")
                )

                val updatedTime = getSafeString(widgetData, "widget_updated_time", "Just now")

                views.setTextViewText(R.id.widget_device_name, deviceName)
                views.setTextViewText(R.id.widget_kw, kw)
                views.setTextViewText(R.id.widget_kva, kva)
                views.setTextViewText(R.id.widget_pf, pf)
                views.setTextViewText(R.id.widget_updated_time, "Updated: $updatedTime")

                // Show cycle button only when multiple devices exist
                if (deviceCount > 1) {
                    views.setViewVisibility(R.id.widget_btn_next_device, View.VISIBLE)
                } else {
                    views.setViewVisibility(R.id.widget_btn_next_device, View.GONE)
                }

                // Check if widget is shrinken on home screen
                val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
                val minWidth = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH) ?: 0
                val isShrunken = minWidth in 1..240
                val isOffline = status.contains("OFFLINE")

                if (isShrunken) {
                    // When shrinken, display status as just a compact green/red dot to protect GRID PULSE title
                    views.setTextViewText(R.id.widget_status, "●")
                    views.setTextViewTextSize(R.id.widget_status, android.util.TypedValue.COMPLEX_UNIT_SP, 11f)
                    if (isOffline) {
                        views.setInt(R.id.widget_status, "setBackgroundResource", R.drawable.bg_badge_dot_offline)
                        views.setTextColor(R.id.widget_status, Color.parseColor("#B91C1C"))
                    } else {
                        views.setInt(R.id.widget_status, "setBackgroundResource", R.drawable.bg_badge_dot_online)
                        views.setTextColor(R.id.widget_status, Color.parseColor("#15803D"))
                    }
                } else {
                    // Normal expanded width: display full "● ONLINE" pill bar
                    views.setTextViewText(R.id.widget_status, if (isOffline) "● OFFLINE" else "● ONLINE")
                    views.setTextViewTextSize(R.id.widget_status, android.util.TypedValue.COMPLEX_UNIT_SP, 9f)
                    if (isOffline) {
                        views.setInt(R.id.widget_status, "setBackgroundResource", R.drawable.bg_badge_offline)
                        views.setTextColor(R.id.widget_status, Color.parseColor("#B91C1C"))
                    } else {
                        views.setInt(R.id.widget_status, "setBackgroundResource", R.drawable.bg_badge_online)
                        views.setTextColor(R.id.widget_status, Color.parseColor("#15803D"))
                    }
                }

                // Set broadcast PendingIntent on device switcher chip
                val cycleIntent = Intent(context, GridPulseWidgetProvider::class.java).apply {
                    action = ACTION_CYCLE_DEVICE
                }
                val cyclePendingIntent = PendingIntent.getBroadcast(
                    context,
                    201,
                    cycleIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_device_chip, cyclePendingIntent)
                views.setOnClickPendingIntent(R.id.widget_btn_next_device, cyclePendingIntent)

                // Tap widget body to launch main app
                val appIntent = Intent(context, MainActivity::class.java).apply {
                    setFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                }
                val appPendingIntent = PendingIntent.getActivity(
                    context,
                    0,
                    appIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_container, appPendingIntent)

                appWidgetManager.updateAppWidget(appWidgetId, views)
            } catch (t: Throwable) {
                Log.e(TAG, "Error updating GridPulseWidget", t)
            }
        }
    }
}
