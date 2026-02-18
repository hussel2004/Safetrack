enum AlertType {
  horsZone,
  vitesseExcessive,
  arretProlonge,
  moteurCoupe,
  batterieFaible,
}

enum AlertSeverity { faible, moyenne, critique }

class Alert {
  final String id;
  final String vehicleId;
  final AlertType type;
  final AlertSeverity severity;
  final String message;
  final DateTime timestamp;
  final bool isAcknowledged;

  Alert({
    required this.id,
    required this.vehicleId,
    required this.type,
    this.severity = AlertSeverity.moyenne,
    required this.message,
    required this.timestamp,
    this.isAcknowledged = false,
  });

  Alert copyWith({
    String? id,
    String? vehicleId,
    AlertType? type,
    AlertSeverity? severity,
    String? message,
    DateTime? timestamp,
    bool? isAcknowledged,
  }) {
    return Alert(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      type: type ?? this.type,
      severity: severity ?? this.severity,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      isAcknowledged: isAcknowledged ?? this.isAcknowledged,
    );
  }
}
