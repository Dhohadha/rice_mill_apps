import 'package:flutter/foundation.dart';
import '../models/app_settings.dart';
import '../models/meter_data.dart';

class ApiService {
  static String get baseUrl => 'http://localhost:8000';

  // Serverless: All methods return dummy data or success immediately
  Future<bool> checkHealth() async => true;
  Future<Map<String, dynamic>?> syncUser() async => {
    'name': 'Lite User',
    'email': 'lite@example.com',
    'role': 'Owner',
    'assignedDevices': ['RICE_MILL_001', 'RICE_MILL_002'],
    'isRegistered': true,
  };
  
  Future<MeterData?> getLatestStatus(String deviceId) async => null;
  
  Future<AppSettings> getSettings() async => AppSettings(
    cmdLimit: 104,
    cmdMaxGauge: 250,
    powerLimit: 104,
    powerMaxGauge: 250,
    pfLimit: 0.85,
  );

  Future<void> updateSettings(Map<String, dynamic> updates) async {}
  Future<double> getDailyUsage(String dateStr, String deviceId) async => 124.5;
  Future<double> getTodayUsage(String deviceId) async => 42.8;
  Future<List<dynamic>> getHistory(String type, String deviceId) async => [];
  Future<List<dynamic>> getNotifications() async => [];
  Future<void> deleteNotification(String id) async {}
  Future<void> clearNotifications() async {}
  Future<bool> shareAccess(String emailToShare, List<String> deviceIds) async => true;
  Future<List<dynamic>> get7DayUsage(String deviceId) async => [];
  Future<Map<String, dynamic>?> getPeriodStats(String deviceId, DateTime fromDate) async => {};
  Future<Map<String, dynamic>?> getMixedStats(List<String> deviceIds, DateTime fromDate) async => {};
  Future<bool> addGuestDevice(String deviceId) async => true;
  Future<bool> removeGuestDevice(String deviceId) async => true;
  Future<bool> acceptInvitation(String ownerEmail) async => true;
  Future<bool> declineInvitation(String ownerEmail) async => true;
  Future<List<dynamic>> getSharedDetails(String email) async => [];
}
