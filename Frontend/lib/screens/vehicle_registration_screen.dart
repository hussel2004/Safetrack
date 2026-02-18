import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../services/vehicle_service.dart';
import '../services/auth_service.dart';
import '../models/stop_mode.dart';
import '../theme.dart';

class VehicleRegistrationScreen extends StatefulWidget {
  const VehicleRegistrationScreen({super.key});

  @override
  State<VehicleRegistrationScreen> createState() =>
      _VehicleRegistrationScreenState();
}

class _VehicleRegistrationScreenState extends State<VehicleRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _plateController = TextEditingController();
  final _deveuiController = TextEditingController();

  bool _isSubmitting = false;
  StopMode _selectedStopMode = StopMode.manual; // Default to manual

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _plateController.dispose();
    _deveuiController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    if (value == null || value.isEmpty) return 'Le nom du véhicule est requis';
    return null;
  }

  String? _validateBrand(String? value) {
    if (value == null || value.isEmpty) return 'La marque est requise';
    return null;
  }

  String? _validateModel(String? value) {
    if (value == null || value.isEmpty) return 'Le modèle est requis';
    return null;
  }

  String? _validateYear(String? value) {
    if (value == null || value.isEmpty) return 'L\'année est requise';
    final year = int.tryParse(value);
    if (year == null || year < 1900 || year > DateTime.now().year + 1) {
      return 'Année invalide';
    }
    return null;
  }

  String? _validatePlate(String? value) {
    if (value == null || value.isEmpty) return 'L\'immatriculation est requise';
    return null;
  }

  String? _validateDevEUI(String? value) {
    if (value == null || value.isEmpty) return 'DevEUI est requis';
    if (value.length != 16) return 'DevEUI doit avoir 16 caractères hex';
    final validHex = RegExp(r'^[0-9a-fA-F]+$');
    if (!validHex.hasMatch(value)) return 'Format Hex invalide';
    return null;
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSubmitting = true);

      final authService = context.read<AuthService>();
      final vehicleService = context.read<VehicleService>();

      if (authService.currentUser != null) {
        final error = await vehicleService.registerVehicle(
          authService.currentUser!.id,
          _nameController.text.trim(),
          _brandController.text.trim(),
          _modelController.text.trim(),
          int.parse(_yearController.text.trim()),
          _plateController.text.trim().toUpperCase(),
          _deveuiController.text.trim().toUpperCase(),
          stopMode: _selectedStopMode,
        );

        setState(() => _isSubmitting = false);
        if (mounted) {
          if (error == null) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 12),
                    Text('Véhicule enregistré avec succès'),
                  ],
                ),
                backgroundColor: AppTheme.successColor,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(error),
                backgroundColor: AppTheme.alertColor,
              ),
            );
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enregistrer un Véhicule'),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Name
              TextFormField(
                controller: _nameController,
                validator: _validateName,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nom du véhicule',
                  hintText: 'ex: Mon Camion, Livraison 1',
                  prefixIcon: Icon(Icons.label, color: AppTheme.accentColor),
                ),
              ),
              const SizedBox(height: 16),

              // Brand
              TextFormField(
                controller: _brandController,
                validator: _validateBrand,
                decoration: const InputDecoration(
                  labelText: 'Marque',
                  hintText: 'ex: Tesla, Renault',
                  prefixIcon: Icon(
                    Icons.branding_watermark,
                    color: AppTheme.accentColor,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Model
              TextFormField(
                controller: _modelController,
                validator: _validateModel,
                decoration: const InputDecoration(
                  labelText: 'Modèle',
                  hintText: 'ex: Clio, Model 3',
                  prefixIcon: Icon(
                    Icons.directions_car_filled,
                    color: AppTheme.accentColor,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Year
              TextFormField(
                controller: _yearController,
                validator: _validateYear,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Année',
                  hintText: 'ex: 2024',
                  prefixIcon: Icon(
                    Icons.calendar_today,
                    color: AppTheme.accentColor,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // License Plate
              TextFormField(
                controller: _plateController,
                validator: _validatePlate,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Immatriculation',
                  hintText: 'ex: AA-123-BB',
                  prefixIcon: Icon(
                    Icons.credit_card,
                    color: AppTheme.accentColor,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              const Divider(color: Colors.white24),
              const SizedBox(height: 16),
              Text(
                'Configuration LoRaWAN',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),

              // DevEUI
              TextFormField(
                controller: _deveuiController,
                validator: _validateDevEUI,
                decoration: const InputDecoration(
                  labelText: 'DevEUI (16 car. Hex)',
                  hintText: 'A1B2C3D4E5F60001',
                  prefixIcon: Icon(Icons.router, color: AppTheme.accentColor),
                ),
              ),
              const SizedBox(height: 24),

              // Stop Mode Section
              const Divider(color: Colors.white24),
              const SizedBox(height: 16),
              Text(
                'Configuration du Mode d\'Arrêt',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'Choisissez comment le véhicule réagit en sortant d\'une zone',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 16),

              // Manual Stop Radio
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _selectedStopMode == StopMode.manual
                        ? AppTheme.accentColor
                        : Colors.white24,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: RadioListTile<StopMode>(
                  value: StopMode.manual,
                  groupValue: _selectedStopMode,
                  onChanged: (value) {
                    setState(() {
                      _selectedStopMode = value!;
                    });
                  },
                  title: const Row(
                    children: [
                      Icon(Icons.notifications_active, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('Arrêt Manuel'),
                    ],
                  ),
                  subtitle: const Text(
                    'Vous recevez une notification et devez appuyer sur "Stop"',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                  activeColor: AppTheme.accentColor,
                ),
              ),
              const SizedBox(height: 12),

              // Automatic Stop Radio
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _selectedStopMode == StopMode.automatic
                        ? AppTheme.accentColor
                        : Colors.white24,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: RadioListTile<StopMode>(
                  value: StopMode.automatic,
                  groupValue: _selectedStopMode,
                  onChanged: (value) {
                    setState(() {
                      _selectedStopMode = value!;
                    });
                  },
                  title: const Row(
                    children: [
                      Icon(Icons.not_started_outlined, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Arrêt Automatique'),
                    ],
                  ),
                  subtitle: const Text(
                    'Le système arrête automatiquement le véhicule',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                  activeColor: AppTheme.accentColor,
                ),
              ),
              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.add_circle),
                  label: Text(
                    _isSubmitting
                        ? 'Enregistrement...'
                        : 'Enregistrer le véhicule',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
