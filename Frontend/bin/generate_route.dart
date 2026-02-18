import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

void main() async {
  // Total Melen -> Pharmacie Emia (REVERSED)
  final startLat = 3.8594;
  final startLng = 11.5134;
  final endLat = 3.8480;
  final endLng = 11.5020;

  final url =
      'http://router.project-osrm.org/route/v1/driving/$startLng,$startLat;$endLng,$endLat?overview=full&geometries=geojson';

  print('Fetching route from OSRM...');
  final request = await HttpClient().getUrl(Uri.parse(url));
  final response = await request.close();

  if (response.statusCode != 200) {
    print('Error fetching route: ${response.statusCode}');
    exit(1);
  }

  final responseBody = await response.transform(utf8.decoder).join();
  final data = jsonDecode(responseBody);

  if (data['routes'] == null || (data['routes'] as List).isEmpty) {
    print('No route found');
    exit(1);
  }

  final geometry = data['routes'][0]['geometry'];
  final coordinates = geometry['coordinates'] as List;

  // Convert [lng, lat] to [lat, lng]
  final List<List<double>> waypoints = coordinates.map((c) {
    final point = c as List;
    return [point[1] as double, point[0] as double];
  }).toList();

  print('Route fetched with ${waypoints.length} waypoints.');

  // Interpolate to 500 points
  final interpolatedPoints = interpolatePoints(waypoints, 500);

  print('Interpolated to ${interpolatedPoints.length} points.');

  // Generate Dart file
  final buffer = StringBuffer();
  buffer.writeln("import 'package:latlong2/latlong.dart';");
  buffer.writeln("");
  buffer.writeln("// Route: Total Melen -> Pharmacie Emia");
  buffer.writeln("// Generated from OSRM");
  buffer.writeln("final List<LatLng> emiaMelenRoute = [");

  for (final point in interpolatedPoints) {
    buffer.writeln("  LatLng(${point[0]}, ${point[1]}),");
  }

  buffer.writeln("];");

  final file = File('lib/utils/simulation_data.dart');
  await file.writeAsString(buffer.toString());

  print('File generated at lib/utils/simulation_data.dart');
}

List<List<double>> interpolatePoints(
  List<List<double>> waypoints,
  int totalPoints,
) {
  final distances = <double>[];
  double totalDist = 0;

  for (int i = 0; i < waypoints.length - 1; i++) {
    final d = distance(waypoints[i], waypoints[i + 1]);
    distances.add(d);
    totalDist += d;
  }

  final allPoints = <List<double>>[];

  for (int i = 0; i < waypoints.length - 1; i++) {
    final segmentDist = distances[i];
    int segmentCount = ((segmentDist / totalDist) * totalPoints).round();

    if (segmentCount < 1) segmentCount = 1;

    final p1 = waypoints[i];
    final p2 = waypoints[i + 1];

    for (int j = 0; j < segmentCount; j++) {
      final t = j / segmentCount;
      final lat = p1[0] + t * (p2[0] - p1[0]);
      final lng = p1[1] + t * (p2[1] - p1[1]);
      allPoints.add([lat, lng]);
    }
  }

  // Add last point
  allPoints.add(waypoints.last);

  return allPoints;
}

double distance(List<double> p1, List<double> p2) {
  return math.sqrt(math.pow(p2[0] - p1[0], 2) + math.pow(p2[1] - p1[1], 2));
}
