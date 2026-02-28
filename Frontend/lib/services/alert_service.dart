import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'notification_service.dart';
import '../config/api_config.dart';

class AlertService extends ChangeNotifier {
  final AuthService _authService;
  final NotificationService _notificationService = NotificationService();

  Timer? _pollingTimer;
  Set<int> _alreadyNotifiedAlerts = {};
  bool _isPolling = false;

  AlertService(this._authService) {
    debugPrint('======================================');
    debugPrint('[AlertService] Constructor called!');
    debugPrint('======================================');
    if (_authService.isAuthenticated) {
      startPolling();
    }
  }

  void startPolling() {
    debugPrint('[AlertService] startPolling() called!');
    if (_isPolling) return;
    _isPolling = true;
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkNewAlerts();
    });
    // Initial check
    _checkNewAlerts();
  }

  void stopPolling() {
    _isPolling = false;
    _pollingTimer?.cancel();
  }

  Future<void> _checkNewAlerts() async {
    debugPrint('[AlertService] Polling for new alerts...');
    if (!_authService.isAuthenticated) {
      debugPrint('[AlertService] Not authenticated, stopping poll.');
      stopPolling();
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.apiV1}/alerts/'),
        headers: {'Authorization': 'Bearer ${_authService.token}'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> alertsData = json.decode(response.body);
        debugPrint('[AlertService] Found ${alertsData.length} alerts');

        for (var alert in alertsData) {
          final int alertId = alert['id_alerte'];

          if (!_alreadyNotifiedAlerts.contains(alertId)) {
            // New alert found!
            _alreadyNotifiedAlerts.add(alertId);

            // Trigger local notification
            final String type = alert['type'] ?? 'ALERTE';
            final String vehicule = alert['vehicule_nom'] ?? 'Véhicule';

            await _notificationService.showNotification(
              id: alertId,
              title: '⚠️ SafeTrack : $type',
              body:
                  'Alerte sur $vehicule : ${alert['description'] ?? 'Activité suspecte'}',
              payload: alertId.toString(),
            );
          } else {
            debugPrint('[AlertService] Alert $alertId already notified.');
          }
        }
      } else {
        debugPrint(
          '[AlertService] Alert polling failed with status ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Error polling alerts: $e');
    }
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}
