import 'dart:async';
import 'package:flutter/material.dart';
import '../services/alarm_service.dart';
import '../services/notification_service.dart';

class AlarmScreen extends StatefulWidget {
  final String title;
  final String body;
  final String alertId;

  const AlarmScreen({
    super.key,
    this.title = '⚠️ Threshold Alert!',
    this.body = 'Critical condition detected. Tap STOP to acknowledge.',
    this.alertId = 'ALARM_ID',
  });

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  late String _displayTitle;
  late String _displayBody;
  late String _alertId;
  Timer? _statusWatcher;

  @override
  void initState() {
    super.initState();
    _displayTitle = widget.title;
    _displayBody = widget.body;
    _alertId = widget.alertId;

    // Pulsing animation for alarm ring & button
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Watch for external stop (e.g. system notification "STOP ALARM" button pressed)
    _statusWatcher = Timer.periodic(const Duration(seconds: 1), (_) {
      _checkExternalStop();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      setState(() {
        if (args.containsKey('title')) _displayTitle = args['title'] as String;
        if (args.containsKey('body')) _displayBody = args['body'] as String;
        if (args.containsKey('alertId')) _alertId = args['alertId'] as String;
      });
    }
  }

  Future<void> _checkExternalStop() async {
    try {
      final isPlaying = await AlarmService().checkAlarmStatus();
      if (!isPlaying && mounted) {
        debugPrint('[AlarmScreen] Alarm stopped externally — dismissing full screen');
        _dismissScreen();
      }
    } catch (e) {
      debugPrint('[AlarmScreen] Error checking stop flag: $e');
    }
  }

  Future<void> _handleStopAlarm() async {
    debugPrint('[AlarmScreen] STOP button pressed on screen');
    _statusWatcher?.cancel();

    // 1. Stop native alarm audio & clear flags
    AlarmService().stopAlarm();

    // 2. Cancel all notifications
    NotificationService().cancelAlert();

    // 3. Drop lock screen flags to prevent roaming
    AlarmService().removeLockScreenFlags();

    // 4. Send stop signal to server
    NotificationService.stopAlertOnServer(_alertId);

    if (mounted) {
      _dismissScreen();
    }
  }

  void _dismissScreen() {
    _statusWatcher?.cancel();
    AlarmService().removeLockScreenFlags();
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _statusWatcher?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF8B0000), // Dark Red
                Color(0xFF1A0000),
                Colors.black,
              ],
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Warning Icon
                          AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) => Transform.scale(
                              scale: _pulseAnimation.value,
                              child: const Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.amberAccent,
                                size: 90,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Header Text
                          AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) => Text(
                              '🚨 CRITICAL ALERT 🚨',
                              style: TextStyle(
                                color: Colors.red.shade300,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 3,
                              ),
                            ),
                          ),
                          const SizedBox(height: 36),

                          // Title
                          Text(
                            _displayTitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Body Message
                          Text(
                            _displayBody,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 18,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 50),

                          // Large Pulsing STOP Button
                          GestureDetector(
                            onTap: _handleStopAlarm,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Outer Pulsing Aura
                                AnimatedBuilder(
                                  animation: _pulseAnimation,
                                  builder: (context, _) => Container(
                                    width: 190 * _pulseAnimation.value,
                                    height: 190 * _pulseAnimation.value,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.red.withValues(
                                        alpha: 0.25 * (2.0 - _pulseAnimation.value),
                                      ),
                                    ),
                                  ),
                                ),
                                // Inner Red Button
                                AnimatedBuilder(
                                  animation: _pulseAnimation,
                                  builder: (context, _) => Transform.scale(
                                    scale: 1.0 + (_pulseAnimation.value - 1.0) * 0.3,
                                    child: Container(
                                      width: 145,
                                      height: 145,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.red.shade600,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.red.withValues(alpha: 0.6),
                                            blurRadius: 25,
                                            spreadRadius: 6,
                                          ),
                                        ],
                                      ),
                                      child: const Center(
                                        child: Text(
                                          'STOP',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 32,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
