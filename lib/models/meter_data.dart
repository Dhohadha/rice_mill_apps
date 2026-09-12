class CapacitorInfo {
  final String key; // S1, S2, etc.
  final bool status;
  final DateTime? lastChanged;
  final String? reason;

  CapacitorInfo({
    required this.key,
    required this.status,
    this.lastChanged,
    this.reason,
  });

  factory CapacitorInfo.fromJson(String key, dynamic jsonVal) {
    if (jsonVal is Map<String, dynamic>) {
      return CapacitorInfo(
        key: key,
        status: jsonVal['status'] == true,
        lastChanged: jsonVal['lastChanged'] != null
            ? DateTime.tryParse(jsonVal['lastChanged'].toString())?.toLocal()
            : null,
        reason: jsonVal['reason']?.toString(),
      );
    } else if (jsonVal is bool) {
      return CapacitorInfo(
        key: key,
        status: jsonVal,
        lastChanged: null,
        reason: null,
      );
    }
    return CapacitorInfo(key: key, status: false);
  }
}

class MeterData {
  final double kVATotal;
  final double kWTotal;
  final double pfAvg;
  final double kWh;
  final String deviceId;
  final String? status;
  final DateTime? timestamp;
  final int capacitorCount;
  final String deviceType;
  final Map<String, CapacitorInfo> capacitors;

  MeterData({
    required this.kVATotal,
    required this.kWTotal,
    required this.pfAvg,
    required this.kWh,
    required this.deviceId,
    this.status,
    this.timestamp,
    this.capacitorCount = 10,
    this.deviceType = 'EMS',
    this.capacitors = const {},
  });

  factory MeterData.fromJson(Map<String, dynamic> json) {
    int capCount = 10;
    if (json['capacitorCount'] != null) {
      capCount = (json['capacitorCount'] as num).toInt();
    }

    final String devType = json['deviceType']?.toString() ?? 'EMS';

    Map<String, CapacitorInfo> parsedCapacitors = {};

    // 1. Parse 'capacitors' map object
    if (json['capacitors'] is Map<String, dynamic>) {
      final capMap = json['capacitors'] as Map<String, dynamic>;
      capMap.forEach((k, v) {
        parsedCapacitors[k] = CapacitorInfo.fromJson(k, v);
      });
    }

    // 2. Parse direct S1..S12 keys if present
    for (int i = 1; i <= 12; i++) {
      final key = 'S$i';
      if (!parsedCapacitors.containsKey(key) && json.containsKey(key)) {
        parsedCapacitors[key] = CapacitorInfo.fromJson(key, json[key]);
      }
    }

    return MeterData(
      kVATotal: (json['KVA'] ?? 0).toDouble(),
      kWTotal: (json['KW'] ?? 0).toDouble(),
      pfAvg: (json['PF'] ?? 0).toDouble(),
      kWh: (json['KWH'] ?? 0).toDouble(),
      deviceId: json['deviceId'] ?? 'RICE_MILL_001',
      status: json['status'],
      timestamp: json['timestamp'] != null ? DateTime.tryParse(json['timestamp'].toString())?.toLocal() : null,
      capacitorCount: capCount,
      deviceType: devType,
      capacitors: parsedCapacitors,
    );
  }

  factory MeterData.empty(String deviceId) {
    return MeterData(
      kVATotal: 0,
      kWTotal: 0,
      pfAvg: 0,
      kWh: 0,
      deviceId: deviceId,
      status: null,
      timestamp: null,
      capacitorCount: 10,
      deviceType: 'EMS',
      capacitors: {},
    );
  }
}
