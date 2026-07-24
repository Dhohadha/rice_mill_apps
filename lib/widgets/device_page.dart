import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:rice_mill/models/app_settings.dart';
import 'package:rice_mill/services/alert_manager.dart';

import '../services/providers.dart';
import '../widgets/gauge_widget.dart';
import '../screens/settings_screen.dart';
import '../screens/analysis_screen.dart';

final graphTypeProvider = StateProvider.autoDispose<String>((ref) => 'KVA');

class DevicePage extends ConsumerWidget {
  final String deviceId;
  final String millName;

  const DevicePage({super.key, required this.deviceId, required this.millName});

  Future<void> _navToSettings(
    BuildContext context,
    WidgetRef ref,
    String title,
    String type,
    double limit, [
    double? maxGauge,
  ]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsScreen(
          title: title,
          type: type,
          currentLimit: limit,
          currentMaxGauge: maxGauge,
        ),
      ),
    );

    if (result != null) {
      Map<String, dynamic> updates = {};
      if (type == 'CMD') {
        updates['cmdLimit'] = result['limit'];
        updates['cmdMaxGauge'] = result['maxGauge'];
      } else if (type == 'POWER') {
        updates['powerLimit'] = result['limit'];
        updates['powerMaxGauge'] = result['maxGauge'];
      } else if (type == 'PF') {
        updates['pfLimit'] = result['limit'];
      }
      ref.read(settingsProvider.notifier).updateSettings(updates);
    }
  }

  String _formatPeakTime(String? timeStr) {
    if (timeStr == null) return '';
    try {
      final DateTime time = DateTime.parse(timeStr).toLocal();
      return DateFormat('dd/MM HH:mm').format(time);
    } catch (_) {
      return '';
    }
  }

  String _formatOfflineTime(DateTime? timestamp) {
    if (timestamp == null) return 'OFFLINE';
    try {
      final localTime = timestamp.toLocal();
      final now = DateTime.now();
      if (localTime.year == now.year && localTime.month == now.month && localTime.day == now.day) {
        return 'OFFLINE since ${DateFormat('HH:mm').format(localTime)}';
      }
      return 'OFFLINE since ${DateFormat('dd/MM HH:mm').format(localTime)}';
    } catch (_) {
      return 'OFFLINE';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mqttData = ref.watch(mqttDataProvider(deviceId));
    final settings = ref.watch(settingsProvider);
    final isDayGraph = ref.watch(isDayGraphProvider);
    final graphData = ref.watch(graphDataProvider(deviceId));
    final todayDetailedUsage = ref.watch(todayDetailedUsageProvider(deviceId));
    final monthlyStats = ref.watch(customRangeStatsProvider(deviceId));
    final monthlyDetailedUsage = ref.watch(rangeDetailedUsageProvider(deviceId));
    final todayKva = ref.watch(todayPeriodStatsProvider(deviceId));
    final alertState = ref.watch(alertManagerProvider(deviceId));
    final userProfile = ref.watch(userProfileProvider);
    final graphType = ref.watch(graphTypeProvider);

    return mqttData.when(
      skipLoadingOnReload: true,
      loading: () => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Connecting...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (data) => RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            ref.read(settingsProvider.notifier).loadSettings(),
            ref.refresh(graphDataProvider(deviceId).future),
            ref.refresh(consumedKwhProvider(deviceId).future),
            ref.refresh(todayKwhProvider(deviceId).future),
            ref.refresh(todayDetailedUsageProvider(deviceId).future),
            ref.refresh(customRangeStatsProvider(deviceId).future),
            ref.refresh(rangeDetailedUsageProvider(deviceId).future),
            ref.refresh(todayPeriodStatsProvider(deviceId).future),
            ref.refresh(periodStatsProvider(deviceId).future),
          ]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if ((userProfile.value?['assignedDevices'] as List<dynamic>? ?? []).length > 1) ...[
                      Text(
                        'Device ID: $deviceId',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: data.status == 'offline' ? Colors.red[50] : Colors.green[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: data.status == 'offline' ? Colors.red.shade200 : Colors.green.shade200,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: data.status == 'offline' ? Colors.red : Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            data.status == 'offline' ? _formatOfflineTime(data.timestamp) : 'ONLINE',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: data.status == 'offline' ? Colors.red[800] : Colors.green[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (alertState.activeAlerts.isNotEmpty)
                  Column(
                    children: [
                      ...alertState.activeAlerts.map(
                        (alert) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.shade300),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.red,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  alert,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: alertState.isAlarmStopped
                                    ? null
                                    : () => ref
                                          .read(
                                            alertManagerProvider(
                                              deviceId,
                                            ).notifier,
                                          )
                                          .stopAlarm(),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: alertState.isAlarmStopped
                                        ? Colors.grey
                                        : Colors.red,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    alertState.isAlarmStopped
                                        ? 'STOPPED'
                                        : 'STOP',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 10),
                if (data.status == 'offline')
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.cloud_off, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        const Text(
                          'Live Telemetry Unavailable',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          data.timestamp != null
                              ? 'Offline since ${DateFormat('dd/MM HH:mm').format(data.timestamp!)}. Showing cached summaries.'
                              : 'The device is currently offline. Showing cached summaries.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildGaugeWithLimit(
                        context,
                        ref,
                        'CMD',
                        data.kVATotal,
                        settings?.cmdMaxGauge ?? 250,
                        settings?.cmdLimit ?? 104,
                        'kVA',
                      ),
                      _buildGaugeWithLimit(
                        context,
                        ref,
                        'POWER',
                        data.kWTotal,
                        settings?.powerMaxGauge ?? 250,
                        settings?.powerLimit ?? 104,
                        'kW',
                      ),
                    ],
                  ),
                
                const SizedBox(height: 25),
                // Power Factor Metrics Card (2x2 grid style using Rows)
                _buildOverviewCard(
                  title: 'POWER FACTOR METRICS',
                  backgroundColor: const Color(0xFFFFF7ED),
                  textColor: Colors.orange[900]!,
                  children: [
                    Row(
                      children: [
                        _buildGridMetricTile(
                          label: 'LIVE PF',
                          value: data.status == 'offline' ? 'Offline' : data.pfAvg.toStringAsFixed(3),
                          labelColor: Colors.black87,
                          valueColor: Colors.orange[900]!,
                        ),
                        const SizedBox(width: 10),
                        _buildGridMetricTile(
                          label: 'P.F LIMIT',
                          value: settings?.pfLimit.toStringAsFixed(3) ?? '0.850',
                          labelColor: Colors.black87,
                          valueColor: Colors.orange[900]!,
                          onTap: () => _navToSettings(
                            context,
                            ref,
                            'PF limit',
                            'PF',
                            settings?.pfLimit ?? 0.85,
                          ),
                          icon: Icon(Icons.edit, color: Colors.teal[700], size: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildGridMetricTile(
                          label: 'TODAY AVG PF',
                          value: todayKva.when(
                            data: (stats) => stats?['avgPF']?.toStringAsFixed(3) ?? '0.000',
                            error: (_, _) => 'Error',
                            loading: () => '...',
                          ),
                          labelColor: Colors.black87,
                          valueColor: Colors.orange[900]!,
                        ),
                        const SizedBox(width: 10),
                        _buildGridMetricTile(
                          label: 'MONTHLY AVG PF',
                          value: monthlyStats.when(
                            data: (stats) => stats?['avgPF']?.toStringAsFixed(3) ?? '0.000',
                            error: (_, _) => 'Error',
                            loading: () => '...',
                          ),
                          labelColor: Colors.black87,
                          valueColor: Colors.orange[900]!,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Energy & Demand Metrics Card (2x4 grid style using Rows)
                _buildOverviewCard(
                  title: 'ENERGY & DEMAND METRICS',
                  backgroundColor: const Color(0xFFF0FDF4),
                  textColor: Colors.green[900]!,
                  children: [
                    Row(
                      children: [
                        _buildGridMetricTile(
                          label: 'TODAY CONSUMED KWH',
                          value: todayDetailedUsage.when(
                            data: (d) => d['todayKWh']?.toStringAsFixed(1) ?? '0.0',
                            error: (_, _) => 'Error',
                            loading: () => '...',
                          ),
                          labelColor: Colors.black87,
                          valueColor: Colors.green[900]!,
                        ),
                        const SizedBox(width: 10),
                        _buildGridMetricTile(
                          label: 'MONTHLY CONSUMED KWH',
                          value: monthlyDetailedUsage.when(
                            data: (d) => d['totalKWhConsumed']?.toStringAsFixed(1) ?? '0.0',
                            error: (_, _) => 'Error',
                            loading: () => '...',
                          ),
                          labelColor: Colors.black87,
                          valueColor: Colors.blue[900]!,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildGridMetricTile(
                          label: 'TODAY CONSUMED KVAH',
                          value: todayDetailedUsage.when(
                            data: (d) => d['todayKVAh']?.toStringAsFixed(1) ?? '0.0',
                            error: (_, _) => 'Error',
                            loading: () => '...',
                          ),
                          labelColor: Colors.black87,
                          valueColor: Colors.green[900]!,
                        ),
                        const SizedBox(width: 10),
                        _buildGridMetricTile(
                          label: 'MONTHLY CONSUMED KVAH',
                          value: monthlyDetailedUsage.when(
                            data: (d) => d['totalKVaConsumed']?.toStringAsFixed(1) ?? '0.0',
                            error: (_, _) => 'Error',
                            loading: () => '...',
                          ),
                          labelColor: Colors.black87,
                          valueColor: Colors.blue[900]!,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildGridMetricTile(
                          label: 'TODAY PEAK KW',
                          value: todayKva.when(
                            data: (stats) => stats?['kw']?['max']?.toStringAsFixed(2) ?? '0.00',
                            error: (_, _) => 'Error',
                            loading: () => '...',
                          ),
                          subtitle: todayKva.when(
                            data: (stats) => _formatPeakTime(stats?['kw']?['maxTime']),
                            error: (_, _) => '',
                            loading: () => '',
                          ),
                          labelColor: Colors.black87,
                          valueColor: Colors.green[900]!,
                        ),
                        const SizedBox(width: 10),
                        _buildGridMetricTile(
                          label: 'MONTHLY PEAK KW',
                          value: monthlyStats.when(
                            data: (stats) => stats?['kw']?['max']?.toStringAsFixed(2) ?? '0.00',
                            error: (_, _) => 'Error',
                            loading: () => '...',
                          ),
                          subtitle: monthlyStats.when(
                            data: (stats) => _formatPeakTime(stats?['kw']?['maxTime']),
                            error: (_, _) => '',
                            loading: () => '',
                          ),
                          labelColor: Colors.black87,
                          valueColor: Colors.blue[900]!,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildGridMetricTile(
                          label: 'TODAY PEAK KVA',
                          value: todayKva.when(
                            data: (stats) => stats?['kva']?['max']?.toStringAsFixed(2) ?? '0.00',
                            error: (_, _) => 'Error',
                            loading: () => '...',
                          ),
                          subtitle: todayKva.when(
                            data: (stats) => _formatPeakTime(stats?['kva']?['maxTime']),
                            error: (_, _) => '',
                            loading: () => '',
                          ),
                          labelColor: Colors.black87,
                          valueColor: Colors.green[900]!,
                        ),
                        const SizedBox(width: 10),
                        _buildGridMetricTile(
                          label: 'MONTHLY PEAK KVA',
                          value: monthlyStats.when(
                            data: (stats) => stats?['kva']?['max']?.toStringAsFixed(2) ?? '0.00',
                            error: (_, _) => 'Error',
                            loading: () => '...',
                          ),
                          subtitle: monthlyStats.when(
                            data: (stats) => _formatPeakTime(stats?['kva']?['maxTime']),
                            error: (_, _) => '',
                            loading: () => '',
                          ),
                          labelColor: Colors.black87,
                          valueColor: Colors.blue[900]!,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 25),
                // Analysis Button
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              AnalysisScreen(deviceId: deviceId),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.teal, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: const Text(
                      'Day Wise Units (Analysis)',
                      style: TextStyle(
                        color: Colors.teal,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 25),
                // Toggle Hour / Day
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildToggleButton(ref, 'Hour', !isDayGraph),
                      _buildToggleButton(ref, 'Day', isDayGraph),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Graph
                Container(
                  height: 200,
                  padding: const EdgeInsets.only(right: 16, top: 16),
                  child: graphData.when(
                    data: (data) {
                      if (data.isEmpty) return const Center(child: Text('No history data available'));
                      
                      if (isDayGraph) {
                        // For the 24-hour graph, make it compact (4px per point)
                        double chartWidth = data.length * 4.0;
                        double minWidth = MediaQuery.of(context).size.width - 32 - 40; // Subtract axis width

                        return Row(
                          children: [
                            // Sticky Y-Axis
                            SizedBox(
                              width: 40,
                              child: LineChart(_buildChartData([], settings, isDayGraph, graphType, showLeftTitles: true)),
                            ),
                            // Scrollable Graph Area
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                reverse: true,
                                child: Container(
                                  width: chartWidth < minWidth ? minWidth : chartWidth,
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: LineChart(_buildChartData(data, settings, isDayGraph, graphType, showLeftTitles: false)),
                                ),
                              ),
                            ),
                          ],
                        );
                      } else {
                        // For the 1-hour graph, keep it fixed to the screen width
                        return LineChart(_buildChartData(data, settings, isDayGraph, graphType, showLeftTitles: true));
                      }
                    },
                    error: (e, _) => Center(child: Text('Error: $e')),
                    loading: () => const Center(child: CircularProgressIndicator(color: Colors.teal)),
                  ),
                ),
                const SizedBox(height: 15),
                // Interactive Graph Toggle under the Graph
                _buildSliderGraphToggle(ref, graphType),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGaugeWithLimit(
    BuildContext context,
    WidgetRef ref,
    String title,
    double value,
    double max,
    double limit,
    String unit,
  ) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () => _navToSettings(
            context,
            ref,
            '$title Settings',
            title,
            limit,
            max,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  ' Limit: ${limit.toStringAsFixed(1)} $unit',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _navToSettings(
            context,
            ref,
            '$title Settings',
            title,
            limit,
            max,
          ),
          child: GaugeWidget(title: '', value: value, max: max, unit: unit),
        ),
      ],
    );
  }

  Widget _buildToggleButton(WidgetRef ref, String text, bool isActive) {
    return GestureDetector(
      onTap: () => ref.read(isDayGraphProvider.notifier).toggle(text == 'Day'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? Colors.blue : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.black38,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSliderGraphToggle(WidgetRef ref, String currentType) {
    // Target alignment & color for the sliding background thumb
    Alignment thumbAlignment;
    Color thumbColor;
    if (currentType == 'KVA') {
      thumbAlignment = Alignment.centerLeft;
      thumbColor = Colors.blue.shade600;
    } else if (currentType == 'BOTH') {
      thumbAlignment = Alignment.center;
      thumbColor = Colors.indigo.shade600;
    } else {
      thumbAlignment = Alignment.centerRight;
      thumbColor = Colors.green.shade600;
    }

    return Container(
      width: 320,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Sliding Background Pill
          AnimatedAlign(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            alignment: thumbAlignment,
            child: FractionallySizedBox(
              widthFactor: 0.33,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      thumbColor,
                      thumbColor.withValues(alpha: 0.85),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: thumbColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Toggle Buttons Row
          Row(
            children: [
              _buildSliderOption(
                ref: ref,
                type: 'KVA',
                label: 'KVA',
                icon: Icons.bolt,
                isSelected: currentType == 'KVA',
              ),
              _buildSliderOption(
                ref: ref,
                type: 'BOTH',
                label: 'BOTH',
                icon: Icons.analytics,
                isSelected: currentType == 'BOTH',
              ),
              _buildSliderOption(
                ref: ref,
                type: 'KW',
                label: 'KW',
                icon: Icons.power,
                isSelected: currentType == 'KW',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSliderOption({
    required WidgetRef ref,
    required String type,
    required String label,
    required IconData icon,
    required bool isSelected,
  }) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => ref.read(graphTypeProvider.notifier).state = type,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey.shade600,
                size: 15,
              ),
              const SizedBox(width: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }

  LineChartData _buildChartData(List<dynamic> data, AppSettings? settings, bool isDayGraph, String selectedType, {required bool showLeftTitles}) {
    double maxY = 250;
    Color themeColor = Colors.blue;

    if (selectedType == 'KW') {
      maxY = settings?.powerMaxGauge ?? 250;
      themeColor = Colors.green;
    } else if (selectedType == 'BOTH') {
      final kvaMax = settings?.cmdMaxGauge ?? 250;
      final kwMax = settings?.powerMaxGauge ?? 250;
      maxY = kvaMax > kwMax ? kvaMax : kwMax;
      themeColor = Colors.indigo;
    } else {
      maxY = settings?.cmdMaxGauge ?? 250;
      themeColor = Colors.blue;
    }
    if (maxY < 10) maxY = 250;

    return LineChartData(
      minY: 0,
      maxY: maxY,
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (spot) {
            if (selectedType == 'BOTH') {
              return spot.barIndex == 0
                  ? Colors.blue.shade800.withValues(alpha: 0.9)
                  : Colors.green.shade800.withValues(alpha: 0.9);
            }
            return themeColor.withValues(alpha: 0.8);
          },
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              int index = spot.x.toInt();
              if (index >= 0 && index < data.length) {
                final item = data[index];
                final timestamp = item['timestamp'];
                String timeStr = '';
                if (timestamp != null) {
                  final date = DateTime.parse(timestamp).toLocal();
                  timeStr = isDayGraph
                      ? "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}"
                      : "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}";
                }
                String spotType = selectedType;
                if (selectedType == 'BOTH') {
                  spotType = spot.barIndex == 0 ? 'KVA' : 'KW';
                }
                return LineTooltipItem(
                  '${spot.y.toStringAsFixed(2)} $spotType\nTime: $timeStr',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                );
              }
              return null;
            }).toList();
          },
        ),
      ),
      gridData: FlGridData(
        show: true,
        drawHorizontalLine: true,
        drawVerticalLine: true,
        verticalInterval: isDayGraph ? 1 : 4, // 1 unit for day-wise, 4 units for hour-wise
        horizontalInterval: maxY / 5,
        getDrawingHorizontalLine: (value) => FlLine(color: Colors.black.withValues(alpha: 0.05), strokeWidth: 1),
        getDrawingVerticalLine: (value) => FlLine(color: Colors.black.withValues(alpha: 0.05), strokeWidth: 1),
      ),
      extraLinesData: ExtraLinesData(
        horizontalLines: [
          if (selectedType == 'KVA' || selectedType == 'BOTH')
            HorizontalLine(
              y: settings?.cmdLimit ?? 104,
              color: Colors.red.withValues(alpha: 0.4),
              strokeWidth: 2,
              dashArray: [5, 5],
              label: HorizontalLineLabel(
                show: true,
                alignment: Alignment.topRight,
                labelResolver: (line) => selectedType == 'BOTH' ? 'KVA Limit' : 'Limit',
                style: TextStyle(
                  color: Colors.red.withValues(alpha: 0.8),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          if (selectedType == 'KW' || selectedType == 'BOTH')
            HorizontalLine(
              y: settings?.powerLimit ?? 104,
              color: Colors.orange.withValues(alpha: 0.4),
              strokeWidth: 2,
              dashArray: [5, 5],
              label: HorizontalLineLabel(
                show: true,
                alignment: selectedType == 'BOTH' ? Alignment.topLeft : Alignment.topRight,
                labelResolver: (line) => selectedType == 'BOTH' ? 'KW Limit' : 'Limit',
                style: TextStyle(
                  color: Colors.orange.withValues(alpha: 0.8),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: showLeftTitles,
            reservedSize: 40,
            interval: maxY >= 500 ? 100 : 50,
            getTitlesWidget: (value, meta) => SideTitleWidget(
              meta: meta,
              child: Text(
                value.toStringAsFixed(0),
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: isDayGraph,
            reservedSize: 30,
            interval: 1,
            getTitlesWidget: (value, meta) {
              int index = value.toInt();
              if (index < 0 || index >= data.length) return const Text('');
              
              final timestamp = data[index]['timestamp'];
              if (timestamp == null) return const Text('');
              final date = DateTime.parse(timestamp).toLocal();

              bool isHourTransition = false;
              if (index == 0) {
                if (date.hour % 4 == 0) {
                  isHourTransition = true;
                }
              } else {
                final prevTimestamp = data[index - 1]['timestamp'];
                if (prevTimestamp != null) {
                  final prevDate = DateTime.parse(prevTimestamp).toLocal();
                  // Show label at 4-hour intervals (00:00, 04:00, 08:00, etc.)
                  if (date.hour != prevDate.hour && date.hour % 4 == 0) {
                    isHourTransition = true;
                  }
                }
              }

              // Only show label if it's an appropriate 4-hour marker
              if (!isHourTransition) return const Text('');

              // Use HH:00 for hourly transitions
              String label = "${date.hour.toString().padLeft(2, '0')}:00";

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
                  label,
                  style: const TextStyle(color: Colors.black45, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        if (selectedType == 'KVA' || selectedType == 'BOTH')
          LineChartBarData(
            spots: data
                .asMap()
                .entries
                .map(
                  (e) => FlSpot(
                    e.key.toDouble(),
                    ((e.value['KVA'] ?? 0) as num).toDouble(),
                  ),
                )
                .toList(),
            isCurved: true,
            color: Colors.blue.withValues(alpha: 0.7),
            barWidth: 1.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.blue.withValues(alpha: selectedType == 'BOTH' ? 0.03 : 0.1),
            ),
          ),
        if (selectedType == 'KW' || selectedType == 'BOTH')
          LineChartBarData(
            spots: data
                .asMap()
                .entries
                .map(
                  (e) => FlSpot(
                    e.key.toDouble(),
                    ((e.value['KW'] ?? 0) as num).toDouble(),
                  ),
                )
                .toList(),
            isCurved: true,
            color: Colors.green.withValues(alpha: 0.7),
            barWidth: 1.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.green.withValues(alpha: selectedType == 'BOTH' ? 0.03 : 0.1),
            ),
          ),
      ],
    );
  }

  Widget _buildOverviewCard({
    required String title,
    required Color backgroundColor,
    required Color textColor,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: textColor,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildGridMetricTile({
    required String label,
    required String value,
    required Color labelColor,
    required Color valueColor,
    String? subtitle,
    VoidCallback? onTap,
    Widget? icon,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: onTap != null
                ? Border.all(color: Colors.orange.withValues(alpha: 0.3), width: 1.5)
                : Border.all(color: Colors.grey.withValues(alpha: 0.05), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    icon,
                    const SizedBox(width: 4),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: labelColor.withValues(alpha: 0.6),
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: valueColor,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                ),
              ),
              if (subtitle != null && subtitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
