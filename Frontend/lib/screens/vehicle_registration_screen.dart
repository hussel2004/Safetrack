import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../services/vehicle_service.dart';
import '../theme.dart';

class VehicleRegistrationScreen extends StatefulWidget {
  const VehicleRegistrationScreen({super.key});

  @override
  State<VehicleRegistrationScreen> createState() =>
      _VehicleRegistrationScreenState();
}

class _VehicleRegistrationScreenState extends State<VehicleRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _deveuiController = TextEditingController();
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _plateController = TextEditingController();

  bool _isSubmitting = false;

  @override
  void dispose() {
    _deveuiController.dispose();
    _nameController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _plateController.dispose();
    super.dispose();
  }

  String? _validateDevEUI(String? value) {
    if (value == null || value.isEmpty) return 'DevEUI requis';
    final clean = value.trim();
    if (clean.length != 16)
      return 'DevEUI doit avoir exactement 16 caractères hex';
    if (!RegExp(r'^[0-9a-fA-F]+$').hasMatch(clean)) {
      return 'Format invalide (caractères hex uniquement : 0-9, A-F)';
    }
    return null;
  }

  String? _validateName(String? value) {
    if (value == null || value.isEmpty) return 'Le nom du véhicule est requis';
    return null;
  }

  String? _validateYear(String? value) {
    if (value == null || value.isEmpty) return null; // optionnel
    final year = int.tryParse(value);
    if (year == null || year < 1900 || year > DateTime.now().year + 1) {
      return 'Année invalide';
    }
    return null;
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final vehicleService = context.read<VehicleService>();

    final error = await vehicleService.pairVehicle(
      deveui: _deveuiController.text.trim(),
      nom: _nameController.text.trim(),
      marque: _brandController.text.trim(),
      modele: _modelController.text.trim(),
      annee: _yearController.text.trim().isNotEmpty
          ? int.tryParse(_yearController.text.trim())
          : null,
      immatriculation: _plateController.text.trim().isNotEmpty
          ? _plateController.text.trim().toUpperCase()
          : null,
    );

    setState(() => _isSubmitting = false);
    if (!mounted) return;

    if (error == null) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text('Véhicule appairé avec succès ! 🎉')),
            ],
          ),
          backgroundColor: AppTheme.successColor,
          duration: Duration(seconds: 3),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(error)),
            ],
          ),
          backgroundColor: AppTheme.alertColor,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Appairer un Véhicule'),
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
              // Header info banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.accentColor.withAlpha(25),
                  border: Border.all(color: AppTheme.accentColor.withAlpha(80)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppTheme.accentColor,
                      size: 20,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Entrez le DevEUI inscrit sur votre boîtier GPS pour l\'associer à votre compte.',
                        style: TextStyle(
                          color: AppTheme.accentColor,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms),
              const SizedBox(height: 28),

              // ── DevEUI (champ principal) ──
              Text(
                'Identifiant du boîtier',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: AppTheme.accentColor),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _deveuiController,
                      validator: _validateDevEUI,
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 16,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        letterSpacing: 2,
                        fontSize: 17,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'DevEUI (16 caractères Hex)',
                        hintText: 'A1B2C3D4E5F60001',
                        prefixIcon: Icon(
                          Icons.router,
                          color: AppTheme.accentColor,
                        ),
                        counterText: '',
                      ),
                      onChanged: (v) {
                        final upper = v.toUpperCase();
                        if (upper != v) {
                          _deveuiController.value = _deveuiController.value
                              .copyWith(
                                text: upper,
                                selection: TextSelection.collapsed(
                                  offset: upper.length,
                                ),
                              );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: SizedBox(
                      height: 56,
                      width: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: AppTheme.surfaceColor,
                              title: const Text('Scanner QR Code'),
                              content: const Text(
                                'La fonction de scan QR Code sera disponible en V2 après la phase de fabrication industrielle des boîtiers.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('D\'accord'),
                                ),
                              ],
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          backgroundColor: AppTheme.surfaceColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(
                              color: AppTheme.accentColor,
                              width: 1,
                            ),
                          ),
                        ),
                        child: const Icon(
                          Icons.qr_code_scanner,
                          color: AppTheme.accentColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ).animate().slideX(begin: -0.05, duration: 350.ms),
              const SizedBox(height: 28),

              const Divider(color: Colors.white24),
              const SizedBox(height: 20),

              // ── Informations du véhicule ──
              Text(
                'Informations du véhicule',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),

              // Nom
              TextFormField(
                controller: _nameController,
                validator: _validateName,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nom du véhicule *',
                  hintText: 'ex: Toyota Hilux, Camion 3',
                  prefixIcon: Icon(Icons.label, color: AppTheme.accentColor),
                ),
              ),
              const SizedBox(height: 16),

              // Marque & Modèle
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _brandController,
                      decoration: const InputDecoration(
                        labelText: 'Marque',
                        hintText: 'Toyota',
                        prefixIcon: Icon(
                          Icons.branding_watermark,
                          color: AppTheme.accentColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _modelController,
                      decoration: const InputDecoration(
                        labelText: 'Modèle',
                        hintText: 'Hilux',
                        prefixIcon: Icon(
                          Icons.directions_car_filled,
                          color: AppTheme.accentColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Année & Immatriculation
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: _yearController,
                      validator: _validateYear,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      decoration: const InputDecoration(
                        labelText: 'Année',
                        hintText: '2024',
                        counterText: '',
                        prefixIcon: Icon(
                          Icons.calendar_today,
                          color: AppTheme.accentColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _plateController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Immatriculation',
                        hintText: 'AA-123-BB',
                        prefixIcon: Icon(
                          Icons.credit_card,
                          color: AppTheme.accentColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 36),

              // ── Submit ──
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
                      : const Icon(Icons.link),
                  label: Text(
                    _isSubmitting
                        ? 'Appairage en cours…'
                        : 'Appairer le véhicule',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentColor,
                  ),
                ),
              ).animate().scale(
                begin: const Offset(0.97, 0.97),
                duration: 300.ms,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
