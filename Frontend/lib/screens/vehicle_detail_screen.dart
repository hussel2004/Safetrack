import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/vehicle.dart';
import '../services/gps_service.dart';
import '../services/vehicle_service.dart';
import '../widgets/custom_app_bar.dart';
import '../theme.dart';
import 'geofence_list_screen.dart';
import 'alerts_screen.dart';

import 'vehicle_edit_screen.dart';
import 'vehicle_tracking_screen.dart';

class VehicleDetailScreen extends StatefulWidget {
  final Vehicle vehicle;

  const VehicleDetailScreen({super.key, required this.vehicle});

  @override
  State<VehicleDetailScreen> createState() => _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends State<VehicleDetailScreen> {
  bool _isEngineActionLoading = false;
  Timer? _pendingPollTimer;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _pendingPollTimer?.cancel();
    super.dispose();
  }

  void _startPollingIfNeeded(bool isEnAttente, VehicleService vehicleService) {
    if (isEnAttente &&
        (_pendingPollTimer == null || !_pendingPollTimer!.isActive)) {
      _pendingPollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
        await vehicleService.fetchVehicles();
        // Check if still pending after refresh — if not, cancel timer
        final updated = vehicleService.getVehicleById(widget.vehicle.id);
        if (updated != null && !updated.moteurEnAttente) {
          _pendingPollTimer?.cancel();
          _pendingPollTimer = null;
        }
      });
    } else if (!isEnAttente) {
      _pendingPollTimer?.cancel();
      _pendingPollTimer = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final gpsService = context.watch<GpsService>();
    final vehicleService = context.watch<VehicleService>();

    // Start tracking when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GpsService>().startTracking([widget.vehicle.id]);
    });

    // Get live vehicle data
    final vehicle =
        vehicleService.getVehicleById(widget.vehicle.id) ?? widget.vehicle;
    final gps = gpsService.getLatestGPS(vehicle.id);

    // Auto-poll while waiting for engine command confirmation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startPollingIfNeeded(vehicle.moteurEnAttente, vehicleService);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails du Véhicule'),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => VehicleEditScreen(vehicle: vehicle),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Vehicle Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            vehicle.name,
                            style: Theme.of(context).textTheme.headlineSmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.accentColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            vehicle.year.toString(),
                            style: const TextStyle(
                              color: AppTheme.accentColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${vehicle.brand} ${vehicle.model}',
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium!.copyWith(color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: Colors.white24),
                    const SizedBox(height: 8),
                    _buildInfoRow('Immatriculation', vehicle.licensePlate),
                    _buildInfoRow('DevEUI', vehicle.deveui),
                    _buildInfoRow('ID Dispositif GPS', vehicle.gpsId),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'État du Relais :',
                          style: TextStyle(color: Colors.white70),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: vehicle.isEngineStopped
                                ? Colors.red
                                : Colors.green,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            vehicle.isEngineStopped ? 'ARRÊTÉ' : 'EN MARCHE',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // --- Connectivity Status Row ---
                    Builder(
                      builder: (context) {
                        final gps = context.watch<GpsService>();
                        final online = gps.isVehicleOnline(vehicle.id);
                        final lastSeen = gps.getLastSeen(vehicle.id);
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Connectivité :',
                              style: TextStyle(color: Colors.white70),
                            ),
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: online ? Colors.green : Colors.red,
                                    shape: BoxShape.circle,
                                    boxShadow: online
                                        ? [
                                            BoxShadow(
                                              color: Colors.green.withOpacity(
                                                0.5,
                                              ),
                                              blurRadius: 4,
                                              spreadRadius: 1,
                                            ),
                                          ]
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  online
                                      ? 'En ligne'
                                      : lastSeen != null
                                      ? 'Hors ligne (${_fmtSeen(lastSeen)})'
                                      : 'Hors ligne (jamais vu)',
                                  style: TextStyle(
                                    color: online
                                        ? Colors.green
                                        : Colors.redAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // GPS Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Position GPS',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    if (gps != null) ...[
                      _buildInfoRow(
                        'Latitude',
                        gps.latitude.toStringAsFixed(6),
                      ),
                      _buildInfoRow(
                        'Longitude',
                        gps.longitude.toStringAsFixed(6),
                      ),
                      _buildInfoRow(
                        'Vitesse',
                        '${gps.speed.toStringAsFixed(1)} km/h',
                      ),
                      _buildInfoRow('Timestamp', gps.timestamp.toString()),
                    ] else
                      const Text('Aucune donnée GPS disponible'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Track Vehicle Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.map),
                label: const Text('Suivre le Véhicule en Temps Réel'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => VehicleTrackingScreen(vehicle: vehicle),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Monitoring & Alerts
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Surveillance & Alertes',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.map),
                            label: const Text('Géoreperage'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      GeofenceListScreen(vehicle: vehicle),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.notifications_active),
                            label: const Text('Alertes'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      AlertsScreen(vehicle: vehicle),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Engine Control
            Card(
              color: vehicle.isEngineStopped
                  ? Colors.green.withOpacity(0.1)
                  : Colors.red.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- Mode Auto Banner ---
                    if (vehicle.modeAuto)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.blueAccent.withOpacity(0.5),
                          ),
                        ),
                        child: Row(
                          children: const [
                            Icon(
                              Icons.auto_mode,
                              color: Colors.blueAccent,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Mode automatique actif — le serveur coupe le relais automatiquement en cas de sortie de zone.',
                                style: TextStyle(
                                  color: Colors.blueAccent,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (vehicle.moteurEnAttente) ...[
                      const Center(
                        child: Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text(
                              'En attente de confirmation du boîtier...',
                              style: TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (vehicle.isEngineStopped) ...[
                      const Text(
                        'Moteur ARRÊTÉ',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _isEngineActionLoading
                          ? const Center(child: CircularProgressIndicator())
                          : SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.play_arrow),
                                label: const Text('DÉMARRER LE MOTEUR'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                                onPressed: () async {
                                  setState(() {
                                    _isEngineActionLoading = true;
                                  });
                                  await context
                                      .read<VehicleService>()
                                      .setEngineStatus(vehicle.id, false);

                                  if (mounted) {
                                    setState(() {
                                      _isEngineActionLoading = false;
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Commande de démarrage envoyée. En attente de confirmation...',
                                        ),
                                        backgroundColor: Colors.orange,
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                    ] else ...[
                      const Text(
                        'Moteur EN MARCHE',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Si mode AUTO actif → pas de bouton STOP manuel
                      if (!vehicle.modeAuto)
                        _isEngineActionLoading
                            ? const Center(child: CircularProgressIndicator())
                            : SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.stop),
                                  label: const Text('ARRÊTER LE MOTEUR'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                  ),
                                  onPressed: () async {
                                    setState(() {
                                      _isEngineActionLoading = true;
                                    });
                                    await context
                                        .read<VehicleService>()
                                        .setEngineStatus(vehicle.id, true);

                                    if (mounted) {
                                      setState(() {
                                        _isEngineActionLoading = false;
                                      });
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Commande d\'arrêt envoyée. En attente de confirmation...',
                                          ),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

String _fmtSeen(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'il y a ${diff.inSeconds}s';
  if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'il y a ${diff.inHours}h';
  return 'il y a ${diff.inDays}j';
}
