import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../services/providers.dart';

class MixedAnalysisScreen extends ConsumerWidget {
  const MixedAnalysisScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mixedStats = ref.watch(mixedStatsProvider);
    final selectedDate = ref.watch(selectedDateProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Aggregate Analysis', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Combined data for all your assigned devices.",
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 24),

              _buildSectionTitle("Aggregated Summary"),
              const SizedBox(height: 15),
              _buildSummary(mixedStats),
              const SizedBox(height: 30),
              
              _buildSectionTitle("Global Performance Peaks"),
              const SizedBox(height: 8),
              Text(
                "Absolute extremes across all machines since ${DateFormat('MMM dd').format(selectedDate)}",
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 15),
              _buildExtremeGrid(mixedStats),
              const SizedBox(height: 30),

              const InfoNote(
                text: "Live KW refers to the combined instantaneous active power reading across your mill network at the time of the peak.",
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
    );
  }

  Widget _buildSummary(AsyncValue<Map<String, dynamic>?> stats) {
    return Row(
      children: [
        Expanded(
          child: _buildSimpleCard(
            'TOTAL KWH', 
            stats.when(
              data: (d) => (d?['totalConsumedKWh'] as num? ?? 0.0).toStringAsFixed(1), 
              error: (_, __) => '0.0', 
              loading: () => '...'
            ), 
            Icons.bolt, 
            Colors.green
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSimpleCard(
            'AVG P.F', 
            stats.when(
              data: (d) => (d?['avgPF'] as num? ?? 0.0).toStringAsFixed(3), 
              error: (_, __) => '0.000', 
              loading: () => '...'
            ), 
            Icons.electric_meter, 
            Colors.teal
          ),
        ),
      ],
    );
  }

  Widget _buildSimpleCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildExtremeGrid(AsyncValue<Map<String, dynamic>?> stats) {
    return stats.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error loading stats')),
      data: (data) {
        if (data == null) return const Text('No records found.');
        
        final kva = data['kva'] as Map<String, dynamic>;
        final kw = data['kw'] as Map<String, dynamic>;
        
        return Column(
          children: [
            Row(
              children: [
                Expanded(child: _buildExtremeCard('PEAK KVA', kva['max'], kva['maxTime'], Icons.trending_up, Colors.orange)),
                const SizedBox(width: 16),
                Expanded(child: _buildExtremeCard('LOWEST KVA', kva['min'], kva['minTime'], Icons.trending_down, Colors.blue)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildExtremeCard('PEAK KW', kw['max'], kw['maxTime'], Icons.speed, Colors.purple)),
                const SizedBox(width: 16),
                Expanded(child: _buildExtremeCard('LOWEST KW', kw['min'], kw['minTime'], Icons.low_priority, Colors.indigo)),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildExtremeCard(String title, num value, String? timeStr, IconData icon, Color color) {
    String formattedTime = "N/A";
    if (timeStr != null) {
      final time = DateTime.parse(timeStr);
      formattedTime = DateFormat('MMM dd, HH:mm').format(time);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 10, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value.toStringAsFixed(1), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
            formattedTime,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}

class InfoNote extends StatelessWidget {
  final String text;
  const InfoNote({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
            ),
          ),
        ],
      ),
    );
  }
}
