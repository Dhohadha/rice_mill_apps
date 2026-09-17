import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Checks and prompts the user to grant the USE_FULL_SCREEN_INTENT permission.
///
/// On Android 14+ (API 34) this permission is required for the alarm screen to
/// appear over the lock screen. Without it, only a notification banner is shown.
class AlarmPermissionHelper {
  static const _platform = MethodChannel('com.rice_mill.app/alarm');
  static const _askedKey = 'full_screen_intent_permission_asked';

  /// Checks the permission and shows a dialog if it's not granted.
  static Future<void> checkAndPromptIfNeeded(BuildContext context) async {
    try {
      final bool hasPermission =
          await _platform.invokeMethod<bool>('checkFullScreenPermission') ?? true;

      if (hasPermission) return;

      final prefs = await SharedPreferences.getInstance();
      final bool alreadyAsked = prefs.getBool(_askedKey) ?? false;
      if (alreadyAsked) return;

      await prefs.setBool(_askedKey, true);

      if (!context.mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const _FullScreenIntentDialog(platform: _platform),
      );
    } catch (e) {
      debugPrint('[AlarmPermission] Check failed: $e');
    }
  }

  static Future<bool> isGranted() async {
    try {
      return await _platform.invokeMethod<bool>('checkFullScreenPermission') ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> openSettings() async {
    try {
      await _platform.invokeMethod('openFullScreenSettings');
    } catch (e) {
      debugPrint('[AlarmPermission] openFullScreenSettings failed: $e');
    }
  }
}

class _FullScreenIntentDialog extends StatelessWidget {
  final MethodChannel platform;
  const _FullScreenIntentDialog({required this.platform});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      icon: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.alarm_on_rounded, color: Colors.red, size: 32),
      ),
      title: const Text(
        'Enable Lock-Screen Alarm',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
        textAlign: TextAlign.center,
      ),
      content: const Text(
        'To show the emergency alarm screen when your phone is locked, please allow '
        '"Display pop-up windows when locked" or "Full-screen notifications" for Grid Pulse.\n\n'
        'Without this, critical threshold alarms may only show a standard banner.',
        style: TextStyle(
          color: Colors.white70,
          fontSize: 14,
          height: 1.5,
        ),
        textAlign: TextAlign.center,
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Later',
            style: TextStyle(color: Colors.white38),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade700,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          onPressed: () async {
            Navigator.of(context).pop();
            try {
              await platform.invokeMethod('openFullScreenSettings');
            } catch (e) {
              debugPrint('[AlarmPermission] openFullScreenSettings failed: $e');
            }
          },
          child: const Text(
            'Open Settings',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
