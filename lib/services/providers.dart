import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_settings.dart';
import '../models/meter_data.dart';
import '../services/socket_service.dart';
import '../services/notification_service.dart';
import '../services/alarm_service.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';



final apiServiceProvider = Provider((ref) => ApiService());
final socketServiceProvider = Provider((ref) => SocketService());
final authServiceProvider = Provider((ref) => AuthService());
final notificationServiceProvider = Provider((ref) => NotificationService());
final alarmServiceProvider = Provider((ref) => AlarmService());

final userProfileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return await api.syncUser();
});

// Settings Provider
final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings?>(() {
  return SettingsNotifier();
});

class SettingsNotifier extends Notifier<AppSettings?> {
  late ApiService _apiService;

  @override
  AppSettings? build() {
    _apiService = ref.watch(apiServiceProvider);
    loadSettings();
    return null;
  }

  Future<void> loadSettings() async {
    try {
      final settings = await _apiService.getSettings();
      state = settings;
    } catch (e) {
      // Error logging can be handled by a dedicated service in production
    }
  }

  Future<void> updateSettings(Map<String, dynamic> updates) async {
    try {
      await _apiService.updateSettings(updates);
      await loadSettings();
    } catch (e) {
      // Error logging
    }
  }
}

// MQTT Data Provider (Family)
final mqttDataProvider = StreamProvider.family<MeterData, String>((ref, deviceId) async* {
  final api = ref.watch(apiServiceProvider);
  final socketService = ref.watch(socketServiceProvider);
  
  // Fetch initial data so the user doesn't see a blank screen while waiting for the next MQTT packet
  final initialData = await api.getLatestStatus(deviceId);
  if (initialData != null) {
    yield initialData;
  } else {
    // If no data exists in DB yet, show an empty state instead of a permanent loading spinner
    yield MeterData.empty(deviceId);
  }
  
  // Connect to device room
  socketService.connect(deviceId);
  
  // Stream subsequent updates
  yield* socketService.dataStream.where((newData) => newData.deviceId == deviceId);
});

// Selected Date Provider using Notifier (replacement for StateProvider)
final selectedDateProvider = NotifierProvider<SelectedDateNotifier, DateTime>(() {
  return SelectedDateNotifier();
});

class SelectedDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => DateTime.now().subtract(const Duration(days: 7));
  
  void setDate(DateTime date) => state = date;
}

// Consumed KWH Provider (Family)
final consumedKwhProvider = FutureProvider.family<double, String>((ref, deviceId) async {
  final api = ref.watch(apiServiceProvider);
  final date = ref.watch(selectedDateProvider);
  final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  return await api.getDailyUsage(dateStr, deviceId);
});

// Today's KWH Provider (Family) - Midnight to Now
final todayKwhProvider = FutureProvider.family<double, String>((ref, deviceId) async {
  final api = ref.watch(apiServiceProvider);
  return await api.getTodayUsage(deviceId);
});

// Analysis: Historical Usage Provider (up to 50 days)
final historicalUsageProvider = FutureProvider.family<List<dynamic>, String>((ref, deviceId) async {
  final api = ref.watch(apiServiceProvider);
  return await api.getHistoricalUsage(deviceId, days: 50);
});

// Analysis: Period Stats Provider
final periodStatsProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, deviceId) async {
  final api = ref.watch(apiServiceProvider);
  final fromDate = ref.watch(selectedDateProvider);
  return await api.getPeriodStats(deviceId, fromDate);
});

// Analysis: Today's Period Stats Provider (Fixed to Today's Midnight)
final todayPeriodStatsProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, deviceId) async {
  final api = ref.watch(apiServiceProvider);
  final todayMidnight = DateTime.now().copyWith(hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0);
  return await api.getPeriodStats(deviceId, todayMidnight);
});

// Analysis: Mixed Stats Provider
final mixedStatsProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final api = ref.watch(apiServiceProvider);
  final profile = ref.watch(userProfileProvider).value;
  if (profile == null) return null;
  
  final deviceIds = List<String>.from(profile['assignedDevices'] ?? []);
  if (deviceIds.isEmpty) return null;

  final fromDate = ref.watch(selectedDateProvider);
  return await api.getMixedStats(deviceIds, fromDate);
});

// Graph Toggle Provider using Notifier
final isDayGraphProvider = NotifierProvider<IsDayGraphNotifier, bool>(() {
  return IsDayGraphNotifier();
});

// Tab Index Provider for MainScreen
final tabIndexProvider = StateProvider<int>((ref) => 0);

class IsDayGraphNotifier extends Notifier<bool> {
  @override
  bool build() => true;
  
  void toggle(bool value) => state = value;
}

// Graph Data Provider (Family)
final graphDataProvider = FutureProvider.family<List<dynamic>, String>((ref, deviceId) async {
  final api = ref.watch(apiServiceProvider);
  final isDay = ref.watch(isDayGraphProvider);
  return await api.getHistory(isDay ? 'day' : 'hour', deviceId);
});

// Analysis: Monthly Usage Provider
final monthlyUsageProvider = FutureProvider.family<List<dynamic>, String>((ref, deviceId) async {
  final api = ref.watch(apiServiceProvider);
  return await api.getMonthlyUsage(deviceId);
});

// The date currently selected in the AnalysisScreen chart
final focusedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

// Stats for a specific day (midnight to midnight)
final dailyStatsProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, deviceId) async {
  final focusedDate = ref.watch(focusedDateProvider);
  final api = ref.watch(apiServiceProvider);
  final from = DateTime(focusedDate.year, focusedDate.month, focusedDate.day);
  final to = from.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
  return await api.getPeriodStats(deviceId, from, toDate: to);
});

// Consumption for a specific day
final dailyConsumptionProvider = FutureProvider.family<double, String>((ref, deviceId) async {
  final focusedDate = ref.watch(focusedDateProvider);
  final api = ref.watch(apiServiceProvider);
  final from = DateTime(focusedDate.year, focusedDate.month, focusedDate.day);
  
  final now = DateTime.now();
  if (from.year == now.year && from.month == now.month && from.day == now.day) {
    return await api.getTodayUsage(deviceId);
  }
  return await api.getRangeUsage(deviceId, from, from);
});

// Notifications Provider using AsyncNotifier
final notificationsProvider = AsyncNotifierProvider<NotificationsNotifier, List<dynamic>>(() {
  return NotificationsNotifier();
});

class NotificationsNotifier extends AsyncNotifier<List<dynamic>> {
  @override
  FutureOr<List<dynamic>> build() async {
    final api = ref.watch(apiServiceProvider);
    return await api.getNotifications();
  }

  Future<void> deleteNotification(String id) async {
    final api = ref.read(apiServiceProvider);
    
    // 1. Optimistically update local state immediately
    if (state.hasValue) {
      final currentList = state.value!;
      state = AsyncData(currentList.where((n) => (n['_id']?.toString() ?? '') != id).toList());
    }

    try {
      // 2. Perform the server-side deletion
      await api.deleteNotification(id);
    } catch (e) {
      // 3. Rolling back if server deletion fails
      ref.invalidateSelf();
    }
  }

  Future<void> clearNotifications() async {
    final api = ref.read(apiServiceProvider);
    state = const AsyncData([]);
    try {
      await api.clearNotifications();
    } catch (e) {
      ref.invalidateSelf();
    }
  }
}
