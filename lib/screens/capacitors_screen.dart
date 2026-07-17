import 'package:flutter/material.dart';

class CapacitorsScreen extends StatelessWidget {
  const CapacitorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> capacitors = [
      {'name': 'Capacitor 1', 'isActive': true},
      {'name': 'Capacitor 2', 'isActive': true},
      {'name': 'Capacitor 3', 'isActive': false},
      {'name': 'Capacitor 4', 'isActive': true},
      {'name': 'Capacitor 5', 'isActive': false},
      {'name': 'Capacitor 6', 'isActive': true},
      {'name': 'Capacitor 7', 'isActive': true},
    ];

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
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Text(
              'Check Your capacitor status',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              itemCount: capacitors.length,
              itemBuilder: (context, index) {
                final cap = capacitors[index];
                final name = cap['name'] as String;
                final isActive = cap['isActive'] as bool;
                return _buildCapacitorCard(context, name, isActive);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCapacitorCard(BuildContext context, String name, bool isActive) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.01),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Left status stripe indicator (matching the image)
              Container(
                width: 6,
                color: isActive ? Colors.green.shade600 : Colors.red.shade600,
              ),
              const SizedBox(width: 16),
              // Lightning/bolt icon (matching the image)
              Icon(
                Icons.bolt,
                color: isActive ? Colors.green.shade600 : Colors.red.shade600,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isActive ? 'active' : 'inactive',
                  style: TextStyle(
                    color: isActive ? Colors.green.shade700 : Colors.red.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
