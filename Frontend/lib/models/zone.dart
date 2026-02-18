import 'dart:math';
import 'package:latlong2/latlong.dart';
import 'package:flutter/material.dart';

class Zone {
  final String id;
  final String name;
  final String description;
  final List<LatLng> polygon; // Polygon vertices
  final Color color;
  final bool isActive;
  final String? vehicleId;

  Zone({
    required this.id,
    required this.name,
    this.description = '',
    required this.polygon,
    this.color = Colors.green,
    this.isActive = true,
    this.vehicleId,
  });

  // Factory constructor to create zone from center point, radius and sides
  factory Zone.fromCenterRadius({
    required String id,
    required String name,
    String description = '',
    required LatLng center,
    required double radius, // meters
    int sides = 12, // default 12-sided polygon
    Color color = Colors.green,
    bool isActive = true,
    String? vehicleId,
  }) {
    final polygon = _generatePolygon(center, radius, sides);
    return Zone(
      id: id,
      name: name,
      description: description,
      polygon: polygon,
      color: color,
      isActive: isActive,
      vehicleId: vehicleId,
    );
  }

  // Generate regular polygon from center point
  static List<LatLng> _generatePolygon(
    LatLng center,
    double radiusMeters,
    int sides,
  ) {
    final points = <LatLng>[];
    const earthRadius = 6371000.0; // meters

    for (int i = 0; i < sides; i++) {
      final angle = (2 * pi * i) / sides;
      final dx = radiusMeters * cos(angle);
      final dy = radiusMeters * sin(angle);

      // Convert meters to degrees
      final deltaLat = dy / earthRadius * (180 / pi);
      final deltaLng =
          dx / (earthRadius * cos(center.latitude * pi / 180)) * (180 / pi);

      points.add(
        LatLng(center.latitude + deltaLat, center.longitude + deltaLng),
      );
    }
    return points;
  }

  // Check if a point is inside this polygon using ray casting algorithm
  bool containsPoint(LatLng point) {
    bool inside = false;
    for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      if ((polygon[i].latitude > point.latitude) !=
              (polygon[j].latitude > point.latitude) &&
          point.longitude <
              (polygon[j].longitude - polygon[i].longitude) *
                      (point.latitude - polygon[i].latitude) /
                      (polygon[j].latitude - polygon[i].latitude) +
                  polygon[i].longitude) {
        inside = !inside;
      }
    }
    return inside;
  }

  // Get center point of polygon (centroid)
  LatLng get center {
    double lat = 0;
    double lng = 0;
    for (final point in polygon) {
      lat += point.latitude;
      lng += point.longitude;
    }
    return LatLng(lat / polygon.length, lng / polygon.length);
  }

  Zone copyWith({
    String? name,
    String? description,
    List<LatLng>? polygon,
    Color? color,
    bool? isActive,
  }) {
    return Zone(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      polygon: polygon ?? this.polygon,
      color: color ?? this.color,
      isActive: isActive ?? this.isActive,
      vehicleId: vehicleId,
    );
  }
}
