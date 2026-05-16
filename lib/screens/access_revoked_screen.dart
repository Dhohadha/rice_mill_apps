import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/providers.dart';

class AccessRevokedScreen extends ConsumerStatefulWidget {
  final String? revokedBy;

  const AccessRevokedScreen({super.key, this.revokedBy});

  @override
  ConsumerState<AccessRevokedScreen> createState() => _AccessRevokedScreenState();
}

class _AccessRevokedScreenState extends ConsumerState<AccessRevokedScreen> {
  bool _isLoggingOut = false;
  final Set<String> _processingInvites = {};

  @override
  Widget build(BuildContext context) {
    final userProfile = ref.watch(userProfileProvider);
    final invitations = (userProfile.value?['pendingInvitations'] as List<dynamic>? ?? []);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(36.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.no_accounts_rounded, size: 72, color: Colors.red.shade400),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Access Removed',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black87),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  widget.revokedBy != null
                      ? 'Your access to this Rice Mill has been removed by ${widget.revokedBy}.'
                      : 'Your access to this Rice Mill has been removed by the owner.',
                  style: const TextStyle(fontSize: 15, color: Colors.grey, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                
                if (invitations.isNotEmpty) ...[
                  const Divider(),
                  const SizedBox(height: 24),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'New Access Requests',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...invitations.map((invite) => _buildInvitationItem(context, Map<String, dynamic>.from(invite))),
                  const SizedBox(height: 24),
                  const Divider(),
                ],

                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoggingOut ? null : _signOut,
                    icon: _isLoggingOut
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.logout),
                    label: const Text('Sign Out', style: TextStyle(fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade400,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInvitationItem(BuildContext context, Map<String, dynamic> invite) {
    final ownerEmail = invite['ownerEmail'];
    final isProcessing = _processingInvites.contains(ownerEmail);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.share, color: Colors.orange),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(invite['millName'] ?? 'Rice Mill', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('From: $ownerEmail', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: isProcessing ? null : () async {
                  setState(() => _processingInvites.add(ownerEmail));
                  try {
                    final success = await ref.read(apiServiceProvider).declineInvitation(ownerEmail);
                    if (success) ref.read(userProfileProvider.notifier).refreshProfileQuietly();
                  } finally {
                    if (mounted) setState(() => _processingInvites.remove(ownerEmail));
                  }
                },
                child: const Text('Decline', style: TextStyle(color: Colors.red)),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: isProcessing ? null : () async {
                  setState(() => _processingInvites.add(ownerEmail));
                  try {
                    final success = await ref.read(apiServiceProvider).acceptInvitation(ownerEmail);
                    if (success) ref.read(userProfileProvider.notifier).refreshProfileQuietly();
                  } finally {
                    if (mounted) setState(() => _processingInvites.remove(ownerEmail));
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                child: isProcessing 
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Accept'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _signOut() async {
    setState(() => _isLoggingOut = true);
    try {
      await ref.read(authServiceProvider).signOut();
    } finally {
      if (mounted) setState(() => _isLoggingOut = false);
    }
  }
}
