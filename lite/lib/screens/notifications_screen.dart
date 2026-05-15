import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/providers.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications History', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.blue),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Clear All'),
                  content: const Text('Are you sure you want to delete all history?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await ref.read(notificationsProvider.notifier).clearNotifications();
                      },
                      child: const Text('Clear', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
          )
        ],
      ),
      body: notificationsAsync.when(
        data: (notifications) => notifications.isEmpty
            ? const Center(child: Text('No notifications'))
            : ListView.builder(
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  final n = notifications[index];
                  final date = DateTime.tryParse(n['timestamp'] ?? '');
                  final id = n['_id']?.toString() ?? index.toString();

                  return Dismissible(
                    key: Key(id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      color: Colors.red,
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (direction) async {
                      await ref.read(notificationsProvider.notifier).deleteNotification(id);
                    },
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.red[50],
                        child: Icon(
                          n['type'] == 'CMD' ? Icons.flash_on
                          : n['type'] == 'POWER' ? Icons.electrical_services
                          : Icons.info,
                          color: Colors.red,
                          size: 20,
                        ),
                      ),
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (n['deviceId'] != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              margin: const EdgeInsets.only(bottom: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                n['deviceId'],
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue),
                              ),
                            ),
                          Text(n['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      subtitle: Text(n['message'] ?? ''),
                      trailing: Text(date != null 
                          ? '${date.hour}:${date.minute.toString().padLeft(2, '0')} ${date.day}/${date.month}' 
                          : '', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ),
                  );
                },
              ),
        error: (e, _) => Center(child: Text('Error: $e')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
