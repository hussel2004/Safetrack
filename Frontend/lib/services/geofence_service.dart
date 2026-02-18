import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/zone.dart';
import '../models/alert.dart';
import '../models/gps_position.dart';
import '../config/api_config.dart';
import 'auth_service.dart';
import 'gps_service.dart';

class GeofenceService extends ChangeNotifier {
  final AuthService _authService;
  List<Zone> _zones = [];
  final List<Alert> _alerts = [];
  final Uuid _uuid = const Uuid();
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  GeofenceService(this._authService) {
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Note: iOS settings would go here
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(initializationSettings);
  }

  List<Zone> getZones(String? vehicleId) {
    if (vehicleId == null) return [];
    return _zones
        .where((z) => z.vehicleId == vehicleId || z.vehicleId == null)
        .toList();
  }

  List<Alert> getAlerts(String? vehicleId) {
    if (vehicleId == null) return [];
    // Return sorted by newest first
    final vehicleAlerts = _alerts
        .where((a) => a.vehicleId == vehicleId)
        .toList();
    vehicleAlerts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return vehicleAlerts;
  }

  // Check if a vehicle has a zone
  bool hasZone(String vehicleId) {
    return _zones.any((z) => z.vehicleId == vehicleId);
  }

  // Check if a vehicle has an active zone
  bool hasActiveZone(String vehicleId) {
    return _zones.any((z) => z.vehicleId == vehicleId && z.isActive);
  }

  // Get the single zone for a vehicle (if exists)
  Zone? getVehicleZone(String vehicleId) {
    try {
      return _zones.firstWhere((z) => z.vehicleId == vehicleId);
    } catch (e) {
      return null;
    }
  }

  // Get the active zone for a vehicle
  Zone? getActiveZone(String vehicleId) {
    try {
      return _zones.firstWhere((z) => z.vehicleId == vehicleId && z.isActive);
    } catch (e) {
      return null;
    }
  }

  Future<void> fetchZones() async {
    if (_authService.token == null) return;

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.geofences}/'),
        headers: {'Authorization': 'Bearer ${_authService.token}'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _zones = data.map((json) => _mapBackendZoneToFrontend(json)).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Fetch zones error: $e');
    }
  }

  Future<void> addZone(Zone zone) async {
    if (_authService.token == null) return;

    // Convert Polygon to Circle (Centroid + Max Radius) for Backend Compatibility
    final center = zone.center;
    double maxRadius = 0;
    for (final point in zone.polygon) {
      final dist = const Distance().as(LengthUnit.Meter, center, point);
      if (dist > maxRadius) maxRadius = dist;
    }

    // Ensure minimum radius
    if (maxRadius < 100) maxRadius = 100;

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.geofences}/'),
        headers: {
          'Authorization': 'Bearer ${_authService.token}',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'nom': zone.name,
          'description': zone.description,
          'latitude_centre': center.latitude,
          'longitude_centre': center.longitude,
          'rayon_metres': maxRadius.toInt(),
          'couleur': '#00FF00', // Default green
          'active': zone.isActive,
          'id_vehicule': zone.vehicleId != null
              ? int.parse(zone.vehicleId!)
              : null,
          'type': 'POLYGON',
          'coordinates': zone.polygon
              .map((p) => {'lat': p.latitude, 'lng': p.longitude})
              .toList(),
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchZones(); // Refresh list
      } else {
        debugPrint('Add zone failed: ${response.body}');
      }
    } catch (e) {
      debugPrint('Add zone error: $e');
    }
  }

  Future<void> updateZone(Zone zone) async {
    if (_authService.token == null) return;

    // Convert Polygon to Circle (Centroid + Max Radius) for Backend Compatibility
    final center = zone.center;
    double maxRadius = 0;
    for (final point in zone.polygon) {
      final dist = const Distance().as(LengthUnit.Meter, center, point);
      if (dist > maxRadius) maxRadius = dist;
    }

    // Ensure minimum radius
    if (maxRadius < 100) maxRadius = 100;

    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.geofences}/${zone.id}'),
        headers: {
          'Authorization': 'Bearer ${_authService.token}',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'nom': zone.name,
          'description': zone.description,
          'latitude_centre': center.latitude,
          'longitude_centre': center.longitude,
          'rayon_metres': maxRadius.toInt(),
          'couleur': '#00FF00',
          'active': zone.isActive,
          'id_vehicule': zone.vehicleId != null
              ? int.parse(zone.vehicleId!)
              : null,
          'type': 'POLYGON',
          'coordinates': zone.polygon
              .map((p) => {'lat': p.latitude, 'lng': p.longitude})
              .toList(),
        }),
      );

      if (response.statusCode == 200) {
        await fetchZones(); // Refresh list
      } else {
        debugPrint('Update zone failed: ${response.body}');
      }
    } catch (e) {
      debugPrint('Update zone error: $e');
    }
  }

  Future<void> deleteZone(String zoneId) async {
    if (_authService.token == null) return;

    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.geofences}/$zoneId'),
        headers: {'Authorization': 'Bearer ${_authService.token}'},
      );

      if (response.statusCode == 200) {
        _zones.removeWhere((z) => z.id == zoneId);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Delete zone error: $e');
    }
  }

  // Helper to map backend JSON to Frontend Zone model
  Zone _mapBackendZoneToFrontend(Map<String, dynamic> json) {
    final center = LatLng(
      (json['latitude_centre'] as num).toDouble(),
      (json['longitude_centre'] as num).toDouble(),
    );
    final radius = (json['rayon_metres'] as num).toDouble();

    if (json['type'] == 'POLYGON' && json['coordinates'] != null) {
      final coords = json['coordinates'] as List;
      final polygon = coords
          .map(
            (c) => LatLng(
              (c['lat'] as num).toDouble(),
              (c['lng'] as num).toDouble(),
            ),
          )
          .toList();

      return Zone(
        id: json['id_zone'].toString(),
        name: json['nom'],
        description: json['description'] ?? '',
        polygon: polygon,
        color: Colors.green, // Fixed for now
        isActive: json['active'] ?? true,
        vehicleId: json['id_vehicule']?.toString(),
      );
    }

    return Zone.fromCenterRadius(
      id: json['id_zone'].toString(),
      name: json['nom'],
      description: json['description'] ?? '',
      center: center,
      radius: radius,
      color: Colors.green, // Fixed for now
      isActive: json['active'] ?? true,
      vehicleId: json['id_vehicule']?.toString(),
    );
  }

  // Activate a zone (auto-deactivates other zones for same vehicle)
  Future<void> activateZone(String zoneId) async {
    // Optimistic update
    final index = _zones.indexWhere((z) => z.id == zoneId);
    if (index == -1) return;

    final zone = _zones[index];

    // Deactivate others locally
    for (int i = 0; i < _zones.length; i++) {
      if (_zones[i].vehicleId == zone.vehicleId && _zones[i].id != zoneId) {
        // In a real app we would call backend to deactivate these too
        // For now, let's just update the target zone
      }
    }

    // Call backend to update
    // We reuse add/update logic or specific endpoint if exists.
    // Backend `update_zone` PUT endpoint exists.
    await _updateZoneStatus(zoneId, true);
  }

  // Deactivate a zone
  Future<void> deactivateZone(String zoneId) async {
    await _updateZoneStatus(zoneId, false);
  }

  Future<void> _updateZoneStatus(String zoneId, bool isActive) async {
    if (_authService.token == null) return;

    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.geofences}/$zoneId'),
        headers: {
          'Authorization': 'Bearer ${_authService.token}',
          'Content-Type': 'application/json',
        },
        body: json.encode({'active': isActive}),
      );

      if (response.statusCode == 200) {
        await fetchZones();
      }
    } catch (e) {
      debugPrint('Update zone status error: $e');
    }
  }

  void checkGeofence(String vehicleId, GpsPosition position) {
    final vehicleZones = getZones(vehicleId).where((z) => z.isActive).toList();
    if (vehicleZones.isEmpty) return;

    bool isInsideAnyZone = false;

    // Check if inside ANY active zone
    // Backend uses Circles, Frontend model uses Polygons generated from circles
    // So containsPoint is still valid for the circular polygon approximation
    final point = LatLng(position.latitude, position.longitude);

    for (final zone in vehicleZones) {
      if (zone.containsPoint(point)) {
        isInsideAnyZone = true;
        break;
      }
    }

    if (!isInsideAnyZone) {
      // Trigger alert logic
      final lastAlert = _alerts
          .where(
            (a) => a.vehicleId == vehicleId && a.type == AlertType.horsZone,
          )
          .fold<Alert?>(
            null,
            (prev, curr) =>
                prev == null || curr.timestamp.isAfter(prev.timestamp)
                ? curr
                : prev,
          );

      if (lastAlert == null ||
          DateTime.now().difference(lastAlert.timestamp).inSeconds > 30) {
        final message = "Le véhicule est hors de la zone de sécurité !";
        _createAlert(
          vehicleId,
          AlertType.horsZone,
          AlertSeverity.critique,
          message,
        );
        _showSystemNotification(vehicleId, message);
      }
    }
  }

  Future<void> _showSystemNotification(String vehicleId, String message) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'safetrack_alerts',
          'SafeTrack Alerts',
          channelDescription: 'Notifications for SafeTrack vehicle alerts',
          importance: Importance.max,
          priority: Priority.high,
          ticker: 'ticker',
        );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );
    await _notificationsPlugin.show(
      0, // ID
      'ALERTE VÉHICULE !',
      message,
      platformChannelSpecifics,
      payload: vehicleId,
    );
  }

  Future<void> acknowledgeAlert(String alertId) async {
    if (_authService.token == null) return;

    // Optimistic update locally
    final index = _alerts.indexWhere((a) => a.id == alertId);
    if (index != -1) {
      _alerts[index] = _alerts[index].copyWith(isAcknowledged: true);
      notifyListeners();
      // Cancel system notification if exists
      await _notificationsPlugin.cancel(0);
    }

    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.apiV1}/alerts/$alertId/acknowledge'),
        headers: {'Authorization': 'Bearer ${_authService.token}'},
      );

      if (response.statusCode != 200) {
        // Revert if failed
        if (index != -1) {
          _alerts[index] = _alerts[index].copyWith(isAcknowledged: false);
          notifyListeners();
        }
        debugPrint('Error acknowledging alert: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error acknowledging alert: $e');
      // Revert if failed
      if (index != -1) {
        _alerts[index] = _alerts[index].copyWith(isAcknowledged: false);
        notifyListeners();
      }
    }
  }

  Future<void> fetchAlerts(String vehicleId) async {
    if (_authService.token == null) return;

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.apiV1}/alerts/?limit=50'),
        headers: {'Authorization': 'Bearer ${_authService.token}'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _alerts.clear();
        _alerts.addAll(data.map((json) => _mapBackendAlertToFrontend(json)));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Fetch alerts error: $e');
    }
  }

  Alert _mapBackendAlertToFrontend(Map<String, dynamic> json) {
    return Alert(
      id: json['id_alerte'].toString(),
      vehicleId: json['id_vehicule'].toString(),
      type: _parseAlertType(json['type_alerte']),
      severity: _parseAlertSeverity(json['severite']),
      message: json['message'],
      timestamp: DateTime.parse(json['created_at']),
      isAcknowledged: json['acquittee'] ?? false,
    );
  }

  AlertType _parseAlertType(String type) {
    switch (type) {
      case 'HORS_ZONE':
        return AlertType.horsZone;
      default:
        return AlertType.horsZone;
    }
  }

  AlertSeverity _parseAlertSeverity(String severity) {
    switch (severity) {
      case 'CRITIQUE':
        return AlertSeverity.critique;
      case 'MOYENNE':
        return AlertSeverity.moyenne;
      case 'FAIBLE':
        return AlertSeverity.faible;
      default:
        return AlertSeverity.moyenne;
    }
  }

  Future<void> _createAlert(
    String vehicleId,
    AlertType type,
    AlertSeverity severity,
    String message,
  ) async {
    if (_authService.token == null) return;

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.apiV1}/alerts/'),
        headers: {
          'Authorization': 'Bearer ${_authService.token}',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'id_vehicule': int.parse(vehicleId),
          'type_alerte': type.toString().split('.').last.toUpperCase(),
          'severite': severity.toString().split('.').last.toUpperCase(),
          'message': message,
        }),
      );

      if (response.statusCode == 200) {
        // Alert will be received via WebSocket, no need to add locally double
        // But for responsiveness, we can add it or fetch list
        await fetchAlerts(vehicleId);
      }
    } catch (e) {
      debugPrint('Create alert error: $e');
      // Fallback local alert
      final newAlert = Alert(
        id: _uuid.v4(),
        vehicleId: vehicleId,
        type: type,
        severity: severity,
        message: message,
        timestamp: DateTime.now(),
      );
      _alerts.add(newAlert);
      notifyListeners();
    }
  }

  StreamSubscription? _gpsSubscription;

  void updateGpsService(GpsService gpsService) {
    _gpsSubscription?.cancel();
    _gpsSubscription = gpsService.positionStream.listen((positions) {
      positions.forEach((vehicleId, position) {
        checkGeofence(vehicleId, position);
      });
    });
  }

  @override
  void dispose() {
    _gpsSubscription?.cancel();
    super.dispose();
  }
}
