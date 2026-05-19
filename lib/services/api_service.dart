import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_settings.dart';
import '../models/meter_data.dart';

class ApiService {
  // Using 10.0.2.2 for Android Emulator, localhost for others
  static const String _defaultIP = '13.233.76.8';
  static const String _envIP = String.fromEnvironment(
    'API_IP',
    defaultValue: _defaultIP,
  );

  static String get baseUrl {
    if (kIsWeb) return 'http://$_envIP:8000';
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        return 'http://$_envIP:8000';
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
        Uri.parse(
          '$baseUrl/api/daily-usage?fromDate=$dateStr&deviceId=$deviceId',
        ),
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

  Future<Map<String, dynamic>> verifyEmailToShare(String emailToShare) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/users/verify-email'),
        headers: await _getHeaders(),
        body: jsonEncode({'emailToShare': emailToShare}),
      );
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error verifying email: $e');
      return {'status': 'error', 'message': 'Network error. Please try again.'};
    }
  }

  Future<bool> revokeAccess(String sharedEmail) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/users/revoke-access/${Uri.encodeComponent(sharedEmail)}'),
        headers: await _getHeaders(),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error revoking access: $e');
      return false;
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

  Future<List<dynamic>> getHistoricalUsage(String deviceId, {int days = 50}) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/api/analysis/historical-usage?deviceId=$deviceId&days=$days',
        ),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
    } catch (e) {
      debugPrint('Error fetching historical usage: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>?> getPeriodStats(
    String deviceId,
    DateTime fromDate, {
    DateTime? toDate,
  }) async {
    try {
      final dateStr = fromDate.toIso8601String();
      String url =
          '$baseUrl/api/analysis/period-stats?deviceId=$deviceId&fromDate=$dateStr';
      if (toDate != null) {
        url += '&toDate=${toDate.toIso8601String()}';
      }
      final response = await http.get(
        Uri.parse(url),
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

  Future<Map<String, dynamic>?> getMixedStats(
    List<String> deviceIds,
    DateTime fromDate,
  ) async {
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

  Future<double> getRangeUsage(
    String deviceId,
    DateTime from,
    DateTime to,
  ) async {
    try {
      final fromStr = from.toIso8601String();
      final toStr = to.toIso8601String();
      final response = await http.get(
        Uri.parse(
          '$baseUrl/api/analysis/range-usage?deviceId=$deviceId&fromDate=$fromStr&toDate=$toStr',
        ),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['totalKWhConsumed'] ?? 0).toDouble();
      }
    } catch (e) {
      debugPrint('Error fetching range usage: $e');
    }
    return 0.0;
  }

  Future<List<dynamic>> getMonthlyUsage(String deviceId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/analysis/monthly-usage?deviceId=$deviceId'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
    } catch (e) {
      debugPrint('Error fetching monthly usage: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>?> updateProfile(Map<String, dynamic> updates) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/users/profile/update'),
        headers: await _getHeaders(),
        body: jsonEncode(updates),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['user'] as Map<String, dynamic>?;
      }
    } catch (e) {
      debugPrint('Error updating profile API: $e');
    }
    return null;
  }
}
