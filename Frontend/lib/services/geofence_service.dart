import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  SharedPreferences? _prefs;

  GeofenceService(this._authService) {
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    await _initializeNotifications();
    _prefs = await SharedPreferences.getInstance();
    await _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    if (_prefs == null) return;
    final String? alertsJson = _prefs!.getString('alerts_list');
    if (alertsJson != null) {
      try {
        final List<dynamic> decoded = json.decode(alertsJson);
        _alerts.clear();
        _alerts.addAll(
          decoded.map(
            (item) => Alert(
              id: item['id'],
              vehicleId: item['vehicleId'],
              type: _parseAlertType(item['type']),
              severity: _parseAlertSeverity(item['severity']),
              message: item['message'],
              timestamp: DateTime.parse('${item['timestamp']}Z').toLocal(),
              isAcknowledged: item['isAcknowledged'] ?? false,
            ),
          ),
        );
        notifyListeners();
      } catch (e) {
        debugPrint('Error loading local alerts: $e');
      }
    }
  }

  Future<void> _saveAlerts() async {
    if (_prefs == null) return;
    try {
      final String encoded = json.encode(
        _alerts
            .map(
              (a) => {
                'id': a.id,
                'vehicleId': a.vehicleId,
                'type': a.type.toString().split('.').last.toUpperCase(),
                'severity': a.severity.toString().split('.').last.toUpperCase(),
                'message': a.message,
                'timestamp': a.timestamp.toIso8601String(),
                'isAcknowledged': a.isAcknowledged,
              },
            )
            .toList(),
      );
      await _prefs!.setString('alerts_list', encoded);
    } catch (e) {
      debugPrint('Error saving local alerts: $e');
    }
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Note: iOS settings would go here
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        if (response.actionId == 'STOP_ALERT' && response.payload != null) {
          final vehicleId = response.payload!;
          // Find the latest unacknowledged alert for this vehicle
          try {
            final alerts = getAlerts(vehicleId);
            final activeAlert = alerts.firstWhere(
              (a) => !a.isAcknowledged && a.type == AlertType.horsZone,
              orElse: () => alerts.first, // Fallback
            );
            await acknowledgeAlert(activeAlert.id);
          } catch (e) {
            debugPrint('Error handling notification action: $e');
          }
        }
      },
    );
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

  // Activate a zone — désactive automatiquement toute zone précédemment active
  Future<void> activateZone(String zoneId) async {
    if (_authService.token == null) return;

    final index = _zones.indexWhere((z) => z.id == zoneId);
    if (index == -1) return;

    final zone = _zones[index];

    // 1. Déactiver toute autre zone active pour le même véhicule (backend)
    final otherActive = _zones
        .where(
          (z) => z.vehicleId == zone.vehicleId && z.id != zoneId && z.isActive,
        )
        .toList();

    for (final other in otherActive) {
      await _updateZoneStatus(other.id, false);
    }

    // 2. Activer la zone demandée
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

  Future<void> checkGeofence(String vehicleId, GpsPosition position) async {
    if (_prefs == null) return; // Wait for initialization

    final vehicleZones = getZones(vehicleId).where((z) => z.isActive).toList();
    if (vehicleZones.isEmpty) return;

    bool currentlyInside = false;

    // Check if inside ANY active zone
    // Backend uses Circles, Frontend model uses Polygons generated from circles
    // So containsPoint is still valid for the circular polygon approximation
    final point = LatLng(position.latitude, position.longitude);

    for (final zone in vehicleZones) {
      if (zone.containsPoint(point)) {
        currentlyInside = true;
        break;
      }
    }

    final String stateKey = 'geofence_state_$vehicleId';
    bool wasInside =
        _prefs!.getBool(stateKey) ?? true; // Default to true (safe)

    // Transition: Inside -> Outside
    if (wasInside && !currentlyInside) {
      final message = "Le véhicule est hors de la zone de sécurité !";
      // Create NEW alert
      await _createAlert(
        vehicleId,
        AlertType.horsZone,
        AlertSeverity.critique,
        message,
      );
      // Show notification (sound)
      await _showSystemNotification(vehicleId, message);

      // Update state
      await _prefs!.setBool(stateKey, false);
    }
    // State: Still Outside
    else if (!wasInside && !currentlyInside) {
      // Find active (latest) alert
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

      if (lastAlert != null) {
        // If NOT acknowledged and enough time passed, REMIND
        if (!lastAlert.isAcknowledged &&
            DateTime.now().difference(lastAlert.timestamp).inSeconds > 30) {
          // We don't create a new alert object, just re-notify
          // Actually, user wants "stop" to silence.
          // If we re-notify, we might annoy.
          // But if we don't re-notify, a short beep might be missed.
          // Let's re-notify only if it continues to be unacknowledged,
          // but maybe throttle it? The condition > 30s checks timestamp of ALERT.
          // This means it notifies ONCE after 30s? No.
          // If I rely on `checkGeofence` loop (1s), this condition is true FOREVER after 30s.
          // So it would spam every second after 30s! BAD.

          // Solution: We need `lastNotificationTime`.
          // Or, simplistic: Just notify ONCE on transition (standard mobile behavior).
          // User said "stopper pour que ca arrete de pertuber".
          // This implies it IS perturbing (repeating).
          // If I want repeating alarm:
          // I need to track `lastNotificationTime` in memory.
          // For now, let's stick to: Notify on transition.
          // AND if unacknowledged, MAYBE remind every minute?
          // To implement repetition properly without variable explosion:
          // Let's just notify ONCE on transition.
          // The "Stopper" button then just marks it as read/acknowledged in history.
          // Does "Stopper" imply stopping a generic recurring sound?
          // If the notification has a sound, it plays once.
          // Unless `ongoing: true`?
          // If `ongoing` (persistent notification), "Stop" removes it.
          // Let's try to use ongoing notification for "Outside Zone".
        }
      }
    }
    // Transition: Outside -> Inside
    else if (!wasInside && currentlyInside) {
      // Back to safety
      await _prefs!.setBool(stateKey, true);

      // Optional: Cancel notification
      await _notificationsPlugin.cancel(0); // Assuming ID 0 is the alert
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
          ongoing: true, // Persistent until stopped/acknowledged
          autoCancel: false,
          actions: <AndroidNotificationAction>[
            AndroidNotificationAction('STOP_ALERT', 'Arrêter l\'alarme'),
          ],
        );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );
    await _notificationsPlugin.show(
      0, // ID. Ideally distinct per vehicle/alert, but using 0 for simplicity as per requirement
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
      await _saveAlerts();
      notifyListeners();
      // Cancel system notification
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
          await _saveAlerts();
          notifyListeners();
        }
        debugPrint('Error acknowledging alert: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error acknowledging alert: $e');
      // Revert if failed
      if (index != -1) {
        _alerts[index] = _alerts[index].copyWith(isAcknowledged: false);
        await _saveAlerts();
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
        final fetchedAlerts = data
            .map((json) => _mapBackendAlertToFrontend(json))
            .toList();

        // Merge strategy: Keep local alerts that are NOT in fetched (unsynced)
        // and update defaults with fetched.
        // Actually, simplest is: Add fetched, remove duplicates by ID.
        // But local IDs might be UUIDs, backend IDs are Ints (as strings).
        // If we have a local alert that failed to sync, it has a UUID.
        // Backend alerts have numeric IDs.
        // So we can keep both?
        // But we don't want to show duplicates if we eventually sync.

        // For now: Add fetched to _alerts.
        // If we clear _alerts, we lose UUID ones.
        // So:
        final existingUnsynced = _alerts
            .where((a) => int.tryParse(a.id) == null)
            .toList();
        _alerts.clear();
        _alerts.addAll(fetchedAlerts);
        _alerts.addAll(existingUnsynced); // Re-add unsynced

        // Sort
        _alerts.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        await _saveAlerts();
        notifyListeners();
        debugPrint('✅ Validated ${fetchedAlerts.length} alerts from backend.');
      }
    } catch (e) {
      debugPrint('❌ Fetch alerts error: $e');
    }
  }

  Alert _mapBackendAlertToFrontend(Map<String, dynamic> json) {
    return Alert(
      id: json['id_alerte'].toString(),
      vehicleId: json['id_vehicule'].toString(),
      type: _parseAlertType(json['type_alerte']),
      severity: _parseAlertSeverity(json['severite']),
      message: json['message'],
      timestamp: DateTime.parse('${json['created_at']}Z').toLocal(),
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
      debugPrint('❌ Create alert error (Backend failed): $e');
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
      await _saveAlerts();
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
