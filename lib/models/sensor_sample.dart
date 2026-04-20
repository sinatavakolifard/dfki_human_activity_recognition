class SensorSample {
  final int timestampMs;
  final double accelX;
  final double accelY;
  final double accelZ;
  final double gyroX;
  final double gyroY;
  final double gyroZ;
  final double magX;
  final double magY;
  final double magZ;

  const SensorSample({
    required this.timestampMs,
    required this.accelX,
    required this.accelY,
    required this.accelZ,
    required this.gyroX,
    required this.gyroY,
    required this.gyroZ,
    required this.magX,
    required this.magY,
    required this.magZ,
  });

  static const List<String> csvHeader = [
    'timestamp_ms',
    'accel_x',
    'accel_y',
    'accel_z',
    'gyro_x',
    'gyro_y',
    'gyro_z',
    'mag_x',
    'mag_y',
    'mag_z',
  ];

  String toCsvRow() =>
      '$timestampMs,$accelX,$accelY,$accelZ,$gyroX,$gyroY,$gyroZ,$magX,$magY,$magZ';
}
