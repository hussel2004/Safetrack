import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/vehicle.dart';
import '../services/gps_service.dart';
import '../services/geofence_service.dart';
import '../theme.dart';
import '../utils/kalman_filter.dart';

class VehicleTrackingScreen extends StatefulWidget {
  final Vehicle vehicle;

  const VehicleTrackingScreen({super.key, required this.vehicle});

  @override
  State<VehicleTrackingScreen> createState() => _VehicleTrackingScreenState();
}

class _VehicleTrackingScreenState extends State<VehicleTrackingScreen> {
  final MapController _mapController = MapController();
  bool _followVehicle = true;

  // Kalman filters for lat and long
  final KalmanFilter _latFilter = KalmanFilter(
    processNoise: 0.1,
    measurementNoise: 2.0,
  );
  final KalmanFilter _lngFilter = KalmanFilter(
    processNoise: 0.1,
    measurementNoise: 2.0,
  );
  DateTime? _lastGpsUpdate;

  @override
  void initState() {
    super.initState();
    // Start tracking real GPS data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GpsService>().startTracking([widget.vehicle.id]);
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gpsService = context.watch<GpsService>();
    final geofenceService = context.watch<GeofenceService>();
    final gps = gpsService.getLatestGPS(widget.vehicle.id);
    final zones = geofenceService.getZones(widget.vehicle.id);

    // Apply Kalman filter
    double lat = gps?.latitude ?? 0;
    double lng = gps?.longitude ?? 0;

    if (gps != null) {
      // Reset filters if data is stale (e.g. > 10 seconds old) or first run
      if (_lastGpsUpdate == null ||
          gps.timestamp.difference(_lastGpsUpdate!).inSeconds > 10) {
        _latFilter.reset();
        _lngFilter.reset();
      }

      if (gps.timestamp != _lastGpsUpdate) {
        lat = _latFilter.filter(gps.latitude);
        lng = _lngFilter.filter(gps.longitude);
        _lastGpsUpdate = gps.timestamp;

        // Auto-center map on vehicle if following AND position changed
        if (_followVehicle) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            try {
              // _mapController.camera might throw if map is not ready yet
              _mapController.move(LatLng(lat, lng), _mapController.camera.zoom);
            } catch (e) {
              debugPrint('MapController not ready yet: $e');
            }
          });
        }
      }
    }

    final center = (gps != null)
        ? LatLng(lat, lng)
        : const LatLng(3.8480, 11.5021);

    return Scaffold(
      appBar: AppBar(
        title: Text('Tracking: ${widget.vehicle.name}'),
        backgroundColor: AppTheme.primaryColor,
        actions: [
          IconButton(
            icon: Icon(_followVehicle ? Icons.gps_fixed : Icons.gps_not_fixed),
            onPressed: () {
              setState(() {
                _followVehicle = !_followVehicle;
              });
            },
            tooltip: _followVehicle ? 'Auto-follow ON' : 'Auto-follow OFF',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Full-screen map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 16.0,
              minZoom: 10.0,
              maxZoom: 19.0,
              onPositionChanged: (position, hasGesture) {
                if (hasGesture) {
                  setState(() {
                    _followVehicle = false;
                  });
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.safetrack.app',
              ),

              // Geofence zones as polygons
              PolygonLayer(
                polygons: zones
                    .where((z) => z.isActive)
                    .map(
                      (zone) => Polygon(
                        points: zone.polygon,
                        color: zone.color.withOpacity(0.2),
                        borderColor: zone.color,
                        borderStrokeWidth: 2,
                      ),
                    )
                    .toList(),
              ),

              // Vehicle marker
              if (gps != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(lat, lng),
                      width: 60,
                      height: 60,
                      alignment: Alignment.center,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.directions_car,
                          color: AppTheme.accentColor,
                          size: 32,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // --- Offline overlay banner ---
          if (!gpsService.isVehicleOnline(widget.vehicle.id))
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.shade900.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade400, width: 1.5),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Boîtier Hors Ligne',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          if (gpsService.getLastSeen(widget.vehicle.id) != null)
                            Text(
                              'Dernière comm. : ${_formatLastSeen(gpsService.getLastSeen(widget.vehicle.id)!)}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            )
                          else
                            const Text(
                              'Aucune donnée reçue',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Info overlay
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Card(
              color: AppTheme.surfaceColor.withOpacity(0.95),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.vehicle.name,
                            style: Theme.of(context).textTheme.titleLarge!
                                .copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: gpsService.isVehicleOnline(widget.vehicle.id)
                                ? AppTheme.successColor.withOpacity(0.1)
                                : Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color:
                                  gpsService.isVehicleOnline(widget.vehicle.id)
                                  ? AppTheme.successColor
                                  : Colors.red,
                            ),
                          ),
                          child: Text(
                            gpsService.isVehicleOnline(widget.vehicle.id)
                                ? 'EN LIGNE'
                                : 'HORS LIGNE',
                            style: TextStyle(
                              color:
                                  gpsService.isVehicleOnline(widget.vehicle.id)
                                  ? AppTheme.successColor
                                  : Colors.redAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (gps != null) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _InfoItem(
                            icon: Icons.speed,
                            label: 'Speed',
                            value: '${gps.speed.toStringAsFixed(1)} km/h',
                          ),
                          _InfoItem(
                            icon: Icons.location_on,
                            label: 'Position',
                            value:
                                '${gps.latitude.toStringAsFixed(4)}, ${gps.longitude.toStringAsFixed(4)}',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _InfoItem(
                            icon: Icons.security,
                            label: 'Active Zones',
                            value: '${zones.where((z) => z.isActive).length}',
                          ),
                          _InfoItem(
                            icon: Icons.update,
                            label: 'Last Update',
                            value:
                                '${DateTime.now().difference(gps.timestamp).inSeconds}s ago',
                          ),
                        ],
                      ),
                    ] else
                      const Text('No GPS data available'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Formate la durée depuis la dernière communication de façon lisible.
String _formatLastSeen(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'Il y a ${diff.inSeconds}s';
  if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
  return 'Il y a ${diff.inDays}j';
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.accentColor),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall!.copyWith(color: Colors.white70),
                ),
                Text(
                  value,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall!.copyWith(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
