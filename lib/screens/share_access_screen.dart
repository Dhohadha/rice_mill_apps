import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/providers.dart';

class ShareAccessScreen extends ConsumerStatefulWidget {
  const ShareAccessScreen({super.key});

  @override
  ConsumerState<ShareAccessScreen> createState() => _ShareAccessScreenState();
}

class _ShareAccessScreenState extends ConsumerState<ShareAccessScreen> {
  final _emailController = TextEditingController();
  bool _isSharing = false;
  final Set<String> _selectedDevices = {};

  Future<void> _handleShare() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email')),
      );
      return;
    }

    if (_selectedDevices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one device')),
      );
      return;
    }

    setState(() => _isSharing = true);
    final success = await ref
        .read(apiServiceProvider)
        .shareAccess(email, _selectedDevices.toList());
    setState(() => _isSharing = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Access shared successfully!')),
      );
      _emailController.clear();
      setState(() => _selectedDevices.clear());
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to share access. Please try again.'),
        ),
      );
    }
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
        loading: () => const SizedBox.shrink(),
        error: (err, _) => Center(child: Text('Error loading devices: $err')),
        data: (profile) {
          final allDevices = List<String>.from(
            profile?['assignedDevices'] ?? [],
          );

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
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Row(
                          children: [
                            const Text(
                              'Select All',
                              style: TextStyle(fontSize: 14),
                            ),
                            Checkbox(
                              value:
                                  _selectedDevices.length ==
                                      allDevices.length &&
                                  allDevices.isNotEmpty,
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
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isSharing ? null : _handleShare,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSharing
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Share Access',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                  const SizedBox(height: 40),
                  const Text(
                    'People with Access',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                  FutureBuilder<List<dynamic>>(
                    future: ref
                        .read(apiServiceProvider)
                        .getSharedDetails(profile!['email']),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const SizedBox.shrink();
                      }
                      if (snapshot.data!.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Text(
                            'No users shared yet.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        );
                      }
                      return Column(
                        children: snapshot.data!.map((user) {
                          final isPending = user['status'] == 'Pending';
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: isPending
                                  ? Colors.grey[200]
                                  : Colors.teal[50],
                              child: Icon(
                                Icons.person,
                                color: isPending ? Colors.grey : Colors.teal,
                              ),
                            ),
                            title: Text(user['email']),
                            subtitle: Text(
                              '${user['role']} • ${user['status']}',
                            ),
                            trailing: isPending
                                ? const Icon(
                                    Icons.hourglass_empty,
                                    size: 18,
                                    color: Colors.orange,
                                  )
                                : const Icon(
                                    Icons.check_circle,
                                    size: 18,
                                    color: Colors.green,
                                  ),
                          );
                        }).toList(),
                      );
                    },
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
