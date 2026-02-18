import 'package:flutter/foundation.dart';

class CommandService extends ChangeNotifier {
  // Simulates sending a Stop command to the IoT device
  Future<bool> stopVehicleEngine(String vehicleId) async {
    // Mock network latency for IoT communication
    await Future.delayed(const Duration(seconds: 2));

    // Simulate 90% success rate
    return true;
  }

  // Generic command sender
  Future<bool> sendCommand(String vehicleId, String command,
      {Map<String, dynamic>? data}) async {
    // Mock network latency
    await Future.delayed(const Duration(seconds: 1));

    if (kDebugMode) {
      print(
          'Sending command: $command to vehicle: $vehicleId with data: $data');
    }

    // Simulate success
    return true;
  }
}
