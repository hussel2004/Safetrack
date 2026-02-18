import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/stop_mode.dart';
import '../models/vehicle.dart';
import '../services/vehicle_service.dart';
import '../theme.dart';

class VehicleEditScreen extends StatefulWidget {
  final Vehicle vehicle;

  const VehicleEditScreen({super.key, required this.vehicle});

  @override
  State<VehicleEditScreen> createState() => _VehicleEditScreenState();
}

class _VehicleEditScreenState extends State<VehicleEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _brandController;
  late TextEditingController _modelController;
  late TextEditingController _yearController;
  late TextEditingController _plateController;
  late TextEditingController _deveuiController;
  late StopMode _stopMode;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final v = widget.vehicle;
    _nameController = TextEditingController(text: v.name);
    _brandController = TextEditingController(text: v.brand);
    _modelController = TextEditingController(text: v.model);
    _yearController = TextEditingController(text: v.year.toString());
    _plateController = TextEditingController(text: v.licensePlate);
    _deveuiController = TextEditingController(text: v.deveui);
    _stopMode = v.stopMode;
  }

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

  void _save() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);

      await context.read<VehicleService>().updateVehicle(
        widget.vehicle.id,
        _nameController.text.trim(),
        _brandController.text.trim(),
        _modelController.text.trim(),
        int.parse(_yearController.text.trim()),
        _stopMode,
      );

      if (mounted) {
        setState(() => _isSaving = false);
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Véhicule mis à jour avec succès'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifier le Véhicule'),
        backgroundColor: AppTheme.primaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _isSaving ? null : _save,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                validator: _validateName,
                decoration: const InputDecoration(
                  labelText: 'Nom',
                  prefixIcon: Icon(Icons.label),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _brandController,
                decoration: const InputDecoration(
                  labelText: 'Marque',
                  prefixIcon: Icon(Icons.branding_watermark),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _modelController,
                decoration: const InputDecoration(
                  labelText: 'Modèle',
                  prefixIcon: Icon(Icons.directions_car),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _yearController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Année',
                  prefixIcon: Icon(Icons.calendar_today),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _plateController,
                decoration: const InputDecoration(
                  labelText: 'Immatriculation',
                  prefixIcon: Icon(Icons.credit_card),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _deveuiController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'DevEUI',
                  prefixIcon: Icon(Icons.router),
                  filled: true,
                ),
              ),
              const SizedBox(height: 24),

              // Stop Mode Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.accentColor.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.stop_circle_outlined,
                          color: AppTheme.accentColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Configuration du Mode d\'Arrêt',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.accentColor,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Choisissez comment le véhicule doit s\'arrêter en sortant des zones',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),

                    // Manual stop option
                    RadioListTile<StopMode>(
                      value: StopMode.manual,
                      groupValue: _stopMode,
                      onChanged: (value) {
                        setState(() {
                          _stopMode = value!;
                        });
                      },
                      title: const Text('Arrêt Manuel'),
                      subtitle: const Text(
                        'Recevoir une notification et arrêter manuellement le véhicule',
                      ),
                      secondary: const Icon(
                        Icons.notifications_active,
                        color: Colors.orange,
                      ),
                    ),

                    // Automatic stop option
                    RadioListTile<StopMode>(
                      value: StopMode.automatic,
                      groupValue: _stopMode,
                      onChanged: (value) {
                        setState(() {
                          _stopMode = value!;
                        });
                      },
                      title: const Text('Arrêt Automatique'),
                      subtitle: const Text(
                        'Le système arrête automatiquement le véhicule en sortant de zone',
                      ),
                      secondary: const Icon(
                        Icons.stop_circle,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Enregistrer les Modifications'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
