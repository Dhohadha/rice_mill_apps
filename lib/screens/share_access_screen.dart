import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/providers.dart';
import '../services/api_service.dart';

class ShareAccessScreen extends ConsumerStatefulWidget {
  const ShareAccessScreen({super.key});

  @override
  ConsumerState<ShareAccessScreen> createState() => _ShareAccessScreenState();
}

class _ShareAccessScreenState extends ConsumerState<ShareAccessScreen> {
  final _emailController = TextEditingController();
  bool _isSharing = false;
  final Set<String> _selectedDevices = {};

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  /// Step 1: Verify email. Shows blocking loading dialog while checking.
  Future<void> _handleShare() async {
    final email = _emailController.text.trim().toLowerCase();

    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      _showSnack('Please enter a valid email address.');
      return;
    }

    if (_selectedDevices.isEmpty) {
      _showSnack('Please select at least one device to share.');
      return;
    }

    // Show verifying loading dialog
    _showLoadingDialog('Verifying email...');

    final result = await ref.read(apiServiceProvider).verifyEmailToShare(email);

    if (!mounted) return;
    Navigator.pop(context); // Close loading dialog

    final status = result['status'] as String? ?? 'error';

    switch (status) {
      case 'no_permission':
        _showBlockedDialog(
          icon: Icons.block,
          iconColor: Colors.red,
          title: 'Not Allowed',
          message: result['message'] ?? 'Shared users cannot share access with others.',
        );
        break;

      case 'self':
        _showBlockedDialog(
          icon: Icons.person_off,
          iconColor: Colors.red,
          title: 'Cannot Share With Yourself',
          message: result['message'] ?? 'You cannot share access with your own account.',
        );
        break;

      case 'already_shared':
        _showBlockedDialog(
          icon: Icons.check_circle_outline,
          iconColor: Colors.orange,
          title: 'Already Shared',
          message: result['message'] ?? 'You have already shared access with this email.',
        );
        break;

      case 'is_owner':
        _showBlockedDialog(
          icon: Icons.block,
          iconColor: Colors.red,
          title: 'Cannot Share',
          message: result['message'] ?? 'You cannot share access with another owner.',
        );
        break;

      case 'error':
        _showSnack(result['message'] ?? 'An error occurred. Please try again.');
        break;

      case 'new_user':
        // User doesn't exist yet — show confirmation
        _showConfirmDialog(
          email: email,
          title: 'Send Invite?',
          icon: Icons.person_add,
          iconColor: Colors.teal,
          bodyContent: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(result['message'] ?? '', style: const TextStyle(color: Colors.black87)),
              const SizedBox(height: 12),
              const Text('An invite will be created for this email. They will see it when they sign into the app.', style: TextStyle(color: Colors.grey, fontSize: 13)),
            ],
          ),
        );
        break;

      case 'ok':
        final name = result['name'] as String? ?? email;
        final sharedByOther = result['sharedByOtherOwner'] == true;
        final otherOwner = result['otherOwnerEmail'] as String? ?? '';

        _showConfirmDialog(
          email: email,
          title: 'Confirm Sharing',
          icon: Icons.person,
          iconColor: Colors.teal,
          bodyContent: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.verified_user, color: Colors.green, size: 16),
                  const SizedBox(width: 6),
                  Expanded(child: Text('User found: $name', style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600))),
                ],
              ),
              if (sharedByOther) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Already managed by $otherOwner. They can still receive your invite.',
                          style: const TextStyle(fontSize: 12, color: Colors.orange),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                'Share ${_selectedDevices.length} device(s) with $email?',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
        );
        break;
    }
  }

  /// Step 2: Actually perform the share after confirmation.
  Future<void> _doShare(String email) async {
    setState(() => _isSharing = true);
    final success = await ref.read(apiServiceProvider).shareAccess(email, _selectedDevices.toList());
    setState(() => _isSharing = false);

    if (!mounted) return;

    if (success) {
      _showSnack('Invite sent successfully to $email!');
      _emailController.clear();
      setState(() => _selectedDevices.clear());
    } else {
      _showSnack('Failed to send invite. Please try again.');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Row(
            children: [
              const CircularProgressIndicator(color: Colors.teal),
              const SizedBox(width: 20),
              Text(message, style: const TextStyle(fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }

  void _showBlockedDialog({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
  }) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontSize: 16)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showConfirmDialog({
    required String email,
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget bodyContent,
  }) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 16))),
          ],
        ),
        content: bodyContent,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _doShare(email);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('YES, SEND INVITE'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProfile = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Share Access'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: userProfile.when(
        skipLoadingOnReload: true,
        loading: () {
          // Check for pre-selection even in loading state if data is available from previous load
          if (userProfile.hasValue && userProfile.value != null) {
            final devices = List<String>.from(userProfile.value!['assignedDevices'] ?? []);
            if (devices.length == 1 && _selectedDevices.isEmpty) {
              Future.microtask(() {
                if (mounted) setState(() => _selectedDevices.add(devices.first));
              });
            }
          }
          return const SizedBox.shrink();
        },
        error: (err, _) => Center(child: Text('Error loading devices: $err')),
        data: (profile) {
          final allDevices = List<String>.from(
            profile?['assignedDevices'] ?? [],
          );

          // Auto-select if only one device
          if (allDevices.length == 1 && _selectedDevices.isEmpty) {
            Future.microtask(() {
              if (mounted) setState(() => _selectedDevices.add(allDevices.first));
            });
          }

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.share, size: 80, color: Colors.teal),
                  const SizedBox(height: 24),
                  const Text(
                    'Share your Rice Mill with others',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Select the devices and enter the Gmail address of the person you want to give access to.',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Device Selection Section
                  if (allDevices.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Select Devices:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Row(
                          children: [
                            const Text('Select All', style: TextStyle(fontSize: 14)),
                            Checkbox(
                              value: _selectedDevices.length == allDevices.length && allDevices.isNotEmpty,
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedDevices.addAll(allDevices);
                                  } else {
                                    _selectedDevices.clear();
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(),
                    ...allDevices.map(
                      (deviceId) => CheckboxListTile(
                        title: Text(deviceId),
                        value: _selectedDevices.contains(deviceId),
                        activeColor: Colors.teal,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedDevices.add(deviceId);
                            } else {
                              _selectedDevices.remove(deviceId);
                            }
                          });
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],

                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Gmail Address',
                      hintText: 'example@gmail.com',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isSharing ? null : _handleShare,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSharing
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Share Access', style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(height: 40),
                  const Text(
                    'People with Access',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                  _SharedUsersList(
                    ownerEmail: profile!['email'] as String,
                    api: ref.read(apiServiceProvider),
                    onRevoke: () => ref.read(userProfileProvider.notifier).refreshProfileQuietly(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Separate StatefulWidget to allow local rebuild on revoke ───────────────
class _SharedUsersList extends StatefulWidget {
  final String ownerEmail;
  final ApiService api;
  final VoidCallback onRevoke;

  const _SharedUsersList({
    required this.ownerEmail,
    required this.api,
    required this.onRevoke,
  });

  @override
  State<_SharedUsersList> createState() => _SharedUsersListState();
}

class _SharedUsersListState extends State<_SharedUsersList> {
  late Future<List<dynamic>> _future;
  final Set<String> _revoking = {};

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    _future = widget.api.getSharedDetails(widget.ownerEmail);
  }

  Future<void> _revoke(String email) async {
    setState(() => _revoking.add(email));
    final success = await widget.api.revokeAccess(email);
    if (!mounted) return;
    if (success) {
      setState(() {
        _revoking.remove(email);
        _refresh();
      });
      widget.onRevoke();
    } else {
      setState(() => _revoking.remove(email));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to revoke access. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator(color: Colors.teal)),
          );
        }
        if (snapshot.data!.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text('No users shared yet.', style: TextStyle(color: Colors.grey)),
          );
        }
        return Column(
          children: snapshot.data!.map((user) {
            final isPending = user['status'] == 'Pending';
            final email = user['email'] as String;
            final isRevoking = _revoking.contains(email);

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: isPending ? Colors.grey[200] : Colors.teal[50],
                    child: Icon(Icons.person, size: 20, color: isPending ? Colors.grey : Colors.teal),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(email, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        Text(
                          '${user['role']} • ${user['status']}',
                          style: TextStyle(fontSize: 11, color: isPending ? Colors.orange : Colors.green),
                        ),
                      ],
                    ),
                  ),
                  // Revoke button
                  if (isRevoking)
                    const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red))
                  else
                    IconButton(
                      icon: const Icon(Icons.person_remove_outlined, color: Colors.red, size: 20),
                      tooltip: 'Remove access',
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Remove Access'),
                            content: Text('Remove $email\'s access to your devices?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('REMOVE', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ) ?? false;
                        if (confirmed) _revoke(email);
                      },
                    ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
