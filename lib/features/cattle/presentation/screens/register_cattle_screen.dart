import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/session/session_manager.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../data/models/cattle.dart';
import '../../data/repositories/cattle_repository.dart';

class RegisterCattleScreen extends StatefulWidget {
  const RegisterCattleScreen({
    super.key,
    this.cattle,
  });

  final Cattle? cattle;

  bool get isEditing => cattle != null;

  @override
  State<RegisterCattleScreen> createState() => _RegisterCattleScreenState();
}

class _RegisterCattleScreenState extends State<RegisterCattleScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final CattleRepository _repository = CattleRepository();

  final ImagePicker _imagePicker = ImagePicker();

  final TextEditingController _codeController = TextEditingController();

  final TextEditingController _dateController = TextEditingController();

  final TextEditingController _weightController = TextEditingController();

  final TextEditingController _vaccinesController = TextEditingController();

  final TextEditingController _observationsController = TextEditingController();

  final TextEditingController _lotController = TextEditingController();

  final TextEditingController _corralController = TextEditingController();

  DateTime _entryDate = DateTime.now();
  String? _imagePath;

  bool _isSaving = false;
  bool _isPickingImage = false;

  @override
  void initState() {
    super.initState();

    final Cattle? cattle = widget.cattle;

    if (cattle != null) {
      _codeController.text = cattle.code;
      _entryDate = cattle.entryDate;
      _weightController.text = cattle.initialWeight.toStringAsFixed(1);
      _vaccinesController.text = cattle.vaccines;
      _observationsController.text = cattle.observations;
      _lotController.text = cattle.lot;
      _corralController.text = cattle.corral;
      _imagePath = cattle.imagePath;
    }

    _updateDateText();
  }

  void _updateDateText() {
    _dateController.text = '${_entryDate.day.toString().padLeft(2, '0')}/'
        '${_entryDate.month.toString().padLeft(2, '0')}/'
        '${_entryDate.year}';
  }

  Future<void> _pickDate() async {
    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: _entryDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (selectedDate == null) {
      return;
    }

    setState(() {
      _entryDate = selectedDate;
      _updateDateText();
    });
  }

  Future<void> _showImageSourceOptions() async {
    if (_isPickingImage) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(
                  Icons.photo_camera_outlined,
                ),
                title: const Text('Tomar fotografía'),
                onTap: () {
                  Navigator.pop(sheetContext);

                  _selectImage(
                    ImageSource.camera,
                  );
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_outlined,
                ),
                title: const Text(
                  'Seleccionar de la galería',
                ),
                onTap: () {
                  Navigator.pop(sheetContext);

                  _selectImage(
                    ImageSource.gallery,
                  );
                },
              ),
              if (_imagePath != null)
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline,
                  ),
                  title: const Text(
                    'Quitar fotografía',
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);

                    setState(() {
                      _imagePath = null;
                    });
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _selectImage(
    ImageSource source,
  ) async {
    setState(() {
      _isPickingImage = true;
    });

    try {
      final XFile? selectedImage = await _imagePicker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1600,
      );

      if (selectedImage == null) {
        return;
      }

      final String permanentPath = await _saveImagePermanently(
        selectedImage,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _imagePath = permanentPath;
      });
    } catch (error) {
      _showMessage(
        'No fue posible obtener la fotografía.',
      );

      debugPrint(
        'Error seleccionando fotografía: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPickingImage = false;
        });
      }
    }
  }

  Future<String> _saveImagePermanently(
    XFile image,
  ) async {
    final Directory documentsDirectory =
        await getApplicationDocumentsDirectory();

    final Directory cattleImagesDirectory = Directory(
      path.join(
        documentsDirectory.path,
        'cattle_images',
      ),
    );

    if (!await cattleImagesDirectory.exists()) {
      await cattleImagesDirectory.create(
        recursive: true,
      );
    }

    final String extension = path.extension(image.path).isEmpty
        ? '.jpg'
        : path.extension(image.path);

    final String fileName =
        'cattle_${DateTime.now().millisecondsSinceEpoch}$extension';

    final String destinationPath = path.join(
      cattleImagesDirectory.path,
      fileName,
    );

    final File sourceFile = File(image.path);

    final File savedFile = await sourceFile.copy(destinationPath);

    return savedFile.path;
  }

  Future<void> _saveCattle() async {
    if (_isSaving) {
      return;
    }

    final bool isValid = _formKey.currentState?.validate() ?? false;

    if (!isValid) {
      return;
    }

    final int? userId = SessionManager.instance.currentUserId;

    if (userId == null) {
      _showMessage(
        'No hay una sesión activa.',
      );
      return;
    }

    final String code = _codeController.text.trim();

    final double? weight = double.tryParse(
      _weightController.text.trim().replaceAll(',', '.'),
    );

    if (weight == null || weight <= 0) {
      _showMessage(
        'Ingresa un peso válido.',
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final Cattle? originalCattle = widget.cattle;

      if (originalCattle == null || originalCattle.code != code) {
        final bool alreadyExists = await _repository.codeExists(code);

        if (alreadyExists) {
          _showMessage(
            'Ya existe un animal con el arete $code.',
          );
          return;
        }
      }

      final Cattle cattle = Cattle(
        id: originalCattle?.id,
        userId: userId,
        code: code,
        entryDate: _entryDate,
        initialWeight: weight,
        vaccines: _vaccinesController.text.trim(),
        observations: _observationsController.text.trim(),
        imagePath: _imagePath,
        lot: _lotController.text.trim(),
        corral: _corralController.text.trim(),
      );

      if (widget.isEditing) {
        await _repository.updateCattle(cattle);
      } else {
        await _repository.insertCattle(cattle);
      }

      if (!mounted) {
        return;
      }

      Navigator.pop(context, true);
    } on DatabaseException catch (error) {
      _showMessage(
        widget.isEditing
            ? 'No se pudo actualizar el registro.'
            : 'No se pudo guardar el registro.',
      );

      debugPrint(
        'Error SQLite ganado: $error',
      );
    } catch (error) {
      _showMessage(
        'Ocurrió un error inesperado.',
      );

      debugPrint(
        'Error guardando ganado: $error',
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

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditing ? 'Actualizar ganado' : 'Registrar ganado',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            if (_imagePath != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  File(_imagePath!),
                  height: 210,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (
                    BuildContext context,
                    Object error,
                    StackTrace? stackTrace,
                  ) {
                    return Container(
                      height: 210,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.broken_image_outlined,
                        size: 56,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),
            ],
            AppTextField(
              label: 'Código o número de arete',
              controller: _codeController,
              icon: Icons.tag,
              validator: (value) {
                final String code = value?.trim() ?? '';

                if (code.isEmpty) {
                  return 'Ingresa el código o arete';
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
                  (value ?? '').replaceAll(',', '.'),
                );

                if (weight == null || weight <= 0) {
                  return 'Ingresa un peso válido';
                }

                return null;
              },
            ),
            /*  const SizedBox(height: 14),
            AppTextField(
              label: 'Vacunas aplicadas',
              controller: _vaccinesController,
              icon: Icons.vaccines_outlined,
            ),*/
            const SizedBox(height: 14),
            AppTextField(
              label: 'Número de lote',
              controller: _lotController,
              icon: Icons.grid_view_outlined,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Ingresa el lote';
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
                  return 'Ingresa el corral';
                }

                return null;
              },
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Observaciones (opcional)',
              controller: _observationsController,
              icon: Icons.notes_outlined,
              maxLines: 4,
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: _isPickingImage ? null : _showImageSourceOptions,
              icon: _isPickingImage
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : Icon(
                      _imagePath == null
                          ? Icons.add_a_photo_outlined
                          : Icons.edit_outlined,
                    ),
              label: Text(
                _imagePath == null
                    ? 'Agregar foto del animal'
                    : 'Cambiar fotografía',
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
                  : Icon(
                      widget.isEditing ? Icons.update : Icons.save_outlined,
                    ),
              label: Text(
                _isSaving
                    ? 'Guardando...'
                    : widget.isEditing
                        ? 'Actualizar registro'
                        : 'Guardar registro',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
