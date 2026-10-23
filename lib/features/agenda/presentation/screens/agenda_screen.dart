import 'package:flutter/material.dart';

import '../../data/models/task_model.dart';
import '../../data/repositories/task_repository.dart';
import 'create_task_screen.dart';
import '../../../cattle/data/models/cattle.dart';
import '../../../cattle/data/repositories/cattle_repository.dart';

import '../../../lots/data/models/lot.dart';
import '../../../lots/data/repositories/lot_repository.dart';

class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key});

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  final TaskRepository _repository = TaskRepository();

  bool _isLoading = true;
  String? _error;
  List<TaskModel> _tasks = [];

  final CattleRepository _cattleRepository = CattleRepository();

  final LotRepository _lotRepository = LotRepository();

  List<Cattle> _cattle = [];
  List<Lot> _lots = [];

  String _selectedFilter = 'todas';

  List<TaskModel> get _filteredTasks {
    List<TaskModel> tasks = List.from(_tasks);

    if (_selectedFilter != 'todas') {
      tasks = tasks
          .where(
            (task) => task.estado == _selectedFilter,
          )
          .toList();
    }

    tasks.sort((a, b) {
      final DateTime dateA = _taskDateTime(a);
      final DateTime dateB = _taskDateTime(b);

      return dateA.compareTo(dateB);
    });

    return tasks;
  }

  String? _getCattleName(int? ganadoId) {
    if (ganadoId == null) {
      return null;
    }

    for (final animal in _cattle) {
      if (animal.serverId == ganadoId) {
        if (animal.name.trim().isNotEmpty) {
          return '${animal.name} - ${animal.code}';
        }

        return 'Arete ${animal.code}';
      }
    }

    return null;
  }

  String? _getLotName(int? loteId) {
    if (loteId == null) {
      return null;
    }

    for (final lot in _lots) {
      if (lot.serverId == loteId) {
        return lot.name;
      }
    }

    return null;
  }

  DateTime _taskDateTime(
    TaskModel task,
  ) {
    final DateTime date = DateTime.tryParse(task.fecha) ?? DateTime(2100);

    if (task.hora == null || task.hora!.isEmpty) {
      return date;
    }

    final parts = task.hora!.split(':');

    if (parts.length < 2) {
      return date;
    }

    return DateTime(
      date.year,
      date.month,
      date.day,
      int.tryParse(parts[0]) ?? 0,
      int.tryParse(parts[1]) ?? 0,
    );
  }

  Widget _filterChip(
    String label,
    String value,
  ) {
    return ChoiceChip(
      label: Text(label),
      selected: _selectedFilter == value,
      onSelected: (_) {
        setState(() {
          _selectedFilter = value;
        });
      },
    );
  }

  Widget _priorityRow(
    String priority,
  ) {
    Color color;

    switch (priority) {
      case 'alta':
        color = Colors.red;
        break;

      case 'media':
        color = Colors.orange;
        break;

      case 'baja':
        color = Colors.green;
        break;

      default:
        color = Colors.grey;
    }

    return Padding(
      padding: const EdgeInsets.only(
        bottom: 6,
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Prioridad',
              style: TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: color.withValues(
                alpha: 0.10,
              ),
              borderRadius: BorderRadius.circular(
                20,
              ),
              border: Border.all(
                color: color,
              ),
            ),
            child: Text(
              _capitalize(priority),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _editTask(
    TaskModel task,
  ) async {
    final bool? updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateTaskScreen(
          task: task,
        ),
      ),
    );

    if (updated != true || !mounted) {
      return;
    }

    await _loadTasks();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Tarea actualizada correctamente.',
          ),
        ),
      );
  }

  Future<void> _openCreateTask() async {
    final bool? created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const CreateTaskScreen(),
      ),
    );

    if (created != true || !mounted) {
      return;
    }

    await _loadTasks();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Tarea creada correctamente.',
          ),
        ),
      );
  }

  Future<void> _loadTasks() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final result = await _repository.getTasks();

      final results = await Future.wait([
        _repository.getTasks(),
        _cattleRepository.getAllCattle(),
        _lotRepository.getAllLots(),
      ]);

      final List<TaskModel> tasks = results[0] as List<TaskModel>;

      final List<Cattle> cattle = results[1] as List<Cattle>;

      final List<Lot> lots = results[2] as List<Lot>;

      if (!mounted) return;

      setState(() {
        _tasks = tasks;
        _cattle = cattle;
        _lots = lots;
        _isLoading = false;
      });
      setState(() {
        _tasks = result;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _completeTask(
    TaskModel task,
  ) async {
    try {
      await _repository.completeTask(
        task.id,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Tarea completada correctamente.',
            ),
          ),
        );

      await _loadTasks();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'No se pudo completar la tarea. $error',
            ),
          ),
        );
    }
  }

  Future<void> _confirmCancelTask(
    TaskModel task,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text(
            'Cancelar tarea',
          ),
          content: Text(
            '¿Deseas cancelar la tarea "${task.titulo}"?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text(
                'No',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text(
                'Sí, cancelar',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await _cancelTask(task);
  }

/***BOTON DE CANCELAR */
  Future<void> _cancelTask(
    TaskModel task,
  ) async {
    try {
      await _repository.cancelTask(
        task.id,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Tarea cancelada correctamente.',
            ),
          ),
        );

      await _loadTasks();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'No se pudo cancelar la tarea. $error',
            ),
          ),
        );
    }
  }

  Future<void> _confirmDeleteTask(TaskModel task) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Eliminar tarea',
          ),
          content: Text(
            '¿Estás segur@ de eliminar la tarea "${task.titulo}"?\n\n'
            'Esta acción no se puede deshacer.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text(
                'Cancelar',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text(
                'Eliminar',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _repository.deleteTask(
        task.id,
      );

      if (!mounted) {
        return;
      }

      await _loadTasks();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tarea eliminada correctamente.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst(
                  'Exception: ',
                  '',
                ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda'),
        actions: [
          IconButton(
            onPressed: _loadTasks,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateTask,
        icon: const Icon(
          Icons.add_task,
        ),
        label: const Text(
          'Nueva tarea',
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
              ),
              const SizedBox(height: 12),
              const Text(
                'No se pudo cargar la agenda.',
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadTasks,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (_tasks.isEmpty) {
      return const Center(
        child: Text(
          'No hay tareas registradas.',
        ),
      );
    }

    final List<TaskModel> filteredTasks = _filteredTasks;

    return RefreshIndicator(
      onRefresh: _loadTasks,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip(
                  'Todas',
                  'todas',
                ),
                const SizedBox(width: 8),
                _filterChip(
                  'Pendientes',
                  'pendiente',
                ),
                const SizedBox(width: 8),
                _filterChip(
                  'Completadas',
                  'completada',
                ),
                const SizedBox(width: 8),
                _filterChip(
                  'Canceladas',
                  'cancelada',
                ),
                const SizedBox(width: 8),
                _filterChip(
                  'Vencidas',
                  'vencida',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (filteredTasks.isEmpty)
            const Padding(
              padding: EdgeInsets.only(
                top: 80,
              ),
              child: Center(
                child: Text(
                  'No hay tareas en esta categoría.',
                ),
              ),
            )
          else
            ...filteredTasks.map(
              _buildTaskCard,
            ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(
    TaskModel task,
  ) {
    return Card(
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    task.titulo,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _statusChip(
                  task.estado,
                ),
              ],
            ),
            if (task.descripcion != null &&
                task.descripcion!.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                task.descripcion!,
              ),
            ],
            const SizedBox(height: 12),
            _infoRow(
              'Tipo',
              _formatType(task.tipo),
            ),
            _infoRow(
              'Fecha',
              task.fecha,
            ),
            _infoRow(
              'Hora',
              task.hora ?? 'Sin hora',
            ),
            _priorityRow(task.prioridad),
            _infoRow(
              'Origen',
              task.creadaPorIa ? 'Automática' : 'Manual',
            ),
            if (task.recordatorio)
              _infoRow(
                'Recordatorio',
                'Sí',
              ),
            if (task.ganadoId != null)
              _infoRow(
                'Ganado',
                _getCattleName(task.ganadoId) ?? 'Ganado relacionado',
              ),
            if (task.loteId != null)
              _infoRow(
                'Lote',
                _getLotName(task.loteId) ?? 'Lote relacionado',
              ),
            if (task.estado == 'pendiente') ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        _completeTask(task);
                      },
                      icon: const Icon(
                        Icons.check_circle_outline,
                      ),
                      label: const Text(
                        'Completar',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _confirmCancelTask(task);
                      },
                      icon: const Icon(
                        Icons.cancel_outlined,
                      ),
                      label: const Text(
                        'Cancelar',
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    _editTask(task);
                  },
                  icon: const Icon(
                    Icons.edit_outlined,
                  ),
                  label: const Text(
                    'Editar tarea',
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (task.estado == 'vencida' || task.estado == 'cancelada') ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    _confirmDeleteTask(task);
                  },
                  icon: const Icon(
                    Icons.delete_outline,
                  ),
                  label: const Text(
                    'Eliminar tarea',
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 6,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(value),
        ],
      ),
    );
  }

  Widget _statusChip(
    String status,
  ) {
    String label;
    IconData icon;

    switch (status) {
      case 'pendiente':
        label = 'Pendiente';
        icon = Icons.schedule;
        break;

      case 'completada':
        label = 'Completada';
        icon = Icons.check_circle_outline;
        break;

      case 'cancelada':
        label = 'Cancelada';
        icon = Icons.cancel_outlined;
        break;

      case 'vencida':
        label = 'Vencida';
        icon = Icons.warning_amber_rounded;
        break;

      default:
        label = status;
        icon = Icons.info_outline;
    }

    return Chip(
      avatar: Icon(
        icon,
        size: 18,
      ),
      label: Text(label),
    );
  }

  String _formatType(
    String type,
  ) {
    switch (type) {
      case 'ordenio':
        return 'Ordeña';

      case 'vacunacion':
        return 'Vacunación';

      case 'veterinaria':
        return 'Veterinaria';

      case 'produccion':
        return 'Producción';

      default:
        return 'General';
    }
  }

  String _capitalize(
    String value,
  ) {
    if (value.isEmpty) {
      return value;
    }

    return '${value[0].toUpperCase()}'
        '${value.substring(1)}';
  }
}
