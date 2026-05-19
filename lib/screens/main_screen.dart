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

  bool _hasShownPrompt = false;

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(tabIndexProvider);

    // Listen for invitations and missing profile details
    ref.listen(userProfileProvider, (previous, next) {
      if (next.hasValue && next.value != null) {
        final user = next.value!;

        // 1. Check for invitations first
        final invites = user['pendingInvitations'] as List<dynamic>? ?? [];
        if (invites.isNotEmpty) {
          _showInvitationDialog(context, Map<String, dynamic>.from(invites.first));
          return;
        }

        // 2. Check for missing details and prompt if not shown yet
        if (!_hasShownPrompt) {
          final isShared = user['isSharedUser'] == true;
          if (isShared) {
            final name = user['name']?.toString() ?? '';
            final email = user['email']?.toString() ?? '';
            final emailPrefix = email.split('@')[0];
            final isPlaceholder = name.trim().isEmpty || name.contains('@') || name == emailPrefix;

            if (isPlaceholder) {
              _hasShownPrompt = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _showMissingDetailDialog(context, isShared: true);
              });
            }
          } else {
            final millName = user['millName']?.toString() ?? '';
            if (millName.trim().isEmpty) {
              _hasShownPrompt = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _showMissingDetailDialog(context, isShared: false);
              });
            }
          }
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

  void _showMissingDetailDialog(BuildContext context, {required bool isShared}) {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      barrierDismissible: false, // Force they must enter it!
      builder: (context) => PopScope(
        canPop: false, // Prevent physical back button
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(isShared ? Icons.person : Icons.factory_outlined, color: Colors.teal),
              const SizedBox(width: 10),
              Text(
                isShared ? 'Enter Your Name' : 'Enter Mill Name', 
                style: const TextStyle(fontWeight: FontWeight.bold)
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isShared 
                  ? 'Please enter your full name to show it in the application and invite logs.'
                  : 'Please enter your Rice Mill name to complete your profile.',
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: isShared ? 'Your Full Name' : 'Rice Mill Name',
                  prefixIcon: Icon(isShared ? Icons.person_outline : Icons.factory_outlined, color: Colors.teal),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                  filled: true,
                  fillColor: Colors.grey.withOpacity(0.05),
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                final text = controller.text.trim();
                if (text.isEmpty) return;

                Navigator.pop(context);

                try {
                  final updates = isShared ? {'name': text} : {'millName': text};
                  await ref.read(userProfileProvider.notifier).updateProfile(updates);
                  
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isShared 
                            ? 'Welcome, $text!' 
                            : 'Rice Mill Name set to $text successfully!'
                        )
                      ),
                    );
                  }
                } catch (e) {
                  // If update failed, allow trying again
                  setState(() => _hasShownPrompt = false);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to update: $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                minimumSize: const Size(120, 45),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
