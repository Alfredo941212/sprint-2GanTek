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

import '../../../lots/data/models/lot.dart';
import '../../../lots/data/repositories/lot_repository.dart';

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

  final LotRepository _lotRepository = LotRepository();

  final ImagePicker _imagePicker = ImagePicker();

  // =========================================================
  // CONTROLADORES
  // =========================================================

  final TextEditingController _codeController = TextEditingController();

  final TextEditingController _nameController = TextEditingController();

  final TextEditingController _breedController = TextEditingController();

  final TextEditingController _birthDateController = TextEditingController();

  final TextEditingController _entryDateController = TextEditingController();

  final TextEditingController _weightController = TextEditingController();

  final TextEditingController _minimumProductionController =
      TextEditingController();

  final TextEditingController _observationsController = TextEditingController();

  // =========================================================
  // VARIABLES
  // =========================================================

  DateTime? _birthDate;

  DateTime _entryDate = DateTime.now();

  String _sex = 'Hembra';

  String _productiveStatus = 'En producción';

  String _status = 'Activo';

  String? _imagePath;

  List<Lot> _lots = [];

  int? _selectedLotId;

  bool _isLoadingLots = true;

  bool _isSaving = false;

  bool _isPickingImage = false;

  // =========================================================
  // OPCIONES
  // =========================================================

  static const List<String> _sexOptions = [
    'Hembra',
    'Macho',
  ];

  static const List<String> _productiveStatusOptions = [
    'En producción',
    'Seca',
    'Gestante',
    'No aplica',
  ];

  static const List<String> _statusOptions = [
    'Activo',
    'Vendido',
    'Fallecido',
    'Baja',
  ];

  // =========================================================
  // INICIALIZACIÓN
  // =========================================================

  @override
  void initState() {
    super.initState();

    final Cattle? cattle = widget.cattle;

    if (cattle != null) {
      _codeController.text = cattle.code;

      _nameController.text = cattle.name;

      _breedController.text = cattle.breed;

      _selectedLotId = cattle.lotId;

      _birthDate = cattle.birthDate;

      _entryDate = cattle.entryDate;

      if (cattle.initialWeight != null) {
        _weightController.text = cattle.initialWeight!.toStringAsFixed(1);
      }

      _minimumProductionController.text =
          cattle.minimumDailyProduction.toStringAsFixed(1);

      _observationsController.text = cattle.observations;

      _sex = cattle.sex;

      _productiveStatus = cattle.productiveStatus;

      _status = cattle.status;

      _imagePath = cattle.imagePath;
    } else {
      _minimumProductionController.text = '4.0';
    }

    _updateEntryDateText();

    _updateBirthDateText();

    _loadLots();
  }

  // =========================================================
  // LOTES NO CARGADOS
  // =========================================================
  Future<void> _loadLots() async {
    try {
      final List<Lot> lots = await _lotRepository.getActiveLots();

      if (!mounted) {
        return;
      }

      setState(() {
        _lots = lots;
        _isLoadingLots = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingLots = false;
      });

      _showMessage(
        'No fue posible cargar los lotes.',
      );

      debugPrint(
        'Error cargando lotes: $error',
      );
    }
  }
  // =========================================================
  // FECHA DE INGRESO
  // =========================================================

  void _updateEntryDateText() {
    _entryDateController.text = _formatDate(_entryDate);
  }

  Future<void> _pickEntryDate() async {
    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: _entryDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (selectedDate == null) {
      return;
    }

    setState(() {
      _entryDate = selectedDate;

      _updateEntryDateText();
    });
  }

  // =========================================================
  // FECHA DE NACIMIENTO
  // =========================================================

  void _updateBirthDateText() {
    final DateTime? date = _birthDate;

    if (date == null) {
      _birthDateController.clear();
      return;
    }

    _birthDateController.text = _formatDate(date);
  }

  Future<void> _pickBirthDate() async {
    final DateTime initialDate = _birthDate ??
        DateTime.now().subtract(
          const Duration(
            days: 365,
          ),
        );

    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
    );

    if (selectedDate == null) {
      return;
    }

    setState(() {
      _birthDate = selectedDate;

      _updateBirthDateText();
    });
  }

  String _formatDate(
    DateTime date,
  ) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  // =========================================================
  // FOTOGRAFÍA
  // =========================================================

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
                title: const Text(
                  'Tomar fotografía',
                ),
                onTap: () {
                  Navigator.pop(
                    sheetContext,
                  );

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
                  Navigator.pop(
                    sheetContext,
                  );

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
                    Navigator.pop(
                      sheetContext,
                    );

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
        : path.extension(
            image.path,
          );

    final String fileName =
        'cattle_${DateTime.now().millisecondsSinceEpoch}$extension';

    final String destinationPath = path.join(
      cattleImagesDirectory.path,
      fileName,
    );

    final File sourceFile = File(image.path);

    final File savedFile = await sourceFile.copy(
      destinationPath,
    );

    return savedFile.path;
  }

  // =========================================================
  // GUARDAR GANADO
  // =========================================================

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

    final String name = _nameController.text.trim();

    final String breed = _breedController.text.trim();

    // Peso opcional.
    double? weight;

    final String weightText =
        _weightController.text.trim().replaceAll(',', '.');

    if (weightText.isNotEmpty) {
      weight = double.tryParse(weightText);

      if (weight == null || weight <= 0) {
        _showMessage(
          'Ingresa un peso válido.',
        );

        return;
      }
    }

    final double? minimumProduction = double.tryParse(
      _minimumProductionController.text.trim().replaceAll(',', '.'),
    );

    if (minimumProduction == null || minimumProduction < 0) {
      _showMessage(
        'Ingresa una producción mínima válida.',
      );

      return;
    }

    if (_birthDate != null &&
        _birthDate!.isAfter(
          _entryDate,
        )) {
      _showMessage(
        'La fecha de nacimiento no puede ser posterior a la fecha de ingreso.',
      );

      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final Cattle? originalCattle = widget.cattle;

      final bool alreadyExists = await _repository.codeExists(
        code,
        excludeCattleId: originalCattle?.id,
      );

      if (alreadyExists) {
        _showMessage(
          'Ya existe un animal con el arete $code.',
        );

        return;
      }

      final Cattle cattle = Cattle(
        id: originalCattle?.id,
        userId: userId,
        lotId: _selectedLotId,
        code: code,
        name: name,
        sex: _sex,
        breed: breed,
        birthDate: _birthDate,
        entryDate: _entryDate,
        initialWeight: weight,
        productiveStatus: _productiveStatus,
        minimumDailyProduction: minimumProduction,
        status: _status,
        observations: _observationsController.text.trim(),
        imagePath: _imagePath,
      );

      if (widget.isEditing) {
        await _repository.updateCattle(
          cattle,
        );
      } else {
        await _repository.insertCattle(
          cattle,
        );
      }

      if (!mounted) {
        return;
      }

      Navigator.pop(
        context,
        true,
      );
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

  // =========================================================
  // MENSAJE
  // =========================================================

  void _showMessage(
    String message,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
          ),
        ),
      );
  }

  // =========================================================
  // DISPOSE
  // =========================================================

  @override
  void dispose() {
    _codeController.dispose();

    _nameController.dispose();

    _breedController.dispose();

    _birthDateController.dispose();

    _entryDateController.dispose();

    _weightController.dispose();

    _minimumProductionController.dispose();

    _observationsController.dispose();

    super.dispose();
  }

  // =========================================================
  // INTERFAZ
  // =========================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditing ? 'Actualizar ganado' : 'Registrar ganado',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(
            18,
          ),
          children: [
            // =================================================
            // FOTO
            // =================================================

            if (_imagePath != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(
                  16,
                ),
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
              const SizedBox(
                height: 18,
              ),
            ],

            // =================================================
            // IDENTIFICACIÓN
            // =================================================

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

            const SizedBox(
              height: 14,
            ),

            AppTextField(
              label: 'Nombre del animal (opcional)',
              controller: _nameController,
              icon: Icons.pets_outlined,
            ),

            const SizedBox(
              height: 14,
            ),

            AppTextField(
              label: 'Raza (opcional)',
              controller: _breedController,
              icon: Icons.category_outlined,
            ),

            const SizedBox(
              height: 14,
            ),
// =================================================
// LOTE
// =================================================

            DropdownButtonFormField<int>(
              initialValue: _selectedLotId,
              decoration: InputDecoration(
                labelText: 'Lote',
                prefixIcon: const Icon(
                  Icons.grid_view_outlined,
                ),
                border: const OutlineInputBorder(),
                helperText: _isLoadingLots
                    ? 'Cargando lotes...'
                    : _lots.isEmpty
                        ? 'No hay lotes activos registrados'
                        : 'Selecciona el lote al que pertenece el animal',
              ),
              items: _lots
                  .where(
                (Lot lot) => lot.id != null,
              )
                  .map(
                (Lot lot) {
                  return DropdownMenuItem<int>(
                    value: lot.id!,
                    child: Text(
                      lot.name,
                    ),
                  );
                },
              ).toList(),
              onChanged: _isLoadingLots || _lots.isEmpty
                  ? null
                  : (int? value) {
                      setState(() {
                        _selectedLotId = value;
                      });
                    },
              validator: (int? value) {
                if (_isLoadingLots) {
                  return 'Espera a que carguen los lotes';
                }

                if (_lots.isEmpty) {
                  return 'Primero registra un lote';
                }

                if (value == null) {
                  return 'Selecciona un lote';
                }

                return null;
              },
            ),

            const SizedBox(
              height: 14,
            ),

            // =================================================
            // SEXO
            // =================================================

            DropdownButtonFormField<String>(
              initialValue: _sex,
              decoration: const InputDecoration(
                labelText: 'Sexo',
                prefixIcon: Icon(
                  Icons.female_outlined,
                ),
                border: OutlineInputBorder(),
              ),
              items: _sexOptions
                  .map(
                    (
                      String value,
                    ) =>
                        DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    ),
                  )
                  .toList(),
              onChanged: (String? value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  _sex = value;

                  if (_sex == 'Macho') {
                    _productiveStatus = 'No aplica';
                  }
                });
              },
            ),

            const SizedBox(
              height: 14,
            ),

            // =================================================
            // NACIMIENTO
            // =================================================

            AppTextField(
              label: 'Fecha de nacimiento (opcional)',
              controller: _birthDateController,
              icon: Icons.cake_outlined,
              readOnly: true,
              onTap: _pickBirthDate,
            ),

            const SizedBox(
              height: 14,
            ),

            // =================================================
            // FECHA DE INGRESO
            // =================================================

            AppTextField(
              label: 'Fecha de ingreso',
              controller: _entryDateController,
              icon: Icons.calendar_month,
              readOnly: true,
              onTap: _pickEntryDate,
            ),

            const SizedBox(
              height: 14,
            ),

            // =================================================
            // PESO
            // =================================================

            AppTextField(
              label: 'Peso inicial (kg) - opcional',
              controller: _weightController,
              icon: Icons.monitor_weight_outlined,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (value) {
                final String text = value?.trim() ?? '';

                if (text.isEmpty) {
                  return null;
                }

                final double? weight = double.tryParse(
                  text.replaceAll(
                    ',',
                    '.',
                  ),
                );

                if (weight == null || weight <= 0) {
                  return 'Ingresa un peso válido';
                }

                return null;
              },
            ),

            const SizedBox(
              height: 14,
            ),

            // =================================================
            // ESTADO PRODUCTIVO
            // =================================================

            DropdownButtonFormField<String>(
              initialValue: _productiveStatus,
              decoration: const InputDecoration(
                labelText: 'Estado productivo',
                prefixIcon: Icon(
                  Icons.water_drop_outlined,
                ),
                border: OutlineInputBorder(),
              ),
              items: _productiveStatusOptions
                  .map(
                    (
                      String value,
                    ) =>
                        DropdownMenuItem<String>(
                      value: value,
                      child: Text(
                        value,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: _sex == 'Macho'
                  ? null
                  : (String? value) {
                      if (value == null) {
                        return;
                      }

                      setState(
                        () {
                          _productiveStatus = value;
                        },
                      );
                    },
            ),

            const SizedBox(
              height: 14,
            ),

            // =================================================
            // PRODUCCIÓN MÍNIMA
            // =================================================

            AppTextField(
              label: 'Producción mínima diaria (L)',
              controller: _minimumProductionController,
              icon: Icons.water_drop,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (value) {
                final double? production = double.tryParse(
                  (value ?? '').trim().replaceAll(
                        ',',
                        '.',
                      ),
                );

                if (production == null || production < 0) {
                  return 'Ingresa una producción válida';
                }

                return null;
              },
            ),

            const SizedBox(
              height: 14,
            ),

            // =================================================
            // ESTADO GENERAL
            // =================================================

            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(
                labelText: 'Estado del animal',
                prefixIcon: Icon(
                  Icons.check_circle_outline,
                ),
                border: OutlineInputBorder(),
              ),
              items: _statusOptions
                  .map(
                    (
                      String value,
                    ) =>
                        DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    ),
                  )
                  .toList(),
              onChanged: (String? value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  _status = value;
                });
              },
            ),

            const SizedBox(
              height: 14,
            ),

            // =================================================
            // OBSERVACIONES
            // =================================================

            AppTextField(
              label: 'Observaciones (opcional)',
              controller: _observationsController,
              icon: Icons.notes_outlined,
              maxLines: 4,
            ),

            const SizedBox(
              height: 18,
            ),

            // =================================================
            // FOTOGRAFÍA
            // =================================================

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

            const SizedBox(
              height: 22,
            ),

            // =================================================
            // GUARDAR
            // =================================================

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

            const SizedBox(
              height: 20,
            ),
          ],
        ),
      ),
    );
  }
}
