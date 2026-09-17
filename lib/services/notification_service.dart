import 'dart:typed_data';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'alarm_service.dart';
import 'api_service.dart';

// Background handler - records stop request to SharedPreferences and notifies server
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) async {
  if (notificationResponse.actionId == 'stop_alarm') {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('alarm_playing', false);
    await prefs.setBool('flutter.alarm_playing', false);
    await prefs.setBool('isAlarmStopped', true);
    await prefs.setBool('flutter.isAlarmStopped', true);
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

  Function(String?)? onNotificationTap;
  Function()? onStopAlarmAction;

  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');

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
        if (details.actionId == 'stop_alarm') {
          AlarmService().stopAlarm();
          onStopAlarmAction?.call();

          if (details.payload != null) {
            stopAlertOnServer(details.payload!);
          }
        } else {
          onNotificationTap?.call(details.payload);
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
  }

  static Future<void> stopAlertOnServer(String alertId) async {
    try {
      final url = '${ApiService.baseUrl}/api/stop-alert';
      await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'alertId': alertId}),
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      // Ignored
    }
  }

  Future<void> cancelAlert() async {
    await _notificationsPlugin.cancel(999);
    await _notificationsPlugin.cancel(889);
    await _notificationsPlugin.cancel(888);
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
      icon: '@mipmap/launcher_icon',
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

    // Matches the native channel created with VISIBILITY_PUBLIC in MainActivity.kt
    final String channelId = isSoundEnabled ? 'grid_pulse_critical_alarm_v14' : 'grid_pulse_silent_alarm_v14';
    final String channelName = isSoundEnabled ? 'Critical Alerts (Loud)' : 'Critical Alerts (Silent)';

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: 'Critical power threshold alerts with stop action',
      importance: Importance.max,
      priority: Priority.max,
      visibility: NotificationVisibility.public,
      playSound: false, // Purely silent notification; AlarmSoundService MediaPlayer handles looping audio exclusively
      ongoing: true,
      autoCancel: false,
      sound: null,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
      actions: const <AndroidNotificationAction>[
        AndroidNotificationAction(
          'stop_alarm',
          '🔕 STOP ALARM',
          showsUserInterface: false,
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
