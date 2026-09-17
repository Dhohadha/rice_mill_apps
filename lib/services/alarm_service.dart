import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AlarmService {
  static final AlarmService _instance = AlarmService._internal();
  factory AlarmService() => _instance;
  AlarmService._internal();

  static const MethodChannel _platform = MethodChannel('com.rice_mill.app/alarm');
  bool _isPlaying = false;

  bool get isPlaying => _isPlaying;

  /// Starts the alarm natively using AlarmSoundService & opens LockScreenAlarmActivity
  Future<void> playAlarm({String? title, String? body, String? alertId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isSoundEnabled = prefs.getBool('alert_sound_enabled') ?? true;
      if (!isSoundEnabled) {
        debugPrint('🔇 Alarm sound is disabled in settings. Skipping play.');
        return;
      }

      await prefs.setBool('alarm_playing', true);
      await prefs.setBool('flutter.alarm_playing', true);
      await prefs.setBool('isAlarmStopped', false);
      await prefs.setBool('flutter.isAlarmStopped', false);
      if (title != null) {
        await prefs.setString('latest_alarm_title', title);
        await prefs.setString('flutter.latest_alarm_title', title);
      }
      if (body != null) {
        await prefs.setString('latest_alarm_body', body);
        await prefs.setString('flutter.latest_alarm_body', body);
      }
      if (alertId != null) {
        await prefs.setString('latest_alert_id', alertId);
        await prefs.setString('flutter.latest_alert_id', alertId);
      }

      _isPlaying = true;

      // Invoke native startAlarm to start AlarmSoundService & launch LockScreenAlarmActivity
      try {
        await _platform.invokeMethod('startAlarm');
      } catch (e) {
        debugPrint('Native startAlarm method channel error: $e');
      }
    } catch (e) {
      debugPrint('❌ Error starting alarm: $e');
    }
  }

  /// Stops the alarm natively, cancels all notifications, and clears state flags
  Future<void> stopAlarm() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('alarm_playing', false);
      await prefs.setBool('flutter.alarm_playing', false);
      await prefs.setBool('isAlarmStopped', true);
      await prefs.setBool('flutter.isAlarmStopped', true);

      _isPlaying = false;

      // Invoke native stopAlarm to stop AlarmSoundService & finish LockScreenAlarmActivity
      try {
        await _platform.invokeMethod('stopAlarm');
      } catch (e) {
        debugPrint('Native stopAlarm method channel error: $e');
      }
    } catch (e) {
      debugPrint('❌ Error stopping alarm: $e');
    }
  }

  /// Clears lock screen flags from the current window to prevent roaming
  Future<void> removeLockScreenFlags() async {
    try {
      await _platform.invokeMethod('removeLockScreenFlags');
    } catch (e) {
      debugPrint('removeLockScreenFlags error: $e');
    }
  }

  /// Queries native side for current alarm playing status
  Future<bool> checkAlarmStatus() async {
    try {
      return await _platform.invokeMethod<bool>('checkAlarmStatus') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Queries native side whether the keyguard (lock screen) is currently active
  Future<bool> isScreenLocked() async {
    try {
      return await _platform.invokeMethod<bool>('isScreenLocked') ?? false;
    } catch (_) {
      return false;
    }
  }

  void dispose() {}
}
