import numpy as np

# Waypoints from gps_test_data.txt
waypoints = [
    (3.8480, 11.5020), # Emia
    (3.8490, 11.5030),
    (3.8510, 11.5050),
    (3.8528, 11.5067),
    (3.8548, 11.5088),
    (3.8558, 11.5098),
    (3.8580, 11.5120),
    (3.8590, 11.5130),
    (3.8594, 11.5134)  # Total Melen
]

def interpolate_points(waypoints, total_points=500):
    # Calculate total distance to normalize steps
    distances = []
    total_dist = 0
    for i in range(len(waypoints) - 1):
        p1 = np.array(waypoints[i])
        p2 = np.array(waypoints[i+1])
        dist = np.linalg.norm(p2 - p1)
        distances.append(dist)
        total_dist += dist
    
    # Generate points
    all_points = []
    
    # For each segment, calculate how many points it should have based on distance
    current_point_count = 0
    
    for i in range(len(waypoints) - 1):
        segment_dist = distances[i]
        # Ratio of total points for this segment
        segment_points_count = int((segment_dist / total_dist) * total_points)
        
        # Ensure at least 1 point if distance > 0
        if segment_points_count == 0 and segment_dist > 0:
            segment_points_count = 1
            
        p1 = np.array(waypoints[i])
        p2 = np.array(waypoints[i+1])
        
        # Linear interpolation
        for j in range(segment_points_count):
            t = j / segment_points_count
            point = p1 + t * (p2 - p1)
            all_points.append(tuple(point))
            
    # Add final point
    all_points.append(waypoints[-1])
    
    return all_points

points = interpolate_points(waypoints, 500)

# Output as Dart List
print("import 'package:latlong2/latlong.dart';")
print("")
print("final List<LatLng> emiaMelenRoute = [")
for p in points:
    print(f"  LatLng({p[0]:.6f}, {p[1]:.6f}),")
print("];")
