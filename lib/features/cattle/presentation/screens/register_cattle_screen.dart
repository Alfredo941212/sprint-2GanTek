import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../data/models/cattle.dart';
import '../../data/repositories/cattle_repository.dart';

class RegisterCattleScreen extends StatefulWidget {
  const RegisterCattleScreen({super.key});

  @override
  State<RegisterCattleScreen> createState() => _RegisterCattleScreenState();
}

class _RegisterCattleScreenState extends State<RegisterCattleScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final CattleRepository _cattleRepository = CattleRepository();

  final TextEditingController _codeController = TextEditingController();

  final TextEditingController _dateController = TextEditingController();

  final TextEditingController _weightController = TextEditingController();

  final TextEditingController _vaccinesController = TextEditingController();

  final TextEditingController _observationsController = TextEditingController();

  final TextEditingController _lotController = TextEditingController();

  final TextEditingController _corralController = TextEditingController();

  DateTime _entryDate = DateTime.now();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _updateDateText();
  }

  void _updateDateText() {
    _dateController.text = '${_entryDate.day.toString().padLeft(2, '0')}/'
        '${_entryDate.month.toString().padLeft(2, '0')}/'
        '${_entryDate.year}';
  }

  @override
  void dispose() {
    _codeController.dispose();
    _dateController.dispose();
    _weightController.dispose();
    _vaccinesController.dispose();
    _observationsController.dispose();
    _lotController.dispose();
    _corralController.dispose();

    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: _entryDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (date == null) {
      return;
    }

    setState(() {
      _entryDate = date;
      _updateDateText();
    });
  }

  Future<void> _saveCattle() async {
    if (_isSaving) {
      return;
    }

    final bool isValid = _formKey.currentState?.validate() ?? false;

    if (!isValid) {
      return;
    }

    final String code = _codeController.text.trim();

    final double? weight = double.tryParse(
      _weightController.text.trim().replaceAll(',', '.'),
    );

    if (weight == null || weight <= 0) {
      _showMessage('Ingresa un peso válido.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final bool alreadyExists = await _cattleRepository.codeExists(code);

      if (alreadyExists) {
        _showMessage(
          'Ya existe un animal con el código o arete $code.',
        );
        return;
      }

      final int? userId = SessionManager.instance.currentUserId;

      if (userId == null) {
        _showMessage(
          'No hay una sesión de usuario activa.',
        );
        return;
      }

      final Cattle cattle = Cattle(
        userId: userId,
        code: code,
        entryDate: _entryDate,
        initialWeight: weight,
        vaccines: _vaccinesController.text.trim(),
        observations: _observationsController.text.trim(),
        imagePath: null,
        lot: _lotController.text.trim(),
        corral: _corralController.text.trim(),
      );

      await _cattleRepository.insertCattle(cattle);

      if (!mounted) {
        return;
      }

      Navigator.pop(context, true);
    } on DatabaseException catch (error) {
      _showMessage(
        'No se pudo guardar el registro: ${error.toString()}',
      );
    } catch (error) {
      _showMessage(
        'Ocurrió un error inesperado: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar ganado'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            AppTextField(
              label: 'Código o número de arete',
              controller: _codeController,
              icon: Icons.tag,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Ingresa el código o número de arete';
                }

                if (value.trim().length < 2) {
                  return 'El código es demasiado corto';
                }

                return null;
              },
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Fecha de ingreso',
              controller: _dateController,
              icon: Icons.calendar_month,
              readOnly: true,
              onTap: _pickDate,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Selecciona una fecha';
                }

                return null;
              },
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Peso inicial (kg)',
              controller: _weightController,
              icon: Icons.monitor_weight_outlined,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (value) {
                final double? weight = double.tryParse(
                  (value ?? '').trim().replaceAll(',', '.'),
                );

                if (weight == null || weight <= 0) {
                  return 'Ingresa un peso válido';
                }

                if (weight > 2000) {
                  return 'El peso ingresado es demasiado alto';
                }

                return null;
              },
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Vacunas aplicadas',
              controller: _vaccinesController,
              icon: Icons.vaccines_outlined,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Indica las vacunas aplicadas';
                }

                return null;
              },
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Número de lote',
              controller: _lotController,
              icon: Icons.grid_view_outlined,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Ingresa el número de lote';
                }

                return null;
              },
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Corral asignado',
              controller: _corralController,
              icon: Icons.fence_outlined,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Ingresa el corral asignado';
                }

                return null;
              },
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Observaciones (opcional)',
              controller: _observationsController,
              icon: Icons.notes,
              maxLines: 4,
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'La cámara se agregará en el siguiente módulo.',
                    ),
                  ),
                );
              },
              icon: const Icon(
                Icons.add_a_photo_outlined,
              ),
              label: const Text(
                'Agregar foto del animal',
              ),
            ),
            const SizedBox(height: 22),
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveCattle,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(
                _isSaving ? 'Guardando...' : 'Guardar registro',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
