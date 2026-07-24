import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rice_mill/screens/mixed_analysis_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/providers.dart';
import '../services/alarm_service.dart';
import 'share_access_screen.dart';
import 'notifications_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isLoggingOut = false;
  final Set<String> _processingInvites = {}; // Set of ownerEmails being processed
  bool _isAlarmSoundEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadAlarmSetting();
  }

  Future<void> _loadAlarmSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isAlarmSoundEnabled = prefs.getBool('alert_sound_enabled') ?? true;
    });
  }

  Future<void> _toggleAlarmSetting(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('alert_sound_enabled', value);
    setState(() {
      _isAlarmSoundEnabled = value;
    });

    if (!value) {
      await AlarmService().stopAlarm();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value ? '🔊 Alarm sound enabled' : '🔇 Alarm sound muted'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProfile = ref.watch(userProfileProvider);
    final email = ref.read(authServiceProvider).currentUser?.email ?? 'User';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Profile & Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Profile Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.teal,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.teal.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 5)),
                ],
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, color: Colors.teal, size: 40),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (userProfile.value?['isSharedUser'] == true) ...[
                          Text(
                            userProfile.value?['name'] == null || userProfile.value?['name'].toString().trim().isEmpty == true
                              ? email.split('@')[0]
                              : userProfile.value?['name'],
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Mill: ${userProfile.value?['millName'] == null || userProfile.value?['millName'].toString().trim().isEmpty == true ? 'Rice Mill' : userProfile.value?['millName']}',
                            style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                        ] else ...[
                          Text(
                            userProfile.value?['millName'] == null || userProfile.value?['millName'].toString().trim().isEmpty == true
                              ? 'Rice Mill Name Not Set'
                              : userProfile.value?['millName'],
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            userProfile.value?['name'] ?? 'Owner',
                            style: const TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                        ],
                        Text(email, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.white, size: 20),
                    onPressed: () => _showEditNameOrMillDialog(),
                    tooltip: userProfile.value?['isSharedUser'] == true ? 'Edit Name' : 'Edit Rice Mill Name',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Settings List
            if (userProfile.value?['role'] != 'Guest' && userProfile.value?['isSharedUser'] != true) ...[
              if ((userProfile.value?['assignedDevices'] as List<dynamic>? ?? []).length > 1)
                _buildSettingTile(
                  icon: Icons.analytics_outlined,
                  title: 'Aggregate Analysis',
                  subtitle: 'View combined stats for all devices',
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const MixedAnalysisScreen()));
                  },
                ),
              _buildSettingTile(
                icon: Icons.share,
                title: 'Share Access',
                subtitle: 'Give others access to your devices',
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ShareAccessScreen()));
                },
              ),
            ],
            _buildSettingTile(
              icon: Icons.history,
              title: 'Activity History',
              subtitle: 'View recent alerts and logs',
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
              },
            ),
            _buildSettingTile(
              icon: Icons.mail_outline,
              title: 'Email Reports Setup',
              subtitle: 'Daily PDF graph reports & Excel dataset logs',
              onTap: () => _showEmailReportsModal(context),
            ),
            _buildSettingTileWithSwitch(
              icon: _isAlarmSoundEnabled ? Icons.volume_up : Icons.volume_off,
              title: 'Alarm Sound',
              subtitle: _isAlarmSoundEnabled ? 'Audible emergency alerts are enabled' : 'Audible emergency alerts are muted',
              value: _isAlarmSoundEnabled,
              onChanged: _toggleAlarmSetting,
            ),

            

            // Pending Invitations Section
            if ((userProfile.value?['pendingInvitations'] as List<dynamic>? ?? []).isNotEmpty) ...[
              const SizedBox(height: 30),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Pending Invitations',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange),
                ),
              ),
              const SizedBox(height: 10),
              ...(userProfile.value?['pendingInvitations'] as List<dynamic>? ?? []).map((invite) => _buildInvitationItem(context, Map<String, dynamic>.from(invite))),
            ],

            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 20),
            
            // Logout Button
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(10)),
                child: _isLoggingOut 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red))
                  : const Icon(Icons.logout, color: Colors.red),
              ),
              title: const Text('Logout', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              onTap: _isLoggingOut ? null : () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Logout'),
                    content: const Text('Are you sure you want to log out?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Logout', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                );
                if (confirm == true && mounted) {
                  setState(() => _isLoggingOut = true);
                  try {
                    await ref.read(authServiceProvider).signOut();
                  } finally {
                    if (mounted) setState(() => _isLoggingOut = false);
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.teal[50], borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: Colors.teal),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  Widget _buildSettingTileWithSwitch({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: value ? Colors.teal[50] : Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: value ? Colors.teal : Colors.grey),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeColor: Colors.teal,
        ),
      ),
    );
  }

  void _showEditNameOrMillDialog() {
    final userProfile = ref.read(userProfileProvider).value;
    if (userProfile == null) return;

    final isShared = userProfile['isSharedUser'] == true;
    final nameController = TextEditingController(text: userProfile['name'] ?? '');
    final millController = TextEditingController(text: userProfile['millName'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isShared ? 'Edit My Name' : 'Edit Profile & Rice Mill'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'My Name',
                  hintText: 'Enter your full name',
                  prefixIcon: const Icon(Icons.person, color: Colors.teal),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              if (!isShared) ...[
                const SizedBox(height: 15),
                TextField(
                  controller: millController,
                  decoration: InputDecoration(
                    labelText: 'Rice Mill Name',
                    hintText: 'Enter Rice Mill name',
                    prefixIcon: const Icon(Icons.factory_outlined, color: Colors.teal),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              final newMill = millController.text.trim();

              if (newName.isEmpty) return;
              if (!isShared && newMill.isEmpty) return;

              Navigator.pop(context);
              
              try {
                final Map<String, dynamic> updates = isShared
                    ? {'name': newName}
                    : {'name': newName, 'millName': newMill};
                    
                await ref.read(userProfileProvider.notifier).updateProfile(updates);
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile updated successfully!')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error updating profile: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showEmailReportsModal(BuildContext context) {
    bool isChecking = true;
    bool isEnabled = false;
    bool isSaving = false;
    bool isTesting = false;
    String reportEmail = '';
    
    final emailController = TextEditingController();
    final defaultEmail = ref.read(authServiceProvider).currentUser?.email ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          if (isChecking) {
            ref.read(apiServiceProvider).getEmailReportSettings().then((settings) {
              if (context.mounted) {
                setModalState(() {
                  isEnabled = settings?['isEmailReportEnabled'] == true;
                  reportEmail = settings?['reportEmail'] ?? '';
                  emailController.text = reportEmail;
                  isChecking = false;
                });
              }
            });
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 24.0,
              right: 24.0,
              top: 24.0,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24.0,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.teal[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.mail_outline, color: Colors.teal, size: 28),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Email Reports Setup',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Automated daily export of energy reports',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  if (isChecking) ...[
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40.0),
                        child: CircularProgressIndicator(color: Colors.teal),
                      ),
                    ),
                  ] else ...[
                    // Status Container
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isEnabled ? Colors.green[50] : Colors.amber[50],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isEnabled ? Colors.green.shade200 : Colors.amber.shade200,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isEnabled ? Icons.check_circle : Icons.warning_amber_rounded,
                            color: isEnabled ? Colors.green[700] : Colors.amber[800],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isEnabled ? 'Daily Reports Active' : 'Daily Reports Off',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isEnabled ? Colors.green[900] : Colors.amber[900],
                                  ),
                                ),
                                Text(
                                  isEnabled
                                      ? 'Energy report PDF & Excel raw data will be sent daily at midnight.'
                                      : 'Enable daily email reports to keep track of device analytics.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isEnabled ? Colors.green[800] : Colors.amber[800],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Switch Tile
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Enable Automated Daily Reports',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      subtitle: const Text(
                        'Send collective multi-device reports every night',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: isEnabled,
                      activeColor: Colors.teal,
                      onChanged: (val) {
                        setModalState(() {
                          isEnabled = val;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Custom Email Input
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Recipient Email Address',
                        hintText: defaultEmail,
                        helperText: 'Leave blank to send to account email ($defaultEmail)',
                        prefixIcon: const Icon(Icons.email_outlined, color: Colors.teal),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Save / Test Buttons
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton.icon(
                              icon: isTesting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(color: Colors.teal, strokeWidth: 1.5),
                                    )
                                  : const Icon(Icons.email_outlined, size: 18),
                              label: Text(
                                isTesting ? 'SENDING...' : 'TEST EMAIL',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.teal,
                                side: const BorderSide(color: Colors.teal),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: isTesting || isSaving
                                  ? null
                                  : () async {
                                      setModalState(() => isTesting = true);
                                      try {
                                        // Save current settings first so test runs with up-to-date recipient address
                                        final customEmail = emailController.text.trim();
                                        await ref.read(apiServiceProvider).saveEmailReportSettings(isEnabled, customEmail);
                                        
                                        final result = await ref
                                            .read(apiServiceProvider)
                                            .triggerTestEmailExport('RICE_MILL_001');

                                        if (context.mounted) {
                                          if (result != null && result['success'] == true) {
                                            final isDemo = result['demoMode'] == true;
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(isDemo
                                                    ? '🎉 Report generated locally! Check server/exports/ folder.'
                                                    : '🎉 Test report sent successfully to recipient email!'),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
                                          } else {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Note: ${result?['reason'] ?? result?['error'] ?? 'Verify credentials'}'),
                                                backgroundColor: Colors.orange,
                                              ),
                                            );
                                          }
                                        }
                                      } finally {
                                        if (context.mounted) {
                                          setModalState(() => isTesting = false);
                                        }
                                      }
                                    },
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              onPressed: isSaving || isTesting
                                  ? null
                                  : () async {
                                      setModalState(() => isSaving = true);
                                      try {
                                        final customEmail = emailController.text.trim();
                                        final success = await ref
                                            .read(apiServiceProvider)
                                            .saveEmailReportSettings(isEnabled, customEmail);

                                        if (context.mounted) {
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(success
                                                  ? '✅ Email report settings saved successfully.'
                                                  : '❌ Failed to save settings.'),
                                              backgroundColor: success ? Colors.green : Colors.red,
                                            ),
                                          );
                                        }
                                      } finally {
                                        if (context.mounted) {
                                          setModalState(() => isSaving = false);
                                        }
                                      }
                                    },
                              child: isSaving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Text('SAVE SETTINGS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInvitationItem(BuildContext context, Map<String, dynamic> invite) {
    final ownerEmail = invite['ownerEmail'];
    final isProcessing = _processingInvites.contains(ownerEmail);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.share, color: Colors.orange),
              const SizedBox(width: 15),
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
          const SizedBox(height: 15),
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
              const SizedBox(width: 10),
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
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Accept'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
