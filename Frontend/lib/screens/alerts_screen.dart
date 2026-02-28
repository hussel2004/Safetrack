import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/vehicle.dart';
import '../models/alert.dart';
import '../services/geofence_service.dart';
import '../theme.dart';

class AlertsScreen extends StatefulWidget {
  final Vehicle vehicle;

  const AlertsScreen({super.key, required this.vehicle});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GeofenceService>().fetchAlerts(widget.vehicle.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final geofenceService = context.watch<GeofenceService>();
    final alerts = geofenceService.getAlerts(widget.vehicle.id);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alerts History'),
        backgroundColor: AppTheme.primaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              geofenceService.fetchAlerts(widget.vehicle.id);
            },
          ),
        ],
      ),
      body: alerts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.notifications_none,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No alerts recorded',
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      geofenceService.fetchAlerts(widget.vehicle.id);
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Rafraîchir'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: alerts.length,
              itemBuilder: (context, index) {
                final alert = alerts[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ListTile(
                    leading: Icon(
                      Icons.warning,
                      color: _getSeverityColor(alert.severity),
                    ),
                    title: Text(alert.message),
                    subtitle: Text(
                      DateFormat('yyyy-MM-dd HH:mm:ss').format(alert.timestamp),
                    ),
                    trailing: alert.isAcknowledged
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : IconButton(
                            icon: const Icon(
                              Icons.notifications_off_outlined,
                              color: Colors.red,
                            ),
                            tooltip: 'Arrêter l\'alarme',
                            onPressed: () {
                              geofenceService.acknowledgeAlert(alert.id);
                            },
                          ),
                    onTap: () {
                      // Optional: Show details dialog
                    },
                  ),
                );
              },
            ),
    );
  }

  Color _getSeverityColor(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.critique:
        return Colors.red;
      case AlertSeverity.moyenne:
        return Colors.orange;
      case AlertSeverity.faible:
        return Colors.yellow;
    }
  }
}
