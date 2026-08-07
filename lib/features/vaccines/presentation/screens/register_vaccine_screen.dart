import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../cattle/data/models/cattle.dart';
import '../../../cattle/data/repositories/cattle_repository.dart';
import '../../data/models/vaccine_record.dart';
import '../../data/repositories/vaccine_repository.dart';
import '../../../../core/session/session_manager.dart';

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

  final TextEditingController _vaccineController = TextEditingController();

  final TextEditingController _applicationDateController =
      TextEditingController();

  final TextEditingController _nextDoseDateController = TextEditingController();

  final TextEditingController _doseController =
      TextEditingController(text: '1');

  final TextEditingController _responsibleController = TextEditingController();

  final TextEditingController _observationsController = TextEditingController();

  List<Cattle> _cattleList = <Cattle>[];
  Cattle? _selectedCattle;

  DateTime _applicationDate = DateTime.now();
  DateTime? _nextDoseDate;

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    final VaccineRecord? vaccine = widget.vaccine;

    if (vaccine != null) {
      _vaccineController.text = vaccine.vaccineName;
      _applicationDate = vaccine.applicationDate;
      _nextDoseDate = vaccine.nextDoseDate;
      _doseController.text = vaccine.doseNumber.toString();
      _responsibleController.text = vaccine.responsible;
      _observationsController.text = vaccine.observations;
    }

    _updateApplicationDateText();
    _updateNextDoseDateText();
    _loadCattle();
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
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      _showMessage(
        'No fue posible cargar el ganado.',
      );

      debugPrint(
        'Error cargando ganado para vacuna: $error',
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
    final int? userId = SessionManager.instance.currentUserId;

    if (userId == null) {
      _showMessage(
        'No hay una sesión activa.',
      );
      return;
    }
    final int? doseNumber = int.tryParse(
      _doseController.text.trim(),
    );

    if (doseNumber == null || doseNumber <= 0) {
      _showMessage(
        'Ingresa un número de dosis válido.',
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final VaccineRecord vaccine = VaccineRecord(
        id: widget.vaccine?.id,
        userId: userId,
        cattleId: _selectedCattle!.id!,
        cattleCode: _selectedCattle!.code,
        vaccineName: _vaccineController.text.trim(),
        applicationDate: _applicationDate,
        nextDoseDate: _nextDoseDate,
        doseNumber: doseNumber,
        responsible: _responsibleController.text.trim(),
        observations: _observationsController.text.trim(),
        createdAt: widget.vaccine?.createdAt ?? DateTime.now(),
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
    _vaccineController.dispose();
    _applicationDateController.dispose();
    _nextDoseDateController.dispose();
    _doseController.dispose();
    _responsibleController.dispose();
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
                        prefixIcon: const FaIcon(
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
                              '${cattle.initialWeight.toStringAsFixed(1)} kg',
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
                  AppTextField(
                    label: 'Nombre de la vacuna',
                    controller: _vaccineController,
                    icon: Icons.vaccines_outlined,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Ingresa el nombre de la vacuna';
                      }

                      if (value.trim().length < 3) {
                        return 'El nombre es demasiado corto';
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
                    label: 'Número de dosis',
                    controller: _doseController,
                    icon: Icons.format_list_numbered,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      final int? dose = int.tryParse(
                        value?.trim() ?? '',
                      );

                      if (dose == null || dose <= 0) {
                        return 'Ingresa una dosis válida';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    label: 'Veterinario o responsable',
                    controller: _responsibleController,
                    icon: Icons.medical_services_outlined,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Ingresa el responsable';
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
                    onPressed:
                        _isSaving || _cattleList.isEmpty ? null : _saveVaccine,
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
