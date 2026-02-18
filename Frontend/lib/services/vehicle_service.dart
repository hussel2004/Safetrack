import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/vehicle.dart';
import '../models/stop_mode.dart';
import '../config/api_config.dart';
import 'auth_service.dart';

class VehicleService extends ChangeNotifier {
  final AuthService _authService;
  List<Vehicle> _vehicles = [];

  List<Vehicle> get vehicles => List.unmodifiable(_vehicles);

  VehicleService(this._authService);

  Future<void> fetchVehicles() async {
    if (_authService.token == null) return;

    try {
      debugPrint('🔍 Fetching vehicles from API...');
      final response = await http.get(
        // Append trailing slash to avoid 307 Redirect which might drop Auth headers
        Uri.parse('${ApiConfig.vehicles}/'),
        headers: {'Authorization': 'Bearer ${_authService.token}'},
      );

      debugPrint('📡 Response status: ${response.statusCode}');
      debugPrint('📦 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        debugPrint('✅ Parsed ${data.length} vehicles from JSON');
        _vehicles = data.map((json) => Vehicle.fromBackendJson(json)).toList();
        debugPrint('🚗 Vehicle list length: ${_vehicles.length}');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ Fetch vehicles error: $e');
    }
  }

  Future<String?> registerVehicle(
    String ownerId,
    String name,
    String brand,
    String model,
    int year,
    String licensePlate,
    String deveui, {
    StopMode stopMode = StopMode.manual,
  }) async {
    if (_authService.token == null) return 'Non authentifié';

    try {
      final response = await http.post(
        // Append trailing slash to avoid 307 Redirect
        Uri.parse('${ApiConfig.vehicles}/'),
        headers: {
          'Authorization': 'Bearer ${_authService.token}',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'nom': name,
          'marque': brand,
          'modele': model,
          'annee': year,
          'immatriculation': licensePlate,
          'deveui': deveui.toUpperCase(),
          'statut': 'ACTIF',
          'moteur_coupe': stopMode == StopMode.automatic,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchVehicles();
        return null; // Success
      } else {
        debugPrint(
          'Register vehicle failed: ${response.statusCode} - ${response.body}',
        );
        // Try to parse detailed error message
        try {
          final errorData = json.decode(response.body);
          if (errorData['detail'] != null) {
            return 'Erreur: ${errorData['detail']}';
          }
        } catch (_) {}
        return 'Échec de l\'enregistrement (${response.statusCode})';
      }
    } catch (e) {
      debugPrint('Register vehicle error: $e');
      return 'Erreur de connexion: $e';
    }
  }

  Future<void> updateVehicle(
    String vehicleId,
    String name,
    String brand,
    String model,
    int year,
    StopMode stopMode,
  ) async {
    if (_authService.token == null) return;

    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.vehicles}/$vehicleId'),
        headers: {
          'Authorization': 'Bearer ${_authService.token}',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'nom': name,
          'marque': brand,
          'modele': model,
          'annee': year,
          'moteur_coupe': stopMode == StopMode.automatic,
        }),
      );

      if (response.statusCode == 200) {
        await fetchVehicles();
      }
    } catch (e) {
      debugPrint('Update vehicle error: $e');
    }
  }

  Future<void> setEngineStatus(String vehicleId, bool stopped) async {
    if (_authService.token == null) return;

    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.vehicles}/$vehicleId'),
        headers: {
          'Authorization': 'Bearer ${_authService.token}',
          'Content-Type': 'application/json',
        },
        body: json.encode({'moteur_coupe': stopped}),
      );

      if (response.statusCode == 200) {
        await fetchVehicles();
        if (stopped) {
          debugPrint('Engine STOP command sent for $vehicleId');
        } else {
          debugPrint('Engine START command sent for $vehicleId');
        }
      } else {
        debugPrint('Set engine status failed: ${response.body}');
      }
    } catch (e) {
      debugPrint('Set engine status error: $e');
    }
  }

  Future<void> deleteVehicle(String vehicleId) async {
    if (_authService.token == null) return;

    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.vehicles}/$vehicleId'),
        headers: {'Authorization': 'Bearer ${_authService.token}'},
      );

      if (response.statusCode == 200) {
        await fetchVehicles();
      }
    } catch (e) {
      debugPrint('Delete vehicle error: $e');
    }
  }

  Vehicle? getVehicleById(String id) {
    try {
      return _vehicles.firstWhere((v) => v.id == id);
    } catch (e) {
      return null;
    }
  }
}
