import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme.dart';
import 'services/auth_service.dart';
import 'services/vehicle_service.dart';
import 'services/gps_service.dart';
import 'services/command_service.dart';
import 'services/geofence_service.dart';
import 'services/notification_service.dart';
import 'services/alert_service.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().init();
  runApp(const SafeTrackApp());
}

class SafeTrackApp extends StatelessWidget {
  const SafeTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProxyProvider<AuthService, VehicleService>(
          create: (context) => VehicleService(context.read<AuthService>()),
          update: (context, auth, previous) => VehicleService(auth),
        ),
        ChangeNotifierProxyProvider<AuthService, GpsService>(
          create: (context) => GpsService(context.read<AuthService>()),
          update: (_, auth, previous) => GpsService(auth),
        ),
        ChangeNotifierProvider(create: (_) => CommandService()),
        ChangeNotifierProxyProvider2<AuthService, GpsService, GeofenceService>(
          create: (context) => GeofenceService(context.read<AuthService>()),
          update: (_, auth, gps, previous) =>
              (previous ?? GeofenceService(auth))..updateGpsService(gps),
        ),
        ChangeNotifierProxyProvider<AuthService, AlertService>(
          create: (context) => AlertService(context.read<AuthService>()),
          update: (_, auth, previous) {
            final service = previous ?? AlertService(auth);
            if (auth.isAuthenticated) {
              service.startPolling();
            } else {
              service.stopPolling();
            }
            return service;
          },
          lazy: false,
        ),
      ],
      child: MaterialApp(
        title: 'SafeTrack',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const LoginScreen(),
      ),
    );
  }
}
