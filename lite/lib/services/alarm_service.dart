import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';


class AlarmService {
  static final AlarmService _instance = AlarmService._internal();
  factory AlarmService() => _instance;
  AlarmService._internal();

  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;

  bool get isPlaying => _isPlaying;

  Future<void> playAlarm() async {
    if (_isPlaying) return;

    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(AssetSource('alarm.mp3'));
      _isPlaying = true;
    } catch (e) {
      debugPrint('❌ Error playing alarm: $e');
    }
  }

  Future<void> stopAlarm() async {
    if (!_isPlaying) return;

    try {
      await _player.stop();
      _isPlaying = false;
    } catch (e) {
      debugPrint('❌ Error stopping alarm: $e');
    }
  }

  void dispose() {
    _player.dispose();
  }
}
