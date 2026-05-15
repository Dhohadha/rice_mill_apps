class MeterData {
  final double kVATotal;
  final double kWTotal;
  final double pfAvg;
  final double kWh;
  final String deviceId;

  MeterData({
    required this.kVATotal,
    required this.kWTotal,
    required this.pfAvg,
    required this.kWh,
    required this.deviceId,
  });

  factory MeterData.fromJson(Map<String, dynamic> json) {
    return MeterData(
      kVATotal: (json['KVA'] ?? 0).toDouble(),
      kWTotal: (json['KW'] ?? 0).toDouble(),
      pfAvg: (json['PF'] ?? 0).toDouble(),
      kWh: (json['KWH'] ?? 0).toDouble(),
      deviceId: json['deviceId'] ?? 'RICE_MILL_001',
    );
  }

  factory MeterData.empty(String deviceId) {
    return MeterData(
      kVATotal: 0,
      kWTotal: 0,
      pfAvg: 0,
      kWh: 0,
      deviceId: deviceId,
    );
  }
}
