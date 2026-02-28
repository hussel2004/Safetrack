class ApiConfig {
  // Pour un émulateur Android: http://10.0.2.2:8000
  // Pour un appareil physique: Utilisez l'IP WiFi de votre PC
  // Pour iOS Simulator: http://localhost:8000
  // Use localhost with adb reverse tcp:8000 tcp:8000
  static const String baseUrl = 'http://192.168.1.115:8000';
  static const String apiV1 = '$baseUrl/api/v1';

  // Endpoints
  static const String login = '$apiV1/auth/login/access-token';
  static const String register = '$apiV1/auth/register';
  static const String vehicles = '$apiV1/vehicles';
  static const String geofences = '$apiV1/geofences';
  static const String tracking = '$apiV1/tracking';
}
