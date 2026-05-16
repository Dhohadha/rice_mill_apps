import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/providers.dart';

class RangeAnalysisScreen extends ConsumerStatefulWidget {
  final String deviceId;

  const RangeAnalysisScreen({super.key, required this.deviceId});

  @override
  ConsumerState<RangeAnalysisScreen> createState() => _RangeAnalysisScreenState();
}

class _RangeAnalysisScreenState extends ConsumerState<RangeAnalysisScreen> {
  int monthOffset = 0; // 0 means starting from the latest 3 months

  Future<void> _selectDate(BuildContext context, bool isFrom) async {
    final DateTime currentFrom = ref.read(rangeFromDateProvider);
    final DateTime currentTo = ref.read(rangeToDateProvider);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? currentFrom : currentTo,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      if (isFrom) {
        ref.read(rangeFromDateProvider.notifier).setDate(picked);
      } else {
        ref.read(rangeToDateProvider.notifier).setDate(picked);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fromDate = ref.watch(rangeFromDateProvider);
    final toDate = ref.watch(rangeToDateProvider);
    final rangeConsumption = ref.watch(customRangeConsumptionProvider(widget.deviceId));
    final rangeStats = ref.watch(customRangeStatsProvider(widget.deviceId));
    final monthlyData = ref.watch(monthlyUsageProvider(widget.deviceId));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Custom Range Analysis', style: TextStyle(fontWeight: FontWeight.bold)),
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
              _buildDateSelectors(fromDate, toDate),
              const SizedBox(height: 30),
              
              _buildResultDisplay(rangeConsumption),
              const SizedBox(height: 30),

              _buildSectionTitle("Historical Period Extremes"),
              const SizedBox(height: 8),
              Text(
                "Peaks from ${DateFormat('MMM dd').format(fromDate)} to ${DateFormat('MMM dd').format(toDate)}",
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 15),
              _buildExtremeGrid(rangeStats),
              
              const SizedBox(height: 40),
              _buildSectionTitle('Monthly Consumption (kWh)'),
              const SizedBox(height: 20),
              _buildMonthlyGraph(monthlyData),
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

  Widget _buildDateSelectors(DateTime fromDate, DateTime toDate) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _selectDate(context, true),
            child: _buildDateBox("From Date", fromDate),
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: GestureDetector(
            onTap: () => _selectDate(context, false),
            child: _buildDateBox("To Date", toDate),
          ),
        ),
      ],
    );
  }

  Widget _buildDateBox(String label, DateTime date) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          Text(
            DateFormat('dd MMM yyyy').format(date),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildResultDisplay(AsyncValue<double> consumed) {
    return consumed.when(
      loading: () => _buildResultContainer(null),
      error: (e, _) => Center(child: Text("Error: $e")),
      data: (val) => _buildResultContainer(val),
    );
  }

  Widget _buildResultContainer(double? val) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade700, Colors.teal.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.teal.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          const Text("Units Consumed", style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 10),
          Text(
            val != null ? val.toStringAsFixed(2) : "...",
            style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.bold),
          ),
          const Text("kWh", style: TextStyle(color: Colors.white70, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildExtremeGrid(AsyncValue<Map<String, dynamic>?> stats) {
    return stats.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error loading stats')),
      data: (data) {
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
      },
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

  Widget _buildMonthlyGraph(AsyncValue<List<dynamic>> monthlyData) {
    return monthlyData.when(
      loading: () => Container(
        height: 250,
        decoration: BoxDecoration(
          color: Colors.teal.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Center(child: CircularProgressIndicator(color: Colors.teal)),
      ),
      error: (err, _) => Center(child: Text("Error loading monthly data: $err")),
      data: (list) {
        if (list.isEmpty) return const Center(child: Text("No data available"));

        // Reverse list to chronological for the chart (if it comes desc)
        final sortedList = List.from(list.reversed);
        
        // Windowing logic: show 3 months at a time
        // monthOffset 0 = the last 3 months
        int end = sortedList.length - (monthOffset * 3);
        int start = end - 3;
        if (start < 0) start = 0;
        if (end <= 0) return const Center(child: Text("No more data"));

        final window = sortedList.sublist(start, end);
        final canGoLeft = start > 0;
        final canGoRight = monthOffset > 0;

        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_ios, color: canGoLeft ? Colors.teal : Colors.grey.shade300),
                  onPressed: canGoLeft ? () => setState(() => monthOffset++) : null,
                ),
                Text(
                  "${_getMonthName(window.first['month'])} ${window.first['year']} - ${_getMonthName(window.last['month'])} ${window.last['year']}",
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                IconButton(
                  icon: Icon(Icons.arrow_forward_ios, color: canGoRight ? Colors.teal : Colors.grey.shade300),
                  onPressed: canGoRight ? () => setState(() => monthOffset--) : null,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              height: 250,
              padding: const EdgeInsets.only(left: 0, right: 30, top: 20, bottom: 10),
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: _getMaxY(window),
                  barTouchData: BarTouchData(
                    enabled: true,
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
                  barGroups: window.asMap().entries.map((e) {
                    return BarChartGroupData(
                      x: e.key,
                      showingTooltipIndicators: [0],
                      barRods: [
                        BarChartRodData(
                          toY: (e.value['totalKWh'] as num).toDouble(),
                          color: Colors.teal,
                          width: 25,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        )
                      ],
                    );
                  }).toList(),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 35,
                        getTitlesWidget: (value, meta) {
                          int index = value.toInt();
                          if (index < 0 || index >= window.length) return const Text('');
                          return SideTitleWidget(
                            meta: meta,
                            space: 10,
                            fitInside: SideTitleFitInsideData(
                              enabled: true,
                              distanceFromEdge: 0,
                              axisPosition: meta.axisPosition,
                              parentAxisSize: meta.parentAxisSize,
                            ),
                            child: Text(
                              _getMonthName(window[index]['month']),
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 35,
                        getTitlesWidget: (value, meta) => SideTitleWidget(
                          meta: meta,
                          space: 4,
                          child: Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 9, color: Colors.black54),
                          ),
                        ),
                      ),
                    ),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _getMonthName(int m) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[m - 1];
  }

  double _getMaxY(List<dynamic> data) {
    double max = 0;
    for (var d in data) {
      if ((d['totalKWh'] as num) > max) max = (d['totalKWh'] as num).toDouble();
    }
    return max == 0 ? 100 : max * 1.3;
  }
}
