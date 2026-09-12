import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../services/providers.dart';
import '../models/meter_data.dart';

class CapacitorsScreen extends ConsumerStatefulWidget {
  const CapacitorsScreen({super.key});

  @override
  ConsumerState<CapacitorsScreen> createState() => _CapacitorsScreenState();
}

class _CapacitorsScreenState extends ConsumerState<CapacitorsScreen> {
  String? _selectedDeviceId;
  final Set<String> _expandedCapacitors = {};

  void _toggleExpanded(String capKey) {
    setState(() {
      if (_expandedCapacitors.contains(capKey)) {
        _expandedCapacitors.remove(capKey);
      } else {
        _expandedCapacitors.add(capKey);
      }
    });
  }

  String _formatTiming(bool isActive, DateTime? timestamp) {
    if (timestamp == null) {
      return isActive ? 'Active' : 'Inactive';
    }
    final localTime = timestamp.toLocal();
    final diff = DateTime.now().difference(localTime);
    final int minutesAgo = diff.inMinutes;
    final int hoursAgo = diff.inHours;
    final int daysAgo = diff.inDays;

    String formattedTime;
    String timeAgoStr = '';

    if (minutesAgo <= 0) {
      formattedTime = DateFormat('hh:mm:ss a').format(localTime);
      timeAgoStr = ' (just now)';
    } else if (minutesAgo < 60) {
      formattedTime = DateFormat('hh:mm:ss a').format(localTime);
      timeAgoStr = ' ($minutesAgo min ago)';
    } else if (hoursAgo < 48) {
      formattedTime = DateFormat('hh:mm:ss a').format(localTime);
      timeAgoStr = hoursAgo == 1 ? ' (1 hr ago)' : ' ($hoursAgo hrs ago)';
    } else {
      formattedTime = DateFormat('dd/MM/yyyy hh:mm a').format(localTime);
      timeAgoStr = daysAgo == 1 ? ' (1 day ago)' : ' ($daysAgo days ago)';
    }

    final statusPrefix = isActive ? 'Active since' : 'Inactive since';
    return '$statusPrefix $formattedTime$timeAgoStr';
  }

  String _formatReason(String? reason) {
    if (reason == null || reason.trim().isEmpty) {
      return 'Not specified';
    }
    return reason.trim();
  }

  @override
  Widget build(BuildContext context) {
    final userProfile = ref.watch(userProfileProvider);

    return userProfile.when(
      skipLoadingOnReload: true,
      loading: () => Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Capacitors Status', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        body: const Center(child: CircularProgressIndicator(color: Colors.teal)),
      ),
      error: (err, stack) => Scaffold(
        body: Center(child: Text('Error: $err')),
      ),
      data: (profile) {
        final devices = (profile?['assignedDevices'] as List<dynamic>? ?? [])
            .map((d) => d.toString().trim())
            .where((d) => d.isNotEmpty)
            .toList();

        if (devices.isEmpty) {
          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              title: const Text('Capacitors Status', style: TextStyle(fontWeight: FontWeight.bold)),
              backgroundColor: Colors.white,
              elevation: 0,
              centerTitle: true,
            ),
            body: const Center(child: Text('No devices assigned.')),
          );
        }

        final activeDeviceId = (_selectedDeviceId != null && devices.contains(_selectedDeviceId))
            ? _selectedDeviceId!
            : devices.first;

        final mqttData = ref.watch(mqttDataProvider(activeDeviceId));

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: const Text(
              'Capacitors Status',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Check your capacitor status',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (devices.length > 1)
                      DropdownButton<String>(
                        value: activeDeviceId,
                        underline: const SizedBox.shrink(),
                        icon: const Icon(Icons.arrow_drop_down, color: Colors.teal),
                        items: devices.map((devId) {
                          return DropdownMenuItem<String>(
                            value: devId,
                            child: Text(
                              devId,
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal, fontSize: 13),
                            ),
                          );
                        }).toList(),
                        onChanged: (newVal) {
                          if (newVal != null) {
                            setState(() => _selectedDeviceId = newVal);
                          }
                        },
                      ),
                  ],
                ),
              ),
              Expanded(
                child: mqttData.when(
                  skipLoadingOnReload: true,
                  loading: () => const Center(child: CircularProgressIndicator(color: Colors.teal)),
                  error: (err, _) => Center(child: Text('Error: $err')),
                  data: (data) {
                    final int count = (data.capacitorCount).clamp(1, 12);
                    final Map<String, CapacitorInfo> capsMap = data.capacitors;

                    return RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(mqttDataProvider(activeDeviceId));
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        itemCount: count,
                        itemBuilder: (context, index) {
                          final capNum = index + 1;
                          final capKey = 'S$capNum';
                          final capInfo = capsMap[capKey];
                          final bool isActive = capInfo?.status ?? false;
                          final DateTime? lastChanged = capInfo?.lastChanged;
                          final String? reason = capInfo?.reason;
                          final bool isExpanded = _expandedCapacitors.contains(capKey);

                          return _buildCapacitorCard(
                            context: context,
                            name: 'Capacitor $capNum',
                            capKey: capKey,
                            isActive: isActive,
                            timestamp: lastChanged,
                            reason: reason,
                            isExpanded: isExpanded,
                            onTap: () => _toggleExpanded(capKey),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCapacitorCard({
    required BuildContext context,
    required String name,
    required String capKey,
    required bool isActive,
    required DateTime? timestamp,
    required String? reason,
    required bool isExpanded,
    required VoidCallback onTap,
  }) {
    final Color primaryColor = isActive ? Colors.green.shade600 : Colors.grey.shade400;
    final Color badgeBgColor = isActive ? Colors.green.shade50 : Colors.grey.shade200;
    final Color badgeTextColor = isActive ? Colors.green.shade700 : Colors.grey.shade700;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isExpanded
                ? primaryColor.withValues(alpha: 0.4)
                : Colors.grey.withValues(alpha: 0.2),
            width: isExpanded ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              IntrinsicHeight(
                child: Row(
                  children: [
                    // Left status stripe indicator
                    Container(
                      width: 6,
                      color: primaryColor,
                    ),
                    const SizedBox(width: 14),
                    // Lightning/bolt icon
                    Icon(
                      Icons.bolt,
                      color: primaryColor,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    // Capacitor Name
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isActive ? Colors.black87 : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ),
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: badgeBgColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isActive ? 'active' : 'inactive',
                        style: TextStyle(
                          color: badgeTextColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Expand arrow icon
                    Icon(
                      isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: Colors.grey.shade500,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                  ],
                ),
              ),
              // Expanded content (Timing & Reason)
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Column(
                  children: [
                    Divider(height: 1, color: Colors.grey.shade200),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      color: isActive
                          ? Colors.green.shade50.withValues(alpha: 0.3)
                          : Colors.grey.shade100.withValues(alpha: 0.5),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Timing Row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.access_time_rounded, size: 16, color: Colors.grey.shade600),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _formatTiming(isActive, timestamp),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade800,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Reason Row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline_rounded, size: 16, color: Colors.grey.shade600),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Reason: ${_formatReason(reason)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade800,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
