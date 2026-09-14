import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/lot.dart';
import '../../data/repositories/lot_repository.dart';

class RegisterLotScreen extends StatefulWidget {
  const RegisterLotScreen({
    super.key,
    this.lot,
  });

  final Lot? lot;

  @override
  State<RegisterLotScreen> createState() => _RegisterLotScreenState();
}

class _RegisterLotScreenState extends State<RegisterLotScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final LotRepository _lotRepository = LotRepository();

  final TextEditingController _nameController = TextEditingController();

  final TextEditingController _descriptionController = TextEditingController();

  final TextEditingController _minimumProductionController =
      TextEditingController();

  bool _isSaving = false;

  String _status = 'Activo';

  bool get _isEditing => widget.lot != null;

  @override
  void initState() {
    super.initState();

    final Lot? lot = widget.lot;

    if (lot != null) {
      _nameController.text = lot.name;

      _descriptionController.text = lot.description ?? '';

      _minimumProductionController.text =
          lot.minimumProductionPerCow.toStringAsFixed(1);

      _status = lot.status;
    } else {
      _minimumProductionController.text = '4.0';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _minimumProductionController.dispose();

    super.dispose();
  }

  // =========================================================
  // GUARDAR
  // =========================================================

  Future<void> _saveLot() async {
    if (_isSaving) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isSaving = true;
    });

    try {
      final double minimumProduction = double.parse(
        _minimumProductionController.text.trim().replaceAll(',', '.'),
      );

      if (_isEditing) {
        final Lot currentLot = widget.lot!;

        final Lot updatedLot = currentLot.copyWith(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          minimumProductionPerCow: minimumProduction,
          status: _status,
        );

        await _lotRepository.updateLot(
          updatedLot,
        );
      } else {
        final Lot newLot = Lot(
          userId: 0,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          minimumProductionPerCow: minimumProduction,
          status: _status,
        );

        await _lotRepository.insertLot(
          newLot,
        );
      }

      if (!mounted) {
        return;
      }

      Navigator.pop(
        context,
        true,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      String message = error.toString();

      if (message.startsWith('Exception: ')) {
        message = message.substring(11);
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Editar lote' : 'Registrar lote',
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // =================================================
              // ENCABEZADO
              // =================================================

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.grid_view_outlined,
                      size: 34,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Información del lote',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // =================================================
              // NOMBRE
              // =================================================

              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                maxLength: 50,
                decoration: const InputDecoration(
                  labelText: 'Nombre del lote',
                  hintText: 'Ej. Lote Norte',
                  prefixIcon: Icon(
                    Icons.grid_view_outlined,
                  ),
                  border: OutlineInputBorder(),
                ),
                validator: (String? value) {
                  final String name = value?.trim() ?? '';

                  if (name.isEmpty) {
                    return 'Ingresa el nombre del lote.';
                  }

                  if (name.length < 3) {
                    return 'El nombre debe tener al menos 3 caracteres.';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              // =================================================
              // PRODUCCIÓN MÍNIMA
              // =================================================

              TextFormField(
                controller: _minimumProductionController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Producción mínima por vaca',
                  hintText: '4.0',
                  suffixText: 'L/día',
                  prefixIcon: Icon(
                    Icons.water_drop_outlined,
                  ),
                  border: OutlineInputBorder(),
                  helperText: 'Se utilizará para detectar baja producción.',
                ),
                validator: (String? value) {
                  final String text = value?.trim() ?? '';

                  if (text.isEmpty) {
                    return 'Ingresa la producción mínima.';
                  }

                  final double? production = double.tryParse(
                    text.replaceAll(',', '.'),
                  );

                  if (production == null) {
                    return 'Ingresa una cantidad válida.';
                  }

                  if (production <= 0) {
                    return 'La producción debe ser mayor a 0.';
                  }

                  if (production > 100) {
                    return 'Verifica la cantidad ingresada.';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              // =================================================
              // ESTADO
              // =================================================

              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(
                  labelText: 'Estado',
                  prefixIcon: Icon(
                    Icons.toggle_on_outlined,
                  ),
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Activo',
                    child: Text('Activo'),
                  ),
                  DropdownMenuItem(
                    value: 'Inactivo',
                    child: Text('Inactivo'),
                  ),
                ],
                onChanged: (String? value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    _status = value;
                  });
                },
              ),

              const SizedBox(height: 16),

              // =================================================
              // DESCRIPCIÓN
              // =================================================

              TextFormField(
                controller: _descriptionController,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 4,
                maxLength: 250,
                decoration: const InputDecoration(
                  labelText: 'Descripción (opcional)',
                  hintText: 'Ej. Vacas en producción del sector norte',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(
                    Icons.notes_outlined,
                  ),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 26),

              // =================================================
              // BOTÓN
              // =================================================

              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _saveLot,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(
                          _isEditing ? Icons.save_outlined : Icons.add,
                        ),
                  label: Text(
                    _isSaving
                        ? 'Guardando...'
                        : _isEditing
                            ? 'Guardar cambios'
                            : 'Registrar lote',
                  ),
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                'La producción mínima podrá utilizarse posteriormente para generar alertas cuando las vacas del lote estén por debajo del nivel esperado.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
