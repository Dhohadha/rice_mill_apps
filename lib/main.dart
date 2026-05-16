import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:firebase_core/firebase_core.dart';
import 'services/fcm_service.dart';
import 'screens/main_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/login_screen.dart';
import 'screens/not_registered_screen.dart';
import 'screens/access_revoked_screen.dart';
import 'services/notification_service.dart';
import 'services/alarm_service.dart';
import 'services/providers.dart';


Future<void> _requestPermissions() async {
  if (Platform.isAndroid) {
    // Request notification permission (Android 13+)
    final notifStatus = await Permission.notification.status;
    if (!notifStatus.isGranted) {
      await Permission.notification.request();
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
  
  await _requestPermissions();

  final notificationService = NotificationService();
  await notificationService.init();

  final fcmService = FCMService();
  await fcmService.init();

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupNotificationListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _setupNotificationListeners() {
    final notificationService = NotificationService();

    notificationService.onNotificationTap = (payload) {
      if (payload == 'history') {
        _navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
        );
      }
    };

    notificationService.onStopAlarmAction = () {
      AlarmService().stopAlarm();
    };
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      final prefs = await SharedPreferences.getInstance();
      final isAlarmStopped = prefs.getBool('isAlarmStopped') ?? false;
      
      if (isAlarmStopped) {
        AlarmService().stopAlarm();
        await prefs.setBool('isAlarmStopped', false);
      }

      ref.read(userProfileProvider.notifier).refreshProfileQuietly();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rice Mill Monitoring',
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
        textTheme: const TextTheme(
          headlineMedium: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
          titleMedium: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54),
        ),
      ),

      home: Consumer(
        builder: (context, ref, child) {
          final authState = ref.watch(authStateProvider);
          
          return authState.when(
            skipLoadingOnReload: true,
            skipLoadingOnRefresh: true,
            loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
            error: (err, _) => Scaffold(body: Center(child: Text('Error: $err'))),
            data: (user) {
              if (user != null) {
                return Consumer(
                  builder: (context, ref, child) {
                    final userProfile = ref.watch(userProfileProvider);
                    
                    return userProfile.when(
                      skipLoadingOnReload: true,
                      skipLoadingOnRefresh: true,
                      data: (profile) {
                        // Null means server returned a non-200 error (timeout/down)
                        if (profile == null) {
                          return Scaffold(
                            backgroundColor: Colors.white,
                            body: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
                                    const SizedBox(height: 20),
                                    const Text('Could not connect to server', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 8),
                                    const Text('Please check your network and try again.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                                    const SizedBox(height: 32),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }

                        // Access was revoked by the owner
                        if (profile['accessRevoked'] == true) {
                          return AccessRevokedScreen(revokedBy: profile['revokedBy'] as String?);
                        }
                        
                        final role = profile['role'];
                        final devices = profile['assignedDevices'] as List<dynamic>? ?? [];
                        final invites = profile['pendingInvitations'] as List<dynamic>? ?? [];

                        if (role == 'Guest' && devices.isEmpty && invites.isEmpty) {
                          return const NotRegisteredScreen();
                        }

                        return const MainScreen();
                      },
                      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
                      error: (err, _) {
                        // 403 = not registered in the admin system
                        if (err.toString().contains('403')) {
                          return const NotRegisteredScreen();
                        }
                        return Scaffold(
                          backgroundColor: Colors.white,
                          body: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
                                  const SizedBox(height: 20),
                                  const Text('Connection Error', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  Text(err.toString(), textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                  const SizedBox(height: 32),
                                  ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              }
              return const LoginScreen();
            },
          );
        },
      ),
    );
  }
}
