# SafeTrack Application

SafeTrack is a Flutter-based IoT vehicle tracking application.

## Prerequisites
- **Flutter SDK**: You must install the Flutter SDK to run this project.
  - [Install Flutter](https://docs.flutter.dev/get-started/install/windows)
- **Dart SDK**: Included with Flutter.

## Setup Instructions

1. **Install Flutter**: Follow the link above if you haven't already.
2. **Open Terminal**: Navigate to this directory (`Frontend`).
3. **Install Dependencies**:
   ```bash
   flutter pub get
   ```
4. **Run the App**:
   ```bash
   flutter run
   ```

## Key Features (Mocked)
- **User Authentication**: Login/Register (Any email/password works).
- **Vehicle Registration**: Add mock vehicles.
- **Real-time GPS**: Visualized on OpenStreetMap (OSM is free, no API key needed).
- **Geofencing**: Set a "Safe Zone" radius. App alerts if vehicle leaves the zone.
- **Remote Stop**: "STOP VEHICLE" button simulates sending a command to an IoT device.

## Architecture
- **State Management**: `provider` pattern.
- **Services**: Mock services in `lib/services` simulate backend behavior.
- **UI**: Modern Dark Theme with `flutter_animate`.
