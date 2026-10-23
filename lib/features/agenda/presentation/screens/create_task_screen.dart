import 'package:flutter/material.dart';
import '../../data/models/task_model.dart';
import '../../data/repositories/task_repository.dart';
import '../../../cattle/data/models/cattle.dart';
import '../../../cattle/data/repositories/cattle_repository.dart';

import '../../../lots/data/models/lot.dart';
import '../../../lots/data/repositories/lot_repository.dart';

class CreateTaskScreen extends StatefulWidget {
  const CreateTaskScreen({
    super.key,
    this.task,
  });

  final TaskModel? task;

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final TaskRepository _repository = TaskRepository();

  final CattleRepository _cattleRepository = CattleRepository();

  final LotRepository _lotRepository = LotRepository();

  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  List<Cattle> _cattle = [];
  List<Lot> _lots = [];

  int? _selectedCattleServerId;
  int? _selectedLotServerId;

  //bool _isLoadingRelations = true;

  String _type = 'general';
  String _priority = 'media';

  DateTime _selectedDate = DateTime.now();
  TimeOfDay? _selectedTime;

  bool _reminder = false;
  bool _isSaving = false;

  bool get _isEditing => widget.task != null;

  @override
  void initState() {
    super.initState();

    _loadRelations();

    final task = widget.task;

    if (task == null) {
      return;
    }

    _selectedCattleServerId = task.ganadoId;
    _selectedLotServerId = task.loteId;
    _titleController.text = task.titulo;
    _descriptionController.text = task.descripcion ?? '';

    _type = task.tipo;
    _priority = task.prioridad;
    _reminder = task.recordatorio;

    final parsedDate = DateTime.tryParse(
      task.fecha,
    );

    if (parsedDate != null) {
      _selectedDate = parsedDate;
    }

    if (task.hora != null && task.hora!.isNotEmpty) {
      final parts = task.hora!.split(':');

      if (parts.length >= 2) {
        _selectedTime = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 0,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadRelations() async {
    try {
      final results = await Future.wait([
        _cattleRepository.getActiveCattle(),
        _lotRepository.getActiveLots(),
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _cattle = results[0] as List<Cattle>;
        _lots = results[1] as List<Lot>;

        // _isLoadingRelations = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        // _isLoadingRelations = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudieron cargar ganado y lotes. $error',
          ),
        ),
      );
    }
  }

  Future<void> _selectDate() async {
    final DateTime? result = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(
        DateTime.now().year + 5,
      ),
    );

    if (result == null) {
      return;
    }

    setState(() {
      _selectedDate = result;
    });
  }

  Future<void> _selectTime() async {
    final TimeOfDay? result = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );

    if (result == null) {
      return;
    }

    setState(() {
      _selectedTime = result;
    });
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final DateTime now = DateTime.now();

    final DateTime selectedDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime?.hour ?? 23,
      _selectedTime?.minute ?? 59,
    );

    if (selectedDateTime.isBefore(now)) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'No puedes crear una tarea con fecha y hora pasadas.',
            ),
          ),
        );

      return;
    }

    // VALIDAR QUE EL GANADO PERTENEZCA AL LOTE SELECCIONADO
    if (_selectedCattleServerId != null) {
      Cattle? selectedAnimal;

      for (final animal in _cattle) {
        if (animal.serverId == _selectedCattleServerId) {
          selectedAnimal = animal;
          break;
        }
      }

      if (selectedAnimal != null && selectedAnimal.lotId != null) {
        Lot? animalLot;

        for (final lot in _lots) {
          if (lot.id == selectedAnimal.lotId) {
            animalLot = lot;
            break;
          }
        }

        if (animalLot != null && animalLot.serverId != _selectedLotServerId) {
          if (!mounted) {
            return;
          }

          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text(
                  'El lote seleccionado no corresponde al ganado.',
                ),
              ),
            );

          return;
        }
      }
    }

    try {
      setState(() {
        _isSaving = true;
      });

      final String date = '${_selectedDate.year.toString().padLeft(4, '0')}-'
          '${_selectedDate.month.toString().padLeft(2, '0')}-'
          '${_selectedDate.day.toString().padLeft(2, '0')}';

      String? time;

      if (_selectedTime != null) {
        time = '${_selectedTime!.hour.toString().padLeft(2, '0')}:'
            '${_selectedTime!.minute.toString().padLeft(2, '0')}';
      }

      if (_isEditing) {
        await _repository.updateTask(
          taskId: widget.task!.id,
          ganadoId: _selectedCattleServerId,
          loteId: _selectedLotServerId,
          titulo: _titleController.text.trim(),
          descripcion: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          tipo: _type,
          fecha: date,
          hora: time,
          prioridad: _priority,
          recordatorio: _reminder,
        );
      } else {
        await _repository.createTask(
          ganadoId: _selectedCattleServerId,
          loteId: _selectedLotServerId,
          titulo: _titleController.text.trim(),
          descripcion: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          tipo: _type,
          fecha: date,
          hora: time,
          prioridad: _priority,
          recordatorio: _reminder,
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

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'No se pudo crear la tarea. $error',
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Editar tarea' : 'Nueva tarea',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Título',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Ingresa un título.';
                }

                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(
                labelText: 'Tipo',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'general',
                  child: Text('General'),
                ),
                DropdownMenuItem(
                  value: 'ordenio',
                  child: Text('Ordeña'),
                ),
                DropdownMenuItem(
                  value: 'vacunacion',
                  child: Text('Vacunación'),
                ),
                DropdownMenuItem(
                  value: 'veterinaria',
                  child: Text('Veterinaria'),
                ),
                DropdownMenuItem(
                  value: 'produccion',
                  child: Text('Producción'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  _type = value;
                });
              },
            ),
            const SizedBox(height: 16),
            /////
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _priority,
              decoration: const InputDecoration(
                labelText: 'Prioridad',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'baja',
                  child: Text('Baja'),
                ),
                DropdownMenuItem(
                  value: 'media',
                  child: Text('Media'),
                ),
                DropdownMenuItem(
                  value: 'alta',
                  child: Text('Alta'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  _priority = value;
                });
              },
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.calendar_today_outlined,
              ),
              title: const Text('Fecha'),
              subtitle: Text(
                '${_selectedDate.day.toString().padLeft(2, '0')}/'
                '${_selectedDate.month.toString().padLeft(2, '0')}/'
                '${_selectedDate.year}',
              ),
              trailing: const Icon(
                Icons.chevron_right,
              ),
              onTap: _selectDate,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.access_time,
              ),
              title: const Text('Hora'),
              subtitle: Text(
                _selectedTime == null
                    ? 'Sin hora'
                    : _selectedTime!.format(context),
              ),
              trailing: const Icon(
                Icons.chevron_right,
              ),
              onTap: _selectTime,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Recordatorio',
              ),
              subtitle: const Text(
                'Marcar esta tarea para recordatorio',
              ),
              value: _reminder,
              onChanged: (value) {
                setState(() {
                  _reminder = value;
                });
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _saveTask,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(
                  _isSaving
                      ? 'Guardando...'
                      : _isEditing
                          ? 'Actualizar tarea'
                          : 'Guardar tarea',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
