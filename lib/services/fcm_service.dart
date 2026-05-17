import 'package:flutter/widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'notification_service.dart';
import 'api_service.dart';
import 'alarm_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint("Handling a background message: ${message.messageId}");
  
  // Initialize NotificationService in background isolate
  final notificationService = NotificationService();
  await notificationService.init();

  String title = message.data['title'] ?? '⚠️ Rice Mill Alert';
  String body = message.data['body'] ?? 'Limit exceeded';
  String alertId = message.data['alertId'] ?? 'ALARM_ID';

  if (alertId == 'INVITE' || alertId == 'PF') {
    await notificationService.showNormalNotification(
      id: message.hashCode,
      title: title,
      body: body,
      payload: alertId,
    );
  } else {
    await notificationService.showThresholdAlert(
      id: 999, // New unified ID
      title: title,
      body: body,
      payload: alertId,
    );
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
      debugPrint('User granted permission');
    } else {
      debugPrint('User declined or has not accepted permission');
    }

    // Foreground listener
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');

      // Extract title and body from data payload since we changed server to send data
      String title = message.data['title'] ?? '⚠️ Rice Mill Alert';
      String body = message.data['body'] ?? 'Limit exceeded';
      String alertId = message.data['alertId'] ?? 'ALARM_ID';

      if (alertId == 'INVITE' || alertId == 'PF') {
        _notificationService.showNormalNotification(
          id: message.hashCode,
          title: title,
          body: body,
          payload: alertId,
        );
      } else {
        _notificationService.showThresholdAlert(
          id: message.hashCode,
          title: title,
          body: body,
          payload: alertId,
        );

        // Play the loud alarm sound explicitly for foreground alerts only if not an invite
        AlarmService().playAlarm();
      }
    });

    // App opened from background/terminated via notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('App opened from notification!');
    });

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
        debugPrint('Token registered successfully');
      } else {
        debugPrint('Failed to register token: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('Error registering token: $e');
    }
  }
}
