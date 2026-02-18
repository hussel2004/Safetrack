class GpsPosition {
  final String vehicleId;
  final double latitude;
  final double longitude;
  final double speed;
  final DateTime timestamp;

  GpsPosition({
    required this.vehicleId,
    required this.latitude,
    required this.longitude,
    this.speed = 0.0,
    required this.timestamp,
  });
}
