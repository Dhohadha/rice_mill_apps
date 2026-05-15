import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/meter_data.dart';
import '../models/app_settings.dart';
import '../services/api_service.dart';
import 'mqtt_service.dart';

// 1. MQTT Service Provider
final mqttServiceProvider = Provider((ref) => MqttService());

// 2. Live Data Provider (From MQTT)
final mqttDataProvider = StreamProvider.family<MeterData, String>((ref, deviceId) {
  final mqtt = ref.watch(mqttServiceProvider);
  return mqtt.dataStream.where((data) => data.deviceId == deviceId);
});

// 3. Connectivity Provider
final connectivityProvider = StreamProvider<ConnectivityResult>((ref) async* {
  final initial = await Connectivity().checkConnectivity();
  if (initial.isNotEmpty) yield initial.first;
  yield* Connectivity().onConnectivityChanged.map((results) => results.first);
});

// 4. Dummy Server Status (Always true in Lite)
final serverStatusProvider = StreamProvider<bool>((ref) {
  return Stream.value(true);
});

// 5. API Service Provider
final apiServiceProvider = Provider((ref) => ApiService());

// 6. Dummy Auth Service Provider
final authServiceProvider = Provider((ref) => DummyAuthService());

// 7. Dummy User Profile Provider
final userProfileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  return {
    'name': 'Lite User',
    'email': 'lite@example.com',
    'role': 'Owner',
    'assignedDevices': ['RICE_MILL_001', 'RICE_MILL_002'],
    'isRegistered': true,
  };
});

// 8. Dummy Today Stats Provider
final todayPeriodStatsProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, deviceId) async {
  return {
    'totalConsumedKWh': 124.5,
    'avgPF': 0.895,
    'kva': {'max': 32.1, 'maxTime': DateTime.now().toIso8601String(), 'min': 1.2, 'minTime': DateTime.now().toIso8601String()},
    'kw': {'max': 28.5, 'maxTime': DateTime.now().toIso8601String(), 'min': 0.8, 'minTime': DateTime.now().toIso8601String()},
  };
});

// 9. Dummy Mixed Stats Provider
final mixedStatsProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  return {
    'totalConsumedKWh': 248.0,
    'avgPF': 0.880,
    'kva': {'max': 45.0, 'maxTime': DateTime.now().toIso8601String(), 'min': 2.5, 'minTime': DateTime.now().toIso8601String()},
    'kw': {'max': 40.0, 'maxTime': DateTime.now().toIso8601String(), 'min': 1.5, 'minTime': DateTime.now().toIso8601String()},
  };
});

// 10. Dummy Settings Provider
final settingsProvider = StateNotifierProvider<DummySettingsNotifier, AppSettings?>((ref) {
  return DummySettingsNotifier();
});

class DummySettingsNotifier extends StateNotifier<AppSettings?> {
  DummySettingsNotifier() : super(AppSettings(
    cmdLimit: 104,
    cmdMaxGauge: 250,
    powerLimit: 104,
    powerMaxGauge: 250,
    pfLimit: 0.85,
  ));
  void updateSettings(Map<String, dynamic> updates) {}
  Future<void> loadSettings() async {}
}

// 11. Dummy Consumption & Graph Providers
final consumedKwhProvider = FutureProvider.family<double, String>((ref, id) async => 124.5);
final todayKwhProvider = FutureProvider.family<double, String>((ref, id) async => 42.8);
final graphDataProvider = FutureProvider.family<List<dynamic>, String>((ref, id) async => []);

final isDayGraphProvider = StateNotifierProvider<DummyGraphNotifier, bool>((ref) => DummyGraphNotifier());
class DummyGraphNotifier extends StateNotifier<bool> {
  DummyGraphNotifier() : super(true);
  void toggle(bool isDay) => state = isDay;
}

// 12. Missing Analysis Providers
final sevenDayUsageProvider = FutureProvider.family<List<dynamic>, String>((ref, id) async => []);
final periodStatsProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, id) async => {});

// 13. Notifications Provider (History) - Wrapped in AsyncValue to satisfy UI
final notificationsProvider = StateNotifierProvider<DummyNotificationNotifier, AsyncValue<List<dynamic>>>((ref) {
  return DummyNotificationNotifier();
});

class DummyNotificationNotifier extends StateNotifier<AsyncValue<List<dynamic>>> {
  DummyNotificationNotifier() : super(const AsyncValue.data([]));
  
  Future<void> clearNotifications() async {
    state = const AsyncValue.data([]);
  }

  Future<void> deleteNotification(String id) async {
    state.whenData((list) {
      state = AsyncValue.data(list.where((n) => n['_id'] != id).toList());
    });
  }
}

final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());
final tabIndexProvider = StateProvider<int>((ref) => 0);

class DummyAuthService {
  Stream<dynamic> get authStateChanges => Stream.value({'uid': 'lite_user'});
  dynamic get currentUser => {'email': 'lite@example.com'};
  Future<void> signOut() async {}
  Future<void> signInWithGoogle() async {}
}
