import 'dart:typed_data';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'alarm_service.dart';
import 'api_service.dart';

// Background handler - minimal, just records the stop request to SharedPreferences
// We do NOT initialize Flutter engine here to avoid Samsung freeze bugs
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) async {
  if (notificationResponse.actionId == 'stop_alarm') {
    // Write the stop flag so main isolate picks it up on next resume
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isAlarmStopped', true);
    await prefs.setString('lastStoppedTime', DateTime.now().toIso8601String());

    // Notify server even in background
    if (notificationResponse.payload != null) {
      await NotificationService.stopAlertOnServer(notificationResponse.payload!);
    }
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Callbacks for foreground tap handling
  Function(String?)? onNotificationTap;
  Function()? onStopAlarmAction;

  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        // This is called when app is FOREGROUND or BACKGROUND (brought to front)
        if (details.actionId == 'stop_alarm') {
          AlarmService().stopAlarm();
          onStopAlarmAction?.call();
          
          // Notify server
          if (details.payload != null) {
            stopAlertOnServer(details.payload!);
          }

          // Also clear the SharedPrefs flag if set by background
          SharedPreferences.getInstance().then((prefs) {
            prefs.setBool('isAlarmStopped', true);
          });
        } else {
          onNotificationTap?.call(details.payload);
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
  }

  static Future<void> stopAlertOnServer(String alertId) async {
    try {
      // Using hardcoded IP or ApiService.baseUrl if possible
      // In background isolate, we use the static baseUrl
      final url = '${ApiService.baseUrl}/api/stop-alert';
      print('🌐 Notifying server to stop alert: $alertId at $url');
      
      await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'alertId': alertId}),
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      print('❌ Error notifying server: $e');
    }
  }

  Future<void> cancelAlert() async {
    await _notificationsPlugin.cancel(999);
  }

  Future<void> showNormalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'normal_alerts_v1',
      'General Alerts',
      channelDescription: 'Standard notifications',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _notificationsPlugin.show(
      id,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  Future<void> showThresholdAlert({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final isSoundEnabled = prefs.getBool('alert_sound_enabled') ?? true;

    final String channelId = isSoundEnabled ? 'threshold_alerts_v11_loud' : 'threshold_alerts_v11_silent';
    final String channelName = isSoundEnabled ? 'Emergency Threshold Alerts (Loud)' : 'Emergency Threshold Alerts (Silent)';

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: 'Critical power alerts with action buttons',
      importance: Importance.max,
      priority: Priority.max,
      visibility: NotificationVisibility.public,
      playSound: isSoundEnabled,
      ongoing: true,      // Samsung never collapses ongoing — button always visible
      autoCancel: false,  // Only dismiss on explicit STOP action
      sound: isSoundEnabled ? const RawResourceAndroidNotificationSound('alarm') : null,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      // No BigTextStyleInformation — Samsung shows action buttons inline in compact view
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'stop_alarm',
          '🔕 STOP ALARM',
          showsUserInterface: false, // Set to false to prevent app redirect
          cancelNotification: true,
        ),
      ],
    );

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentSound: isSoundEnabled,
        presentAlert: true,
        presentBadge: true,
      ),
    );

    await _notificationsPlugin.show(
      999,
      title,
      body,
      platformChannelSpecifics,
      payload: payload ?? 'alarm',
    );
  }
}
