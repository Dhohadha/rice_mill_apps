import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/providers.dart';

class AnalysisScreen extends ConsumerWidget {
  final String deviceId;

  const AnalysisScreen({super.key, required this.deviceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sevenDayData = ref.watch(sevenDayUsageProvider(deviceId));
    final periodStats = ref.watch(periodStatsProvider(deviceId));
    final todayPeriodStats = ref.watch(todayPeriodStatsProvider(deviceId));
    final consumedKwh = ref.watch(consumedKwhProvider(deviceId));
    final selectedDate = ref.watch(selectedDateProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Power Analysis', style: TextStyle(fontWeight: FontWeight.bold)),
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
              _buildSectionTitle('Weekly Consumption (kWh)'),
              const SizedBox(height: 15),
              _buildWeeklyChart(sevenDayData),
              const SizedBox(height: 30),

              _buildSectionTitle("Today's Summary"),
              const SizedBox(height: 15),
              _buildTodaySummary(consumedKwh, todayPeriodStats),
              const SizedBox(height: 30),
              
              _buildSectionTitle("Today's Performance Peaks"),
              const SizedBox(height: 8),
              const Text("Max/Min values recorded since midnight", style: TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 15),
              _buildExtremeGrid(todayPeriodStats),
              const SizedBox(height: 30),

              _buildSectionTitle("Historical Period Extremes"),
              const SizedBox(height: 8),
              Text(
                "Peaks from ${DateFormat('MMM dd').format(selectedDate)} to Now",
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 15),
              _buildExtremeGrid(periodStats),
              const SizedBox(height: 30),
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

  Widget _buildWeeklyChart(AsyncValue<List<dynamic>> data) {
    return Container(
      height: 250,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(24),
      ),
      child: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (list) {
          if (list.isEmpty) return const Center(child: Text('No historical data available'));
          
          double maxVal = list.map((e) => (e['kwh'] as num).toDouble()).reduce((a, b) => a > b ? a : b);
          double maxY = maxVal > 10 ? maxVal * 1.2 : 10.0;

          return BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxY,
              barGroups: list.asMap().entries.map((e) {
                return BarChartGroupData(
                  x: e.key,
                  barRods: [
                    BarChartRodData(
                      toY: (e.value['kwh'] as num).toDouble(),
                      color: Colors.teal,
                      width: 16,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    )
                  ],
                );
              }).toList(),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      int index = value.toInt();
                      if (index < 0 || index >= list.length) return const Text('');
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(list[index]['label'], style: const TextStyle(fontSize: 10)),
                      );
                    },
                  ),
                ),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: false),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTodaySummary(AsyncValue<double> consumed, AsyncValue<Map<String, dynamic>?> stats) {
    return Row(
      children: [
        Expanded(
          child: _buildSimpleCard(
            'CONSUMED KWH', 
            consumed.when(data: (d) => d.toStringAsFixed(1), error: (_, __) => '0.0', loading: () => '...'), 
            Icons.bolt, 
            Colors.green
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSimpleCard(
            'AVG P.F', 
            stats.when(data: (d) => (d?['avgPF'] ?? 0.0).toStringAsFixed(3), error: (_, __) => '0.000', loading: () => '...'), 
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
        if (data == null) return const Text('No data recorded.');
        
        final kva = data['kva'] as Map<String, dynamic>;
        final kw = data['kw'] as Map<String, dynamic>;
        
        return Column(
          children: [
            Row(
              children: [
                Expanded(child: _buildExtremeCard('MAX KVA', kva['max'], kva['maxTime'], Icons.trending_up, Colors.orange)),
                const SizedBox(width: 16),
                Expanded(child: _buildExtremeCard('MIN KVA', kva['min'], kva['minTime'], Icons.trending_down, Colors.blue)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildExtremeCard('LIVE MAX KW', kw['max'], kw['maxTime'], Icons.speed, Colors.purple)),
                const SizedBox(width: 16),
                Expanded(child: _buildExtremeCard('LIVE MIN KW', kw['min'], kw['minTime'], Icons.low_priority, Colors.indigo)),
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
