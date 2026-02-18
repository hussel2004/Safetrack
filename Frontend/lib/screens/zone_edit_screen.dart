import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import '../models/vehicle.dart';
import '../models/zone.dart';
import '../services/geofence_service.dart';
import '../services/gps_service.dart';
import '../theme.dart';

class ZoneEditScreen extends StatefulWidget {
  final Vehicle vehicle;
  final Zone? zone;

  const ZoneEditScreen({super.key, required this.vehicle, this.zone});

  @override
  State<ZoneEditScreen> createState() => _ZoneEditScreenState();
}

class _ZoneEditScreenState extends State<ZoneEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final MapController _mapController = MapController();

  late String _name;
  late int _sides;
  late double _radius;
  late LatLng _center;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    if (widget.zone != null) {
      _name = widget.zone!.name;
      _sides = widget.zone!.polygon.length;
      _radius = 100.0; // Approximate from polygon
      _center = widget.zone!.center;
      _isActive = widget.zone!.isActive;
    } else {
      _name = '';
      _sides = 12;
      _radius = 100.0;
      // Default to Yaoundé
      _center = LatLng(3.8480, 11.5021);
      _isActive = true;
    }
  }

  void _useCurrentGpsPosition() {
    final gpsService = context.read<GpsService>();
    final gps = gpsService.getLatestGPS(widget.vehicle.gpsId);

    if (gps != null) {
      setState(() {
        _center = LatLng(gps.latitude, gps.longitude);
      });
      _mapController.move(_center, 15.0);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Using current GPS position'),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('GPS position not available'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _saveZone() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final service = context.read<GeofenceService>();

      if (widget.zone != null) {
        // For now, just update the name and active status
        // Full polygon editing would require more complex UI
        service.updateZone(
          widget.zone!.copyWith(name: _name, isActive: _isActive),
        );
      } else {
        service.addZone(
          Zone.fromCenterRadius(
            id: DateTime.now().millisecondsSinceEpoch
                .toString(), // Simple ID generation
            name: _name,
            center: _center,
            radius: _radius,
            sides: _sides,
            vehicleId: widget.vehicle.id,
            isActive: _isActive,
          ),
        );
      }
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final gpsService = context.watch<GpsService>();
    final vehicleGps = gpsService.getLatestGPS(widget.vehicle.gpsId);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.zone != null ? 'Edit Zone' : 'New Zone'),
        backgroundColor: AppTheme.primaryColor,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Interactive Map
            SizedBox(
              height: 400,
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _center,
                  initialZoom: 15.0,
                  minZoom: 3.0,
                  maxZoom: 18.0,
                  onTap: (tapPosition, point) {
                    setState(() {
                      _center = point;
                    });
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.safetrack.app',
                  ),
                  // Zone circle overlay
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: _center,
                        radius: _radius,
                        useRadiusInMeter: true,
                        color: AppTheme.accentColor.withOpacity(0.2),
                        borderColor: AppTheme.accentColor,
                        borderStrokeWidth: 2,
                      ),
                    ],
                  ),
                  // Vehicle GPS position marker (reference)
                  if (vehicleGps != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(
                            vehicleGps.latitude,
                            vehicleGps.longitude,
                          ),
                          child: const Icon(
                            Icons.navigation,
                            color: Colors.blue,
                            size: 30,
                          ),
                        ),
                      ],
                    ),
                  // Zone center marker (draggable via map tap)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _center,
                        child: const Icon(
                          Icons.location_pin,
                          color: Colors.red,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Map instructions
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: AppTheme.accentColor.withOpacity(0.1),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppTheme.accentColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tap anywhere on the map to set zone center',
                      style: TextStyle(
                        color: AppTheme.accentColor,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Form controls
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Use Current GPS button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.my_location),
                        label: const Text('Use Current GPS Position'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.accentColor,
                          side: BorderSide(color: AppTheme.accentColor),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: _useCurrentGpsPosition,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Coordinates display (read-only)
                    Card(
                      color: Colors.grey[900],
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Selected Coordinates',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: Colors.white70),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Latitude:',
                                  style: TextStyle(color: Colors.white70),
                                ),
                                Text(
                                  _center.latitude.toStringAsFixed(6),
                                  style: TextStyle(
                                    color: AppTheme.accentColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Longitude:',
                                  style: TextStyle(color: Colors.white70),
                                ),
                                Text(
                                  _center.longitude.toStringAsFixed(6),
                                  style: TextStyle(
                                    color: AppTheme.accentColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Zone name
                    TextFormField(
                      initialValue: _name,
                      decoration: const InputDecoration(
                        labelText: 'Zone Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value!.isEmpty ? 'Please enter a name' : null,
                      onSaved: (value) => _name = value!,
                    ),
                    const SizedBox(height: 16),

                    // Radius slider
                    Text(
                      'Radius: ${_radius >= 1000 ? '${(_radius / 1000).toStringAsFixed(1)} km' : '${_radius.toInt()} m'}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Slider(
                      value: _radius,
                      min: 50,
                      max: 5000,
                      divisions: 99,
                      activeColor: AppTheme.accentColor,
                      inactiveColor: Colors.white10,
                      label: _radius >= 1000
                          ? '${(_radius / 1000).toStringAsFixed(1)} km'
                          : '${_radius.toInt()} m',
                      onChanged: (value) {
                        setState(() {
                          _radius = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Active toggle
                    SwitchListTile(
                      title: const Text('Active'),
                      subtitle: const Text('Enable zone monitoring'),
                      value: _isActive,
                      activeColor: AppTheme.accentColor,
                      onChanged: (val) => setState(() => _isActive = val),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 24),

                    // Save button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: _saveZone,
                        child: const Text('Save Zone'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
