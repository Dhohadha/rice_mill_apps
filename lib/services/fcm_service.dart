import 'package:flutter/widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';
import 'api_service.dart';
import 'alarm_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint("Handling a background message: ${message.messageId}");
  
  final notificationService = NotificationService();
  await notificationService.init();

  String title = message.data['title'] ?? '⚠️ Grid Pulse Alert';
  String body = message.data['body'] ?? 'Limit exceeded';
  String alertId = message.data['alertId'] ?? 'ALARM_ID';

  if (alertId == 'INVITE') {
    await notificationService.showNormalNotification(
      id: message.hashCode,
      title: title,
      body: body,
      payload: alertId,
    );
  } else {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('latest_alarm_title', title);
    await prefs.setString('flutter.latest_alarm_title', title);
    await prefs.setString('latest_alarm_body', body);
    await prefs.setString('flutter.latest_alarm_body', body);
    await prefs.setString('latest_alert_id', alertId);
    await prefs.setString('flutter.latest_alert_id', alertId);
    await prefs.setBool('alarm_playing', true);
    await prefs.setBool('flutter.alarm_playing', true);
    await prefs.setBool('isAlarmStopped', false);
    await prefs.setBool('flutter.isAlarmStopped', false);

    await notificationService.showThresholdAlert(
      id: 999,
      title: title,
      body: body,
      payload: alertId,
    );

    await AlarmService().playAlarm(title: title, body: body, alertId: alertId);
  }
}

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final NotificationService _notificationService = NotificationService();

  Future<void> init() async {
    // Set background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request permissions (especially for iOS and Android 13+)
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted notification permission');
    } else {
      debugPrint('User declined or has not accepted notification permission');
    }

    // Foreground listener
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');

      String title = message.data['title'] ?? '⚠️ Grid Pulse Alert';
      String body = message.data['body'] ?? 'Limit exceeded';
      String alertId = message.data['alertId'] ?? 'ALARM_ID';

      if (alertId == 'INVITE') {
        _notificationService.showNormalNotification(
          id: message.hashCode,
          title: title,
          body: body,
          payload: alertId,
        );
      } else {
        await _notificationService.showThresholdAlert(
          id: 999,
          title: title,
          body: body,
          payload: alertId,
        );
        AlarmService().playAlarm(title: title, body: body, alertId: alertId);
      }
    });

    // App opened from background via notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('App opened from notification!');
      String title = message.data['title'] ?? '⚠️ Grid Pulse Alert';
      String body = message.data['body'] ?? 'Limit exceeded';
      String alertId = message.data['alertId'] ?? 'ALARM_ID';

      if (alertId != 'INVITE') {
        AlarmService().playAlarm(title: title, body: body, alertId: alertId);
      }
    });

    // Register token immediately if already logged in
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      try {
        final token = await _fcm.getToken();
        if (token != null) {
          await _registerTokenWithBackend(token);
        }
      } catch (e) {
        debugPrint('Initial token fetch error: $e');
      }
    }

    // Listen to Auth State Changes to register token immediately upon login
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user != null) {
        debugPrint("User logged in, checking FCM token...");
        String? token = await _fcm.getToken();
        if (token != null) {
          await _registerTokenWithBackend(token);
        }
      }
    });

    // Token refresh listener
    _fcm.onTokenRefresh.listen((newToken) {
      _registerTokenWithBackend(newToken);
    });
  }

  Future<void> registerToken() async {
    try {
      final token = await _fcm.getToken();
      if (token != null) {
        await _registerTokenWithBackend(token);
      }
    } catch (e) {
      debugPrint('Manual registerToken error: $e');
    }
  }

  Future<void> _registerTokenWithBackend(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final idToken = await user.getIdToken();

      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/api/fcm-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({'token': token}),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ FCM Token registered successfully with backend: ${token.substring(0, 15)}...');
      } else {
        debugPrint('Failed to register token: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('Error registering token: $e');
    }
  }
}
