import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../models/vehicle.dart';
import '../models/zone.dart';
import '../services/geofence_service.dart';
import '../services/gps_service.dart';
import '../theme.dart';

class ZoneDrawingScreen extends StatefulWidget {
  final Vehicle vehicle;

  const ZoneDrawingScreen({super.key, required this.vehicle});

  @override
  State<ZoneDrawingScreen> createState() => _ZoneDrawingScreenState();
}

class _ZoneDrawingScreenState extends State<ZoneDrawingScreen> {
  final MapController _mapController = MapController();
  final List<LatLng> _polygonPoints = [];

  bool get _canComplete => _polygonPoints.length >= 3;

  @override
  void initState() {
    super.initState();
    // No replacement warning needed - we support multiple zones
  }

  void _onMapTap(TapPosition tapPosition, LatLng latLng) {
    setState(() {
      _polygonPoints.add(latLng);
    });
  }

  void _undoLastPoint() {
    if (_polygonPoints.isNotEmpty) {
      setState(() {
        _polygonPoints.removeLast();
      });
    }
  }

  void _clearAllPoints() {
    setState(() {
      _polygonPoints.clear();
    });
  }

  Future<void> _completePolygon() async {
    if (!_canComplete) return;

    // Show name input dialog
    final nameController = TextEditingController(text: 'Ma Zone');
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nom de la zone'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Entrez le nom de la zone',
            hintText: 'ex: Zone sécurisée, Bureau',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(nameController.text.trim()),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    // Create and save zone (inactive by default)
    final zone = Zone(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      polygon: List.from(_polygonPoints),
      vehicleId: widget.vehicle.id,
      color: AppTheme.accentColor,
      isActive: false, // New zones start inactive
    );

    if (mounted) {
      await context.read<GeofenceService>().addZone(zone);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Zone "$name" créée avec succès'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gpsService = context.watch<GpsService>();
    final gpsPosition = gpsService.getLatestGPS(widget.vehicle.gpsId);
    final currentPosition = gpsPosition != null
        ? LatLng(gpsPosition.latitude, gpsPosition.longitude)
        : null;

    // Center map on vehicle's current position or default to Yaoundé
    final center = currentPosition ?? const LatLng(3.8480, 11.5021);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dessiner une Zone'),
        backgroundColor: AppTheme.primaryColor,
        actions: [
          if (_polygonPoints.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: _clearAllPoints,
              tooltip: 'Tout effacer',
            ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 14.0,
              onTap: _onMapTap,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.safetrack.app',
              ),

              // Drawing preview polygon
              if (_polygonPoints.length >= 2)
                PolygonLayer(
                  polygons: [
                    Polygon(
                      points: _polygonPoints,
                      color: AppTheme.accentColor.withOpacity(0.2),
                      borderColor: AppTheme.accentColor,
                      borderStrokeWidth: 3,
                      isDotted: true,
                    ),
                  ],
                ),

              // Point markers
              MarkerLayer(
                markers: _polygonPoints.asMap().entries.map((entry) {
                  final index = entry.key;
                  final point = entry.value;
                  final isFirst = index == 0;

                  return Marker(
                    point: point,
                    width: 40,
                    height: 40,
                    child: GestureDetector(
                      onTap: () {
                        // TODO: Allow removing specific point
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isFirst ? Colors.green : AppTheme.accentColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              // Vehicle position marker
              if (currentPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: currentPosition,
                      width: 30,
                      height: 30,
                      child: const Icon(
                        Icons.navigation,
                        color: Colors.blue,
                        size: 30,
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // Bottom control bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Points counter
                  Text(
                    'Points: ${_polygonPoints.length}${_canComplete ? ' ✓' : ' (min 3)'}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),

                  // Action buttons
                  Row(
                    children: [
                      // Undo button
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _polygonPoints.isEmpty
                              ? null
                              : _undoLastPoint,
                          icon: const Icon(Icons.undo),
                          label: const Text('Annuler'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Clear button
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _polygonPoints.isEmpty
                              ? null
                              : _clearAllPoints,
                          icon: const Icon(Icons.clear),
                          label: const Text('Effacer'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Complete button
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: _canComplete ? _completePolygon : null,
                          icon: const Icon(Icons.check_circle),
                          label: const Text('Terminer'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentColor,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
