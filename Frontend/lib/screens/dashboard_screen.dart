import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../services/vehicle_service.dart';
import '../services/auth_service.dart';
import '../services/gps_service.dart';
import '../models/vehicle.dart';
import '../theme.dart';
import '../widgets/custom_app_bar.dart';
import 'vehicle_detail_screen.dart';
import 'vehicle_registration_screen.dart';
import '../services/geofence_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final vehicleService = context.read<VehicleService>();
      final gpsService = context.read<GpsService>();
      final geofenceService = context.read<GeofenceService>();

      // Fetch vehicles and zones FIRST before starting tracking
      await vehicleService.fetchVehicles();
      await geofenceService.fetchZones();

      // Start simulation for all vehicles AFTER they are loaded
      final vehicleIds = vehicleService.vehicles.map((v) => v.gpsId).toList();
      if (vehicleIds.isNotEmpty) {
        gpsService.startTracking(vehicleIds);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final user = authService.currentUser;
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Bonjour'
        : now.hour < 18
        ? 'Bon après-midi'
        : 'Bonsoir';

    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Tableau de Bord',
        showLogout: true,
        showUserProfile: true,
      ),
      body: Consumer<VehicleService>(
        builder: (context, vehicleService, _) {
          final vehicles = vehicleService.vehicles;
          // Use GeofenceService to check for active zones as it holds the real state
          final geofenceService = Provider.of<GeofenceService>(context);
          final activeZones = vehicles
              .where((v) => geofenceService.hasActiveZone(v.id))
              .length;

          return CustomScrollView(
            slivers: [
              // Welcome Header
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(32),
                      bottomRight: Radius.circular(32),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$greeting,',
                        style: Theme.of(context).textTheme.titleMedium!
                            .copyWith(color: Colors.white60),
                      ).animate().fadeIn().slideX(begin: -0.2),
                      const SizedBox(height: 4),
                      Text(
                        user?.username ?? 'Utilisateur',
                        style: Theme.of(context).textTheme.headlineMedium!
                            .copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                      ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.2),
                      const SizedBox(height: 24),

                      // Stats Cards
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              icon: Icons.directions_car,
                              label: 'Véhicules',
                              value: vehicles.length.toString(),
                              color: AppTheme.accentColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              icon: Icons.security,
                              label: 'Zones Actives',
                              value: activeZones.toString(),
                              color: AppTheme.successColor,
                            ),
                          ),
                        ],
                      ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
                    ],
                  ),
                ),
              ),

              // Vehicle List
              if (vehicles.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.directions_car_outlined,
                            size: 64,
                            color: Colors.white24,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Aucun véhicule enregistré',
                          style: Theme.of(context).textTheme.titleLarge!
                              .copyWith(color: Colors.white70),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Ajoutez votre premier véhicule pour commencer',
                          style: Theme.of(context).textTheme.bodyMedium!
                              .copyWith(color: Colors.white38),
                        ),
                      ],
                    ).animate().fadeIn().scale(),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final vehicle = vehicles[index];
                      return _VehicleCard(vehicle: vehicle, index: index);
                    }, childCount: vehicles.length),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const VehicleRegistrationScreen(),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Ajouter Véhicule'),
        backgroundColor: AppTheme.accentColor,
      ).animate().scale(delay: 400.ms),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium!.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall!.copyWith(color: Colors.white60),
          ),
        ],
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  final Vehicle vehicle;
  final int index;

  const _VehicleCard({required this.vehicle, required this.index});

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: 'vehicle_${vehicle.id}',
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        elevation: 2,
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => VehicleDetailScreen(vehicle: vehicle),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  AppTheme.surfaceColor,
                  AppTheme.surfaceColor.withOpacity(0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.directions_car,
                    color: AppTheme.accentColor,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vehicle.model,
                        style: Theme.of(context).textTheme.titleMedium!
                            .copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.credit_card,
                            size: 14,
                            color: Colors.white54,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            vehicle.licensePlate,
                            style: Theme.of(context).textTheme.bodySmall!
                                .copyWith(color: Colors.white54),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (context.watch<GeofenceService>().hasActiveZone(vehicle.id))
                  Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.successColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.security,
                              color: AppTheme.successColor,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Protégé',
                              style: TextStyle(
                                color: AppTheme.successColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      )
                      .animate(onPlay: (c) => c.repeat())
                      .shimmer(duration: 2.seconds),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: Colors.white24),
              ],
            ),
          ),
        ),
      ).animate().slideX(duration: 400.ms, begin: 0.1 * index).fadeIn(),
    );
  }
}
