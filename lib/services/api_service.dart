import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_settings.dart';
import '../models/meter_data.dart';

class ApiService {
  // Using 10.0.2.2 for Android Emulator, localhost for others
  static const String _defaultIP = '192.168.1.5';
  static const String _envIP = String.fromEnvironment('API_IP', defaultValue: _defaultIP);

  static String get baseUrl {
    if (kIsWeb) return 'http://192.168.64.1:8000';
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        return 'http://192.168.64.1:8000';
      }
    } catch (_) {}
    return 'http://localhost:8000';
  }



  Future<Map<String, String>> _getHeaders() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  } 

  Future<bool> checkHealth() async {
    // Try up to 2 times before deciding it's offline
    for (int i = 0; i < 2; i++) {
      try {
        final response = await http.get(Uri.parse(baseUrl)).timeout(const Duration(seconds: 7));
        if (response.statusCode == 200) return true;
      } catch (e) {
        debugPrint('⚠️ Health check attempt ${i + 1} failed: $e');
      }
      if (i == 0) await Future.delayed(const Duration(seconds: 1));
    }
    return false;
  }

  Future<Map<String, dynamic>?> syncUser() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/users/sync'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 403) {
        throw '403: Not Registered';
      }
    } catch (e) {
      debugPrint('Error syncing user: $e');
      rethrow;
    }
    return null;
  }

  Future<MeterData?> getLatestStatus(String deviceId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/status?deviceId=$deviceId'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return MeterData.fromJson(jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint('Error fetching latest status: $e');
    }
    return null;
  }

  Future<AppSettings> getSettings() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/settings'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return AppSettings.fromJson(jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint('Error fetching settings: $e');
    }
    return AppSettings(
      cmdLimit: 150,
      cmdMaxGauge: 250,
      powerLimit: 150,
      powerMaxGauge: 250,
      pfLimit: 0.90,
    );
  }

  Future<void> updateSettings(Map<String, dynamic> updates) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/api/settings'),
        headers: await _getHeaders(),
        body: jsonEncode(updates),
      );
    } catch (e) {
      debugPrint('Error updating settings: $e');
    }
  }

  Future<double> getDailyUsage(String dateStr, String deviceId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/daily-usage?fromDate=$dateStr&deviceId=$deviceId'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['totalKWhConsumed'] ?? 0).toDouble();
      }
    } catch (e) {
      debugPrint('Error fetching daily usage: $e');
    }
    return 0.0;
  }

  Future<double> getTodayUsage(String deviceId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/today-usage?deviceId=$deviceId'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['todayKWh'] ?? 0).toDouble();
      }
    } catch (e) {
      debugPrint('Error fetching today usage: $e');
    }
    return 0.0;
  }

  Future<List<dynamic>> getHistory(String type, String deviceId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/history?range=$type&deviceId=$deviceId'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      } else {
        debugPrint('Failed to load history: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching history: $e');
    }
    return [];
  }

  Future<List<dynamic>> getNotifications() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/notifications'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
    }
    return [];
  }

  Future<void> deleteNotification(String id) async {
    try {
      await http.delete(
        Uri.parse('$baseUrl/api/notifications/$id'),
        headers: await _getHeaders(),
      );
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }

  Future<void> clearNotifications() async {
    try {
      await http.delete(
        Uri.parse('$baseUrl/api/notifications'),
        headers: await _getHeaders(),
      );
    } catch (e) {
      debugPrint('Error clearing notifications: $e');
    }
  }

  Future<bool> shareAccess(String emailToShare, List<String> deviceIds) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/users/share'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'emailToShare': emailToShare,
          'deviceIds': deviceIds,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error sharing access: $e');
      return false;
    }
  }

  Future<List<dynamic>> get7DayUsage(String deviceId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/analysis/7day-usage?deviceId=$deviceId'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
    } catch (e) {
      debugPrint('Error fetching 7-day usage: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>?> getPeriodStats(String deviceId, DateTime fromDate) async {
    try {
      final dateStr = fromDate.toIso8601String();
      final response = await http.get(
        Uri.parse('$baseUrl/api/analysis/period-stats?deviceId=$deviceId&fromDate=$dateStr'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error fetching period stats: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> getMixedStats(List<String> deviceIds, DateTime fromDate) async {
    try {
      final dateStr = fromDate.toIso8601String();
      String query = 'fromDate=$dateStr';
      for (final id in deviceIds) {
        query += '&deviceIds=$id';
      }
      final response = await http.get(
        Uri.parse('$baseUrl/api/analysis/mixed-stats?$query'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error fetching mixed stats: $e');
    }
    return null;
  }

  Future<bool> addGuestDevice(String deviceId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/users/add-guest-device'),
        headers: await _getHeaders(),
        body: jsonEncode({'deviceId': deviceId}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error adding guest device: $e');
      return false;
    }
  }

  Future<bool> removeGuestDevice(String deviceId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/users/remove-guest-device/$deviceId'),
        headers: await _getHeaders(),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error removing guest device: $e');
      return false;
    }
  }

  Future<bool> acceptInvitation(String ownerEmail) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/users/invitations/accept'),
        headers: await _getHeaders(),
        body: jsonEncode({'ownerEmail': ownerEmail}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error accepting invitation: $e');
      return false;
    }
  }

  Future<bool> declineInvitation(String ownerEmail) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/users/invitations/decline'),
        headers: await _getHeaders(),
        body: jsonEncode({'ownerEmail': ownerEmail}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error declining invitation: $e');
      return false;
    }
  }

  Future<List<dynamic>> getSharedDetails(String email) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/users/$email/shared-details'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      debugPrint('Error fetching shared details: $e');
    }
    return [];
  }
}
