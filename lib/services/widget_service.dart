import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import '../models/meter_data.dart';

class WidgetService {
  static const String _monitoringWidgetProvider = 'GridPulseWidgetProvider';
  static const String _alertWidgetProvider = 'GridPulseAlertWidgetProvider';

  // Multi-device in-memory state
  static final Map<String, MeterData> _devicesData = {};
  static final Map<String, List<String>> _devicesAlerts = {};
  static final Map<String, String> _devicesNames = {};

  /// Update widget telemetry and breach state for a specific device.
  /// Synchronizes multi-device status to both the Monitoring and Alert widgets.
  static Future<void> recordDeviceTelemetry({
    required String deviceId,
    required MeterData data,
    required List<String> alerts,
    String? deviceName,
  }) async {
    try {
      _devicesData[deviceId] = data;
      _devicesAlerts[deviceId] = alerts;
      if (deviceName != null && deviceName.isNotEmpty) {
        _devicesNames[deviceId] = deviceName;
      } else if (!_devicesNames.containsKey(deviceId)) {
        _devicesNames[deviceId] = 'METER $deviceId';
      }

      await _syncAllWidgets(lastActiveDeviceId: deviceId);
    } catch (e) {
      debugPrint('❌ Error recording device telemetry for widget: $e');
    }
  }

  /// Internal sync function to write multi-device data to HomeWidget
  static Future<void> _syncAllWidgets({String? lastActiveDeviceId}) async {
    try {
      final deviceIds = _devicesData.keys.toList();
      final nowStr = DateFormat('HH:mm').format(DateTime.now());

      if (deviceIds.isEmpty) return;

      // Save device count
      await HomeWidget.saveWidgetData<int>('widget_device_count', deviceIds.length);

      // Save each device's metrics for native cycling
      for (int i = 0; i < deviceIds.length; i++) {
        final dId = deviceIds[i];
        final dData = _devicesData[dId]!;
        final name = _devicesNames[dId] ?? 'DEV $dId';
        final displayName = deviceIds.length > 1
            ? '$name (${i + 1}/${deviceIds.length})'
            : name;

        final kwStr = '${dData.kWTotal.toStringAsFixed(1)} kW';
        final kvaStr = '${dData.kVATotal.toStringAsFixed(1)} kVA';
        final pfStr = dData.pfAvg.toStringAsFixed(3);
        final statusStr = dData.status == 'offline' ? '🔴 OFFLINE' : '🟢 ONLINE';

        await HomeWidget.saveWidgetData<String>('dev_${i}_name', displayName);
        await HomeWidget.saveWidgetData<String>('dev_${i}_kw', kwStr);
        await HomeWidget.saveWidgetData<String>('dev_${i}_kva', kvaStr);
        await HomeWidget.saveWidgetData<String>('dev_${i}_pf', pfStr);
        await HomeWidget.saveWidgetData<String>('dev_${i}_status', statusStr);
      }

      // Default active device (either last active or first)
      final activeIndex = lastActiveDeviceId != null
          ? deviceIds.indexOf(lastActiveDeviceId).clamp(0, deviceIds.length - 1)
          : 0;
      final activeData = _devicesData[deviceIds[activeIndex]]!;
      final activeName = _devicesNames[deviceIds[activeIndex]] ?? 'DEV ${deviceIds[activeIndex]}';

      await HomeWidget.saveWidgetData<String>(
        'widget_device_name',
        deviceIds.length > 1 ? '$activeName (${activeIndex + 1}/${deviceIds.length})' : activeName,
      );
      await HomeWidget.saveWidgetData<String>(
        'widget_kw',
        '${activeData.kWTotal.toStringAsFixed(1)} kW',
      );
      await HomeWidget.saveWidgetData<String>(
        'widget_kva',
        '${activeData.kVATotal.toStringAsFixed(1)} kVA',
      );
      await HomeWidget.saveWidgetData<String>(
        'widget_pf',
        activeData.pfAvg.toStringAsFixed(3),
      );
      await HomeWidget.saveWidgetData<String>(
        'widget_status',
        activeData.status == 'offline' ? '🔴 OFFLINE' : '🟢 ONLINE',
      );
      await HomeWidget.saveWidgetData<String>('widget_updated_time', nowStr);

      // --- Multi-Device Alert Aggregation ---
      final breachingEntries =
          _devicesAlerts.entries.where((e) => e.value.isNotEmpty).toList();
      final bool hasAnyBreach = breachingEntries.isNotEmpty;

      String alertTitle;
      String alertMsg;

      if (hasAnyBreach) {
        if (breachingEntries.length == 1) {
          final bDevId = breachingEntries.first.key;
          final bName = _devicesNames[bDevId] ?? bDevId;
          final bAlerts = breachingEntries.first.value;
          alertTitle = deviceIds.length > 1
              ? '⚠️ $bName BREACH'
              : (bAlerts.length == 1 ? '⚠️ THRESHOLD EXCEEDED' : '🚨 ${bAlerts.length} THRESHOLDS BREACHED');
          alertMsg = bAlerts.join(' • ');
        } else {
          alertTitle = '🚨 ${breachingEntries.length} DEVICES IN BREACH';
          alertMsg = breachingEntries
              .map((e) => '${_devicesNames[e.key] ?? e.key}: ${e.value.join(", ")}')
              .join(' • ');
        }
      } else {
        alertTitle = 'All Systems Normal';
        alertMsg = deviceIds.length > 1
            ? 'All ${deviceIds.length} devices operating safely'
            : 'Demand, power & PF are within safe operating limits';
      }

      await HomeWidget.saveWidgetData<String>(
        'alert_is_breach',
        hasAnyBreach ? 'true' : 'false',
      );
      await HomeWidget.saveWidgetData<String>('alert_title', alertTitle);
      await HomeWidget.saveWidgetData<String>('alert_message', alertMsg);
      await HomeWidget.saveWidgetData<String>(
        'alert_devices_summary',
        deviceIds.length > 1 ? 'All ${deviceIds.length} Devices Monitored' : 'Monitored 24/7',
      );

      // Trigger update for both widget providers
      await HomeWidget.updateWidget(
        name: _monitoringWidgetProvider,
        androidName: _monitoringWidgetProvider,
      );

      await HomeWidget.updateWidget(
        name: _alertWidgetProvider,
        androidName: _alertWidgetProvider,
      );

      debugPrint(
        '📊 [Multi-Device Widget Sync] ${deviceIds.length} device(s) synced | Active: $activeName | Any Breach: $hasAnyBreach',
      );
    } catch (e) {
      debugPrint('❌ Error syncing multi-device widgets: $e');
    }
  }

  /// Single device backward compatible helper
  static Future<void> updateAllWidgets({
    required MeterData data,
    required bool hasBreach,
    String? alertTitle,
    String? alertMessage,
  }) async {
    await recordDeviceTelemetry(
      deviceId: data.deviceId,
      data: data,
      alerts: hasBreach ? [alertMessage ?? 'Threshold Exceeded'] : [],
    );
  }

  /// Backward compatible helper
  static Future<void> updateWidgetData(MeterData data) async {
    await recordDeviceTelemetry(
      deviceId: data.deviceId,
      data: data,
      alerts: [],
    );
  }
}
