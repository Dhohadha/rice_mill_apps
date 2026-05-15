import 'dart:typed_data';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'alarm_service.dart';

// Background handler - minimal, just records the stop request to SharedPreferences
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) async {
  if (notificationResponse.actionId == 'stop_alarm') {
    // Write the stop flag so main isolate picks it up on next resume
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isAlarmStopped', true);
    await prefs.setString('lastStoppedTime', DateTime.now().toIso8601String());
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

  Future<void> cancelAlert() async {
    await _notificationsPlugin.cancel(999);
  }

  Future<void> showThresholdAlert({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'threshold_alerts_lite_v1',
      'Emergency Threshold Alerts',
      channelDescription: 'Critical power alerts for Lite app',
      importance: Importance.max,
      priority: Priority.max,
      visibility: NotificationVisibility.public,
      playSound: true,
      ongoing: true,
      autoCancel: false,
      sound: const RawResourceAndroidNotificationSound('alarm'),
      audioAttributesUsage: AudioAttributesUsage.alarm,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(
          'stop_alarm',
          '🔕 STOP ALARM',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
    );

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(
        presentSound: true,
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
