import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../cattle/data/models/cattle.dart';
import '../../../cattle/data/repositories/cattle_repository.dart';
import '../../data/models/vaccine_record.dart';
import '../../data/repositories/vaccine_repository.dart';

import '../../../veterinarians/data/models/veterinarian.dart';
import '../../../veterinarians/data/repositories/veterinarian_repository.dart';
import '../../data/models/vaccine.dart';
import '../../data/repositories/vaccine_catalog_repository.dart';

class RegisterVaccineScreen extends StatefulWidget {
  const RegisterVaccineScreen({
    super.key,
    this.vaccine,
  });

  final VaccineRecord? vaccine;

  bool get isEditing => vaccine != null;

  @override
  State<RegisterVaccineScreen> createState() => _RegisterVaccineScreenState();
}

class _RegisterVaccineScreenState extends State<RegisterVaccineScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final CattleRepository _cattleRepository = CattleRepository();

  final VaccineRepository _vaccineRepository = VaccineRepository();

  final VaccineCatalogRepository _vaccineCatalogRepository =
      VaccineCatalogRepository();

  final VeterinarianRepository _veterinarianRepository =
      VeterinarianRepository();

  //final TextEditingController _vaccineController = TextEditingController();

  final TextEditingController _applicationDateController =
      TextEditingController();

  final TextEditingController _nextDoseDateController = TextEditingController();

  final TextEditingController _doseController =
      TextEditingController(text: '1');

  final TextEditingController _observationsController = TextEditingController();

  List<Cattle> _cattleList = <Cattle>[];
  Cattle? _selectedCattle;

  List<Veterinarian> _veterinarians = <Veterinarian>[];
  Veterinarian? _selectedVeterinarian;

  List<Vaccine> _vaccines = <Vaccine>[];
  Vaccine? _selectedVaccine;

  DateTime _applicationDate = DateTime.now();
  DateTime? _nextDoseDate;

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    final VaccineRecord? vaccine = widget.vaccine;

    if (vaccine != null) {
      _applicationDate = vaccine.applicationDate;
      _nextDoseDate = vaccine.nextDoseDate;
      _doseController.text = vaccine.dose;
      _observationsController.text = vaccine.observations;
    }

    _updateApplicationDateText();
    _updateNextDoseDateText();
    _loadInitialData();
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  void _updateApplicationDateText() {
    _applicationDateController.text = _formatDate(_applicationDate);
  }

  void _updateNextDoseDateText() {
    _nextDoseDateController.text =
        _nextDoseDate == null ? '' : _formatDate(_nextDoseDate!);
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await Future.wait([
        _loadCattle(),
        _loadVeterinarians(),
        _loadVaccines(),
      ]);
    } catch (error) {
      debugPrint(
        'Error cargando datos de vacunación: $error',
      );
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadCattle() async {
    try {
      final List<Cattle> result = await _cattleRepository.getAllCattle();

      if (!mounted) {
        return;
      }

      Cattle? selectedCattle;

      final VaccineRecord? vaccine = widget.vaccine;

      if (vaccine != null) {
        for (final Cattle cattle in result) {
          if (cattle.id == vaccine.cattleId) {
            selectedCattle = cattle;
            break;
          }
        }
      }

      setState(() {
        _cattleList = result;
        _selectedCattle = selectedCattle;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'No fue posible cargar el ganado.',
      );

      debugPrint(
        'Error cargando ganado para vacuna: $error',
      );
    }
  }

  Future<void> _loadVeterinarians() async {
    try {
      final List<Veterinarian> result =
          await _veterinarianRepository.getActiveVeterinarians();

      if (!mounted) {
        return;
      }

      Veterinarian? selectedVeterinarian;

      final VaccineRecord? vaccine = widget.vaccine;

      if (vaccine != null && vaccine.responsible.trim().isNotEmpty) {
        for (final Veterinarian veterinarian in result) {
          if (veterinarian.name.trim().toLowerCase() ==
              vaccine.responsible.trim().toLowerCase()) {
            selectedVeterinarian = veterinarian;
            break;
          }
        }
      }

      setState(() {
        _veterinarians = result;
        _selectedVeterinarian = selectedVeterinarian;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'No fue posible cargar los veterinarios.',
      );

      debugPrint(
        'Error cargando veterinarios: $error',
      );
    }
  }

  Future<void> _loadVaccines() async {
    try {
      final List<Vaccine> result =
          await _vaccineCatalogRepository.getActiveVaccines();

      if (!mounted) {
        return;
      }

      Vaccine? selectedVaccine;

      final VaccineRecord? vaccination = widget.vaccine;

      if (vaccination != null) {
        for (final Vaccine vaccine in result) {
          if (vaccine.id == vaccination.vaccineId) {
            selectedVaccine = vaccine;
            break;
          }
        }
      }

      setState(() {
        _vaccines = result;
        _selectedVaccine = selectedVaccine;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'No fue posible cargar el catálogo de vacunas.',
      );

      debugPrint(
        'Error cargando catálogo de vacunas: $error',
      );
    }
  }

  Future<void> _pickApplicationDate() async {
    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: _applicationDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (selectedDate == null) {
      return;
    }

    setState(() {
      _applicationDate = selectedDate;
      _updateApplicationDateText();

      if (_nextDoseDate != null && _nextDoseDate!.isBefore(_applicationDate)) {
        _nextDoseDate = null;
        _updateNextDoseDateText();
      }
    });
  }

  Future<void> _pickNextDoseDate() async {
    final DateTime initialDate = _nextDoseDate ??
        _applicationDate.add(
          const Duration(days: 30),
        );

    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: _applicationDate,
      lastDate: DateTime(
        DateTime.now().year + 10,
      ),
    );

    if (selectedDate == null) {
      return;
    }

    setState(() {
      _nextDoseDate = selectedDate;
      _updateNextDoseDateText();
    });
  }

  void _removeNextDoseDate() {
    setState(() {
      _nextDoseDate = null;
      _nextDoseDateController.clear();
    });
  }

  Future<void> _saveVaccine() async {
    if (_isSaving) {
      return;
    }

    final bool isValid = _formKey.currentState?.validate() ?? false;

    if (!isValid) {
      return;
    }

    if (_selectedCattle == null || _selectedCattle!.id == null) {
      _showMessage(
        'Selecciona el animal vacunado.',
      );
      return;
    }

    if (_selectedVaccine == null || _selectedVaccine!.id == null) {
      _showMessage(
        'Selecciona una vacuna.',
      );
      return;
    }

    if (_selectedVeterinarian == null) {
      _showMessage(
        'Selecciona el veterinario responsable.',
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final VaccineRecord vaccine = VaccineRecord(
        id: widget.vaccine?.id,
        cattleId: _selectedCattle!.id!,
        vaccineId: _selectedVaccine!.id!,
        veterinarianId: _selectedVeterinarian!.id!,
        cattleCode: _selectedCattle!.code,
        vaccineName: _selectedVaccine!.name,
        veterinarianName: _selectedVeterinarian!.name,
        applicationDate: _applicationDate,
        nextDoseDate: _nextDoseDate,
        dose: _doseController.text.trim(),
        observations: _observationsController.text.trim(),
        createdAt: widget.vaccine?.createdAt,
        updatedAt: widget.vaccine?.updatedAt,
      );

      if (widget.isEditing) {
        await _vaccineRepository.updateVaccineRecord(
          vaccine,
        );
      } else {
        await _vaccineRepository.insertVaccineRecord(
          vaccine,
        );
      }

      if (!mounted) {
        return;
      }

      Navigator.pop(context, true);
    } catch (error) {
      _showMessage(
        'No se pudo guardar la vacuna: $error',
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
  void dispose() {
    _applicationDateController.dispose();
    _nextDoseDateController.dispose();
    _doseController.dispose();
    _observationsController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditing ? 'Actualizar vacuna' : 'Registrar vacuna',
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  if (_cattleList.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.warning_amber,
                              size: 48,
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'No hay ganado registrado.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Primero debes registrar un animal.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    DropdownButtonFormField<Cattle>(
                      initialValue: _selectedCattle,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Animal vacunado',
                        prefixIcon: FaIcon(
                          FontAwesomeIcons.cow,
                          size: 38,
                          color: Color(0xFF0F5132),
                        ),
                      ),
                      items: _cattleList.map(
                        (Cattle cattle) {
                          return DropdownMenuItem<Cattle>(
                            value: cattle,
                            child: Text(
                              'Arete ${cattle.code} — '
                              '${cattle.initialWeight != null ? '${cattle.initialWeight!.toStringAsFixed(1)} kg' : 'Sin peso'}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        },
                      ).toList(),
                      onChanged: (Cattle? cattle) {
                        setState(() {
                          _selectedCattle = cattle;
                        });
                      },
                      validator: (Cattle? value) {
                        if (value == null) {
                          return 'Selecciona un animal';
                        }

                        return null;
                      },
                    ),
                  const SizedBox(height: 14),
                  if (_vaccines.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'No hay vacunas activas disponibles.',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    DropdownButtonFormField<Vaccine>(
                      initialValue: _selectedVaccine,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Vacuna',
                        prefixIcon: Icon(
                          Icons.vaccines_outlined,
                        ),
                        border: OutlineInputBorder(),
                      ),
                      items: _vaccines.map(
                        (Vaccine vaccine) {
                          final String manufacturer =
                              vaccine.manufacturer?.trim().isNotEmpty == true
                                  ? ' — ${vaccine.manufacturer}'
                                  : '';

                          return DropdownMenuItem<Vaccine>(
                            value: vaccine,
                            child: Text(
                              '${vaccine.name}$manufacturer',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        },
                      ).toList(),
                      onChanged: (Vaccine? vaccine) {
                        setState(() {
                          _selectedVaccine = vaccine;
                        });
                      },
                      validator: (Vaccine? value) {
                        if (value == null) {
                          return 'Selecciona una vacuna';
                        }

                        return null;
                      },
                    ),
                  const SizedBox(height: 14),
                  AppTextField(
                    label: 'Fecha de aplicación',
                    controller: _applicationDateController,
                    icon: Icons.calendar_month,
                    readOnly: true,
                    onTap: _pickApplicationDate,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Selecciona una fecha';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    label: 'Próxima dosis (opcional)',
                    controller: _nextDoseDateController,
                    icon: Icons.event_repeat_outlined,
                    readOnly: true,
                    onTap: _pickNextDoseDate,
                    suffixIcon: _nextDoseDate == null
                        ? const Icon(
                            Icons.calendar_today_outlined,
                          )
                        : IconButton(
                            tooltip: 'Quitar fecha',
                            onPressed: _removeNextDoseDate,
                            icon: const Icon(
                              Icons.close,
                            ),
                          ),
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    label: 'Dosis',
                    controller: _doseController,
                    icon: Icons.medication_outlined,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Ingresa la dosis aplicada';
                      }

                      if (value.trim().length > 100) {
                        return 'La dosis no puede superar 100 caracteres';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  if (_veterinarians.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'No hay veterinarios activos. '
                                'Registra un veterinario antes de '
                                'guardar la vacunación.',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    DropdownButtonFormField<Veterinarian>(
                      initialValue: _selectedVeterinarian,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Veterinario responsable',
                        prefixIcon: Icon(
                          Icons.medical_services_outlined,
                        ),
                        border: OutlineInputBorder(),
                      ),
                      items: _veterinarians.map(
                        (Veterinarian veterinarian) {
                          final String specialty =
                              veterinarian.specialty?.trim().isNotEmpty == true
                                  ? ' — ${veterinarian.specialty}'
                                  : '';

                          return DropdownMenuItem<Veterinarian>(
                            value: veterinarian,
                            child: Text(
                              '${veterinarian.name}$specialty',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        },
                      ).toList(),
                      onChanged: (Veterinarian? veterinarian) {
                        setState(() {
                          _selectedVeterinarian = veterinarian;
                        });
                      },
                      validator: (Veterinarian? value) {
                        if (value == null) {
                          return 'Selecciona un veterinario';
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
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _isSaving ||
                            _cattleList.isEmpty ||
                            _veterinarians.isEmpty
                        ? null
                        : _saveVaccine,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : Icon(
                            widget.isEditing
                                ? Icons.update
                                : Icons.save_outlined,
                          ),
                    label: Text(
                      _isSaving
                          ? 'Guardando...'
                          : widget.isEditing
                              ? 'Actualizar vacunación'
                              : 'Guardar vacunación',
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
