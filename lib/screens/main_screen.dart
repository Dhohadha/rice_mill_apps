import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rice_mill/services/providers.dart';
import 'monitoring_screen.dart';
import 'profile_screen.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  final List<Widget> _screens = [
    const MonitoringScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(tabIndexProvider);

    // Listen for invitations
    ref.listen(userProfileProvider, (previous, next) {
      if (next.hasValue && next.value != null) {
        final invites = next.value!['pendingInvitations'] as List<dynamic>? ?? [];
        if (invites.isNotEmpty) {
          _showInvitationDialog(context, Map<String, dynamic>.from(invites.first));
        }
      }
    });

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (index) => ref.read(tabIndexProvider.notifier).state = index,
          backgroundColor: Colors.white,
          selectedItemColor: Colors.teal,
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Monitoring',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  void _showInvitationDialog(BuildContext context, Map<String, dynamic> invite) {
    bool isProcessing = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.share, color: Colors.teal),
              SizedBox(width: 10),
              Text('Access Request', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${invite['ownerName']} wants to share device access with you.'),
              const SizedBox(height: 10),
              Text('Mill Name: ${invite['millName']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
              const SizedBox(height: 10),
              Text('Email: ${invite['ownerEmail']}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isProcessing ? null : () async {
                setDialogState(() => isProcessing = true);
                try {
                  final success = await ref.read(apiServiceProvider).declineInvitation(invite['ownerEmail']);
                  if (success) {
                    ref.read(userProfileProvider.notifier).refreshProfileQuietly();
                    if (context.mounted) Navigator.pop(context);
                  }
                } finally {
                  setDialogState(() => isProcessing = false);
                }
              },
              child: const Text('DECLINE', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: isProcessing ? null : () async {
                setDialogState(() => isProcessing = true);
                try {
                  final success = await ref.read(apiServiceProvider).acceptInvitation(invite['ownerEmail']);
                  if (success) {
                    ref.read(userProfileProvider.notifier).refreshProfileQuietly();
                    if (context.mounted) Navigator.pop(context);
                  }
                } finally {
                  setDialogState(() => isProcessing = false);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: isProcessing 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('ACCEPT'),
            ),
          ],
        ),
      ),
    );
  }
}
