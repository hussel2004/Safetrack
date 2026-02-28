import 'package:latlong2/latlong.dart';
import 'stop_mode.dart';

class Vehicle {
  final String id;
  final String ownerId;
  final String model;
  final String licensePlate;
  final String gpsId;

  final String name;
  final String brand;
  final int year;
  final String deveui;

  // Secure Zone (Geofencing)
  double? secureZoneRadius; // in meters
  LatLng? secureZoneCenter;
  bool isSecureZoneActive;

  // Status
  bool isEngineStopped;
  bool
  modeAuto; // True = geofencing automatique actif (backend envoie STOP tout seul)
  bool
  moteurEnAttente; // True = commande STOP/START envoyée mais pas encore confirmée
  DateTime? lastCommunication;

  // Stop mode configuration
  StopMode stopMode;

  Vehicle({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.brand,
    required this.model,
    required this.year,
    required this.licensePlate,
    required this.gpsId,
    required this.deveui,
    this.secureZoneRadius,
    this.secureZoneCenter,
    this.isSecureZoneActive = false,
    this.isEngineStopped = false,
    this.modeAuto = false,
    this.moteurEnAttente = false,
    this.lastCommunication,
    this.stopMode = StopMode.manual, // Default to manual
  });

  bool get isOnline {
    if (lastCommunication == null) return false;
    final diff = DateTime.now().difference(lastCommunication!);
    return diff.inMinutes < 5; // Online if comm in last 5 minutes
  }

  // Calculate distance from center (Mock helper)
  bool isOutsideZone(LatLng currentPos) {
    if (!isSecureZoneActive ||
        secureZoneCenter == null ||
        secureZoneRadius == null) {
      return false;
    }
    final distance = const Distance().as(
      LengthUnit.Meter,
      secureZoneCenter!,
      currentPos,
    );
    return distance > secureZoneRadius!;
  }

  // Factory constructor to parse backend JSON
  factory Vehicle.fromBackendJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id_vehicule'].toString(),
      ownerId: json['id_utilisateur_proprietaire']?.toString() ?? '',
      name: json['nom'] ?? '',
      brand: json['marque'] ?? '',
      model: json['modele'] ?? '',
      year: json['annee'] ?? 0,
      licensePlate: json['immatriculation'] ?? '',
      gpsId: json['deveui'] ?? '',
      deveui: json['deveui'] ?? '',
      isEngineStopped: json['moteur_coupe'] ?? false,
      modeAuto: json['mode_auto'] ?? false,
      moteurEnAttente: json['moteur_en_attente'] ?? false,
      lastCommunication: json['derniere_communication'] != null
          ? DateTime.parse('${json['derniere_communication']}Z').toLocal()
          : null,
      stopMode: (json['mode_auto'] ?? false)
          ? StopMode.automatic
          : StopMode.manual,
    );
  }
}
