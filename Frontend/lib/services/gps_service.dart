import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/gps_position.dart';
import '../config/api_config.dart';
import 'auth_service.dart';

class GpsService extends ChangeNotifier {
  final AuthService _authService;
  final Map<String, GpsPosition> _latestPositions = {};
  final StreamController<Map<String, GpsPosition>> _positionController =
      StreamController.broadcast();
  Timer? _timer;

  GpsService(this._authService);

  Stream<Map<String, GpsPosition>> get positionStream =>
      _positionController.stream;
  Map<String, GpsPosition> get latestPositions => _latestPositions;

  GpsPosition? getLatestGPS(String vehicleId) {
    return _latestPositions[vehicleId];
  }

  /// Retourne true si une position GPS a été reçue dans les 5 dernières minutes.
  /// Permet d'afficher l'indicateur hors ligne en temps réel.
  bool isVehicleOnline(String vehicleId) {
    final pos = _latestPositions[vehicleId];
    if (pos == null) return false;
    return DateTime.now().difference(pos.timestamp).inMinutes < 5;
  }

  /// Retourne le timestamp de la dernière communication GPS connue, ou null.
  DateTime? getLastSeen(String vehicleId) {
    return _latestPositions[vehicleId]?.timestamp;
  }

  void startTracking(List<String> vehicleIds) {
    _timer?.cancel();
    // Poll immediately, then every 3 seconds
    _fetchPositionsFromApi(vehicleIds);
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _fetchPositionsFromApi(vehicleIds);
    });
  }

  Future<void> _fetchPositionsFromApi(List<String> vehicleIds) async {
    if (_authService.token == null) return;

    for (var vehicleId in vehicleIds) {
      try {
        final response = await http.get(
          Uri.parse('${ApiConfig.tracking}/$vehicleId?limit=1'),
          headers: {'Authorization': 'Bearer ${_authService.token}'},
        );

        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          if (data.isNotEmpty) {
            final latest = data.first;
            _latestPositions[vehicleId] = GpsPosition(
              vehicleId: vehicleId,
              latitude: double.parse(latest['latitude'].toString()),
              longitude: double.parse(latest['longitude'].toString()),
              speed: double.parse(latest['vitesse'].toString()),
              timestamp: DateTime.parse('${latest['timestamp_gps']}Z').toLocal(),
            );
            debugPrint(
              '📍 GPS Update for $vehicleId: ${latest['latitude']}, ${latest['longitude']}',
            );
          }
        }
      } catch (e) {
        debugPrint('❌ Error fetching GPS for $vehicleId: $e');
      }
    }
    _positionController.add(_latestPositions);
    notifyListeners();
  }

  void stopTracking() {
    _timer?.cancel();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _positionController.close();
    super.dispose();
  }
}
