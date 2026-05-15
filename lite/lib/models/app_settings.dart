class AppSettings {
  final double cmdLimit;
  final double cmdMaxGauge;
  final double powerLimit;
  final double powerMaxGauge;
  final double pfLimit;

  AppSettings({
    required this.cmdLimit,
    required this.cmdMaxGauge,
    required this.powerLimit,
    required this.powerMaxGauge,
    required this.pfLimit,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      cmdLimit: (json['cmdLimit'] ?? 150).toDouble(),
      cmdMaxGauge: (json['cmdMaxGauge'] ?? 250).toDouble(),
      powerLimit: (json['powerLimit'] ?? 150).toDouble(),
      powerMaxGauge: (json['powerMaxGauge'] ?? 250).toDouble(),
      pfLimit: (json['pfLimit'] ?? 0.90).toDouble(),
    );
  }
}
