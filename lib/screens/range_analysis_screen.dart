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
  DateTime? fromDate;
  DateTime? toDate;
  double? totalConsumed;
  bool isLoadingRange = false;
  int monthOffset = 0; // 0 means starting from the latest 3 months

  @override
  void initState() {
    super.initState();
    // Default range: last 7 days
    toDate = DateTime.now();
    fromDate = toDate!.subtract(const Duration(days: 7));
  }

  Future<void> _checkUsage() async {
    if (fromDate == null || toDate == null) return;
    
    setState(() {
      isLoadingRange = true;
      totalConsumed = null;
    });

    try {
      final api = ref.read(apiServiceProvider);
      final result = await api.getRangeUsage(widget.deviceId, fromDate!, toDate!);
      setState(() {
        totalConsumed = result;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() {
        isLoadingRange = false;
      });
    }
  }

  Future<void> _selectDate(BuildContext context, bool isFrom) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? fromDate : toDate) ?? DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          fromDate = picked;
        } else {
          toDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
              _buildDateSelectors(),
              const SizedBox(height: 20),
              _buildCheckButton(),
              if (totalConsumed != null || isLoadingRange) ...[
                const SizedBox(height: 30),
                _buildResultDisplay(),
              ],
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

  Widget _buildDateSelectors() {
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

  Widget _buildDateBox(String label, DateTime? date) {
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
            date != null ? DateFormat('dd MMM yyyy').format(date) : "Select",
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: isLoadingRange ? null : _checkUsage,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 0,
        ),
        child: isLoadingRange
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Text("Check Consumption", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildResultDisplay() {
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
            totalConsumed != null ? totalConsumed!.toStringAsFixed(2) : "...",
            style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.bold),
          ),
          const Text("kWh", style: TextStyle(color: Colors.white70, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildMonthlyGraph(AsyncValue<List<dynamic>> monthlyData) {
    return monthlyData.when(
      loading: () => const SizedBox(height: 250),
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
              padding: const EdgeInsets.only(right: 20, top: 20),
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: _getMaxY(window),
                  barGroups: window.asMap().entries.map((e) {
                    return BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                          toY: (e.value['totalKWh'] as num).toDouble(),
                          color: Colors.teal,
                          width: 25,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: _getMaxY(window),
                            color: Colors.grey.shade100,
                          ),
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
                          if (index < 0 || index >= window.length) return const Text('');
                          return Padding(
                            padding: const EdgeInsets.only(top: 10.0),
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
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: const TextStyle(fontSize: 9)),
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
    return max == 0 ? 100 : max * 1.2;
  }
}
