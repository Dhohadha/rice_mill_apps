import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/providers.dart';

class ConnectionWrapper extends ConsumerWidget {
  final Widget child;
  const ConnectionWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivity = ref.watch(connectivityProvider);

    return connectivity.when(
      data: (result) {
        if (result == ConnectivityResult.none) {
          return const _StatusOverlay(
            title: 'No Network Connection',
            message: 'Please check your WiFi or Data settings to receive live monitoring updates.',
            icon: Icons.wifi_off_rounded,
            color: Colors.orange,
          );
        }
        return child;
      },
      loading: () => child,
      error: (_, __) => child,
    );
  }
}

class _StatusOverlay extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final Color color;

  const _StatusOverlay({
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 80, color: color),
            ),
            const SizedBox(height: 32),
            Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(color.withValues(alpha: 0.5)),
              strokeWidth: 2,
            ),
            const SizedBox(height: 16),
            Text(
              'Retrying...',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade400,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
