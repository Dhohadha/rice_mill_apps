import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/providers.dart';
import 'range_analysis_screen.dart';

class AnalysisScreen extends ConsumerWidget {
  final String deviceId;

  const AnalysisScreen({super.key, required this.deviceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sevenDayData = ref.watch(historicalUsageProvider(deviceId));
    final focusedDate = ref.watch(focusedDateProvider);
    final dailyData = ref.watch(dailyConsumptionProvider(deviceId));
    final dailyStats = ref.watch(dailyStatsProvider(deviceId));

    bool isToday = DateFormat('yyyy-MM-dd').format(focusedDate) == DateFormat('yyyy-MM-dd').format(DateTime.now());

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
              _buildWeeklyChart(sevenDayData, ref, focusedDate),
              const SizedBox(height: 15),
              _buildCustomRangeButton(context),
              const SizedBox(height: 30),

              _buildSectionTitle(isToday ? "Today's Summary" : "${DateFormat('MMM dd').format(focusedDate)} Summary"),
              const SizedBox(height: 15),
              _buildTodaySummary(dailyData, dailyStats),
              const SizedBox(height: 30),
              
              _buildSectionTitle(isToday ? "Today's Performance Peaks" : "${DateFormat('MMM dd').format(focusedDate)} Peaks"),
              const SizedBox(height: 8),
              Text(isToday ? "Max/Min values recorded since midnight" : "Max/Min values recorded on this day", style: const TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 15),
              _buildExtremeGrid(dailyStats),
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

  Widget _buildCustomRangeButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => RangeAnalysisScreen(deviceId: deviceId)),
          );
        },
        icon: const Icon(Icons.date_range, size: 18),
        label: const Text("Custom Range & Monthly Analysis"),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.teal,
          side: const BorderSide(color: Colors.teal),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildWeeklyChart(AsyncValue<List<dynamic>> data, WidgetRef ref, DateTime focusedDate) {
    return Container(
      height: 250,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Colors.teal.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
      ),
      child: data.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.teal)),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (list) {
          if (list.isEmpty) return const Center(child: Text('No historical data available'));
          
          double maxVal = list.map((e) => (e['kwh'] as num).toDouble()).reduce((a, b) => a > b ? a : b);
          double avgVal = list.map((e) => (e['kwh'] as num).toDouble()).reduce((a, b) => a + b) / list.length;
          double maxY = maxVal > 10 ? maxVal * 1.3 : 10.0;
          
          final double barWidth = 55.0;
          final double chartWidth = list.length * barWidth;
          final double minWidth = MediaQuery.of(ref.context).size.width - 40;

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true,
            child: Container(
              width: chartWidth < minWidth ? minWidth : chartWidth,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchCallback: (event, response) {
                      if (event is FlTapUpEvent && response?.spot != null) {
                        final index = response!.spot!.touchedBarGroupIndex;
                        if (index >= 0 && index < list.length) {
                          final date = DateTime.parse(list[index]['fullDate']).toLocal();
                          ref.read(focusedDateProvider.notifier).state = date;
                        }
                      }
                    },
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => Colors.transparent,
                      tooltipPadding: EdgeInsets.zero,
                      tooltipMargin: 4,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          rod.toY.toStringAsFixed(1),
                          const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 10),
                        );
                      },
                    ),
                  ),
                  barGroups: list.asMap().entries.map((e) {
                    final date = DateTime.parse(e.value['fullDate']).toLocal();
                    final val = (e.value['kwh'] as num).toDouble();
                    final isSelected = date.year == focusedDate.year && date.month == focusedDate.month && date.day == focusedDate.day;
                    final isHigh = val >= avgVal;

                    return BarChartGroupData(
                      x: e.key,
                      showingTooltipIndicators: [0],
                      barRods: [
                        BarChartRodData(
                          toY: val,
                          color: isHigh ? Colors.orange : Colors.green,
                          width: 16,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          borderSide: isSelected 
                            ? const BorderSide(color: Color.fromARGB(255, 137, 194, 240), width: 2) 
                            : BorderSide.none,
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
                          final date = DateTime.parse(list[index]['fullDate']).toLocal();
                          return SideTitleWidget(
                            meta: meta,
                            space: 8,
                            fitInside: SideTitleFitInsideData(
                              enabled: true,
                              distanceFromEdge: 0,
                              axisPosition: meta.axisPosition,
                              parentAxisSize: meta.parentAxisSize,
                            ),
                            child: Text(
                              DateFormat('dd/MM').format(date),
                              style: const TextStyle(fontSize: 10),
                            ),
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
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTodaySummary(AsyncValue<double> consumed, AsyncValue<Map<String, dynamic>?> stats) {
    final kwh = consumed.valueOrNull ?? 0.0;
    final avgPF = stats.valueOrNull?['avgPF'] ?? 0.0;

    return Row(
      children: [
        Expanded(
          child: _buildSimpleCard(
            'CONSUMED KWH', 
            kwh.toStringAsFixed(1), 
            Icons.bolt, 
            Colors.green
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSimpleCard(
            'AVG P.F', 
            avgPF.toStringAsFixed(3), 
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
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
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
    final data = stats.valueOrNull;
    final kva = data?['kva'] as Map<String, dynamic>? ?? {};
    final kw = data?['kw'] as Map<String, dynamic>? ?? {};
    
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildExtremeCard('MAX KVA', kva['max'] ?? 0.0, kva['maxTime'], Icons.trending_up, Colors.orange)),
            const SizedBox(width: 16),
            Expanded(child: _buildExtremeCard('MIN KVA', kva['min'] ?? 0.0, kva['minTime'], Icons.trending_down, Colors.blue)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildExtremeCard('LIVE MAX KW', kw['max'] ?? 0.0, kw['maxTime'], Icons.speed, Colors.purple)),
            const SizedBox(width: 16),
            Expanded(child: _buildExtremeCard('LIVE MIN KW', kw['min'] ?? 0.0, kw['minTime'], Icons.low_priority, Colors.indigo)),
          ],
        ),
      ],
    );
  }

  Widget _buildExtremeCard(String title, num value, String? timeStr, IconData icon, Color color) {
    String formattedTime = "N/A";
    if (timeStr != null) {
      final time = DateTime.parse(timeStr).toLocal();
      formattedTime = DateFormat('MMM dd, HH:mm').format(time);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
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
