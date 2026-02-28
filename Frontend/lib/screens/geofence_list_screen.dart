import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../models/vehicle.dart';

import '../services/geofence_service.dart';
import '../theme.dart';
import 'zone_drawing_screen.dart';

class GeofenceListScreen extends StatefulWidget {
  final Vehicle vehicle;

  const GeofenceListScreen({super.key, required this.vehicle});

  @override
  State<GeofenceListScreen> createState() => _GeofenceListScreenState();
}

class _GeofenceListScreenState extends State<GeofenceListScreen> {
  final MapController _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    // Watch geofence service to rebuild on changes
    final geofenceService = context.watch<GeofenceService>();
    final zones = geofenceService.getZones(widget.vehicle.id);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Geofences'),
        backgroundColor: AppTheme.primaryColor,
      ),
      body: Column(
        children: [
          // Map View
          SizedBox(
            height: 250,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: const LatLng(3.8480, 11.5021),
                initialZoom: 13.0,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.safetrack.app',
                ),
                PolygonLayer(
                  polygons: zones
                      .map(
                        (zone) => Polygon(
                          points: zone.polygon,
                          color: zone.isActive
                              ? Colors.green.withOpacity(0.2)
                              : Colors.grey.withOpacity(0.2),
                          borderColor: zone.isActive
                              ? Colors.green
                              : Colors.grey,
                          borderStrokeWidth: 2,
                          label: zone.name,
                          labelStyle: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // List View
          Expanded(
            child: zones.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.location_off,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Aucune zone définie',
                          style: Theme.of(
                            context,
                          ).textTheme.titleLarge?.copyWith(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: zones.length,
                    itemBuilder: (context, index) {
                      final zone = zones[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: ListTile(
                          leading: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.security,
                                color: zone.isActive
                                    ? Colors.green
                                    : Colors.grey,
                                size: 28,
                              ),
                              if (zone.isActive)
                                const Text(
                                  'ACTIF',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),
                          title: Text(
                            zone.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Polygone à ${zone.polygon.length} côtés',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Activate button (if inactive)
                              if (!zone.isActive)
                                IconButton(
                                  icon: const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                  ),
                                  onPressed: () async {
                                    await context
                                        .read<GeofenceService>()
                                        .activateZone(zone.id);
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Zone ${zone.name} activée',
                                          ),
                                          backgroundColor:
                                              AppTheme.successColor,
                                        ),
                                      );
                                    }
                                  },
                                  tooltip: 'Activer',
                                ),

                              // Deactivate button (if active)
                              if (zone.isActive)
                                IconButton(
                                  icon: const Icon(
                                    Icons.cancel,
                                    color: Colors.orange,
                                  ),
                                  onPressed: () async {
                                    await context
                                        .read<GeofenceService>()
                                        .deactivateZone(zone.id);
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Zone ${zone.name} désactivée',
                                          ),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                    }
                                  },
                                  tooltip: 'Désactiver',
                                ),

                              // Delete button
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Supprimer la zone'),
                                      content: Text(
                                        'Êtes-vous sûr de vouloir supprimer "${zone.name}" ?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(ctx).pop(false),
                                          child: const Text('Annuler'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(ctx).pop(true),
                                          child: const Text(
                                            'Supprimer',
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirm == true && mounted) {
                                    context.read<GeofenceService>().deleteZone(
                                      zone.id,
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Zone ${zone.name} supprimée',
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                                tooltip: 'Supprimer',
                              ),
                            ],
                          ),
                          onTap: () {
                            if (zone.polygon.isNotEmpty) {
                              // Calculate center of polygon
                              double latSum = 0;
                              double lngSum = 0;
                              for (var point in zone.polygon) {
                                latSum += point.latitude;
                                lngSum += point.longitude;
                              }
                              final center = LatLng(
                                latSum / zone.polygon.length,
                                lngSum / zone.polygon.length,
                              );

                              _mapController.move(center, 16.0);
                            }
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.accentColor,
        child: const Icon(Icons.add_location_alt),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ZoneDrawingScreen(vehicle: widget.vehicle),
            ),
          );
        },
      ),
    );
  }
}
