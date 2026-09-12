import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AlarmService {
  static final AlarmService _instance = AlarmService._internal();
  factory AlarmService() => _instance;
  AlarmService._internal();

  static const MethodChannel _platform = MethodChannel('com.rice_mill.app/alarm');

  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;

  bool get isPlaying => _isPlaying;

  Future<void> playAlarm({String? title, String? body}) async {
    if (_isPlaying) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final isSoundEnabled = prefs.getBool('alert_sound_enabled') ?? true;
      if (!isSoundEnabled) {
        debugPrint('🔇 Alarm sound is disabled in settings. Skipping play.');
        return;
      }

      await prefs.setBool('alarm_playing', true);
      await prefs.setBool('isAlarmStopped', false);
      if (title != null) await prefs.setString('latest_alarm_title', title);
      if (body != null) await prefs.setString('latest_alarm_body', body);

      await _player.setReleaseMode(ReleaseMode.loop);
      try {
        await _player.play(AssetSource('alert fro ricemill.m4a'));
      } catch (_) {
        await _player.play(AssetSource('alarm.mp3'));
      }
      _isPlaying = true;

      // Invoke native startAlarm to start AlarmSoundService & LockScreenAlarmActivity if locked
      try {
        await _platform.invokeMethod('startAlarm');
      } catch (e) {
        debugPrint('Native startAlarm method channel error: $e');
      }
    } catch (e) {
      debugPrint('❌ Error playing alarm: $e');
    }
  }

  Future<void> stopAlarm() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('alarm_playing', false);
      await prefs.setBool('isAlarmStopped', true);

      await _player.stop();
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

  void dispose() {
    _player.dispose();
  }
}
