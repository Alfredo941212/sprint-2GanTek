import 'package:flutter/material.dart';

import '../../../cattle/data/models/cattle.dart';
import '../../../cattle/data/repositories/cattle_repository.dart';
import '../../data/models/milking_record.dart';
import '../../data/repositories/milking_repository.dart';
import 'register_milking_screen.dart';

class MilkingListScreen extends StatefulWidget {
  const MilkingListScreen({
    super.key,
  });

  @override
  State<MilkingListScreen> createState() => _MilkingListScreenState();
}

class _MilkingListScreenState extends State<MilkingListScreen> {
  final MilkingRepository _milkingRepository = MilkingRepository();

  final CattleRepository _cattleRepository = CattleRepository();

  DateTime _selectedDate = DateTime.now();

  List<MilkingRecord> _milkings = [];

  Map<int, Cattle> _cattleById = {};

  double _totalProduction = 0;

  bool _isLoading = true;

  // =========================================================
  // INICIALIZACIÓN
  // =========================================================

  @override
  void initState() {
    super.initState();

    _loadData();
  }

  // =========================================================
  // CARGAR DATOS
  // =========================================================

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final List<MilkingRecord> milkings =
          await _milkingRepository.getMilkingsByDate(
        _selectedDate,
      );

      final double total = await _milkingRepository.getDailyProduction(
        _selectedDate,
      );

      final List<Cattle> cattle = await _cattleRepository.getAllCattle();

      final Map<int, Cattle> cattleMap = {};

      for (final Cattle animal in cattle) {
        final int? id = animal.id;

        if (id != null) {
          cattleMap[id] = animal;
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _milkings = milkings;
        _totalProduction = total;
        _cattleById = cattleMap;
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
        'No fue posible cargar las ordeñas.',
      );

      debugPrint(
        'Error cargando ordeñas: $error',
      );
    }
  }

  // =========================================================
  // CAMBIAR FECHA
  // =========================================================

  Future<void> _selectDate() async {
    final DateTime? selected = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (selected == null) {
      return;
    }

    setState(() {
      _selectedDate = selected;
    });

    await _loadData();
  }

  // =========================================================
  // REGISTRAR ORDEÑA
  // =========================================================

  Future<void> _openRegisterMilking() async {
    final bool? saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const RegisterMilkingScreen(),
      ),
    );

    if (saved != true) {
      return;
    }

    await _loadData();

    if (!mounted) {
      return;
    }

    _showMessage(
      'Ordeña registrada correctamente.',
    );
  }

  // =========================================================
  // ELIMINAR
  // =========================================================

  Future<void> _confirmDelete(
    MilkingRecord record,
  ) async {
    final int? recordId = record.id;

    if (recordId == null) {
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (
        BuildContext dialogContext,
      ) {
        return AlertDialog(
          title: const Text(
            'Eliminar ordeña',
          ),
          content: Text(
            '¿Deseas eliminar la ordeña '
            '#${record.milkingNumber} de '
            '${record.liters.toStringAsFixed(1)} L?',
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
                'Cancelar',
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
      await _milkingRepository.deleteMilking(
        recordId,
      );

      await _loadData();

      if (!mounted) {
        return;
      }

      _showMessage(
        'Ordeña eliminada.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'No fue posible eliminar la ordeña.',
      );

      debugPrint(
        'Error eliminando ordeña: $error',
      );
    }
  }

  // =========================================================
  // NOMBRE DEL ANIMAL
  // =========================================================

  String _cattleName(
    MilkingRecord record,
  ) {
    final Cattle? cattle = _cattleById[record.cattleId];

    if (cattle == null) {
      return 'Animal no disponible';
    }

    if (cattle.name.trim().isNotEmpty) {
      return cattle.name;
    }

    return 'Arete ${cattle.code}';
  }

  String _cattleCode(
    MilkingRecord record,
  ) {
    final Cattle? cattle = _cattleById[record.cattleId];

    if (cattle == null) {
      return '';
    }

    return cattle.code;
  }

  // =========================================================
  // FORMATO FECHA
  // =========================================================

  String _formatDate(
    DateTime date,
  ) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  // =========================================================
  // MENSAJES
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
          content: Text(message),
        ),
      );
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
        title: const Text(
          'Producción de leche',
        ),
        actions: [
          IconButton(
            tooltip: 'Seleccionar fecha',
            onPressed: _selectDate,
            icon: const Icon(
              Icons.calendar_month_outlined,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openRegisterMilking,
        icon: const Icon(
          Icons.add,
        ),
        label: const Text(
          'Registrar ordeña',
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _isLoading
            ? ListView(
                children: const [
                  SizedBox(
                    height: 250,
                  ),
                  Center(
                    child: CircularProgressIndicator(),
                  ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  100,
                ),
                children: [
                  // =========================================
                  // FECHA
                  // =========================================

                  InkWell(
                    onTap: _selectDate,
                    borderRadius: BorderRadius.circular(
                      14,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(
                        14,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).dividerColor,
                        ),
                        borderRadius: BorderRadius.circular(
                          14,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                          ),
                          const SizedBox(
                            width: 12,
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Fecha seleccionada',
                                  style: TextStyle(
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(
                                  height: 3,
                                ),
                                Text(
                                  _formatDate(
                                    _selectedDate,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 16,
                  ),

                  // =========================================
                  // PRODUCCIÓN TOTAL
                  // =========================================

                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(
                        20,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(
                                14,
                              ),
                            ),
                            child: Icon(
                              Icons.water_drop_outlined,
                              color: Theme.of(
                                context,
                              ).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(
                            width: 16,
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Producción total del día',
                                ),
                                const SizedBox(
                                  height: 4,
                                ),
                                Text(
                                  '${_totalProduction.toStringAsFixed(1)} L',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  Text(
                    'Ordeñas registradas',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),

                  const SizedBox(
                    height: 10,
                  ),

                  // =========================================
                  // SIN REGISTROS
                  // =========================================

                  if (_milkings.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(
                        30,
                      ),
                      alignment: Alignment.center,
                      child: const Column(
                        children: [
                          Icon(
                            Icons.water_drop_outlined,
                            size: 55,
                          ),
                          SizedBox(
                            height: 12,
                          ),
                          Text(
                            'No hay ordeñas registradas para esta fecha.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                  // =========================================
                  // REGISTROS
                  // =========================================

                  ..._milkings.map(
                    (
                      MilkingRecord record,
                    ) {
                      final String code = _cattleCode(
                        record,
                      );

                      return Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: CircleAvatar(
                            child: Text(
                              '#${record.milkingNumber}',
                            ),
                          ),
                          title: Text(
                            _cattleName(
                              record,
                            ),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (code.isNotEmpty)
                                Text(
                                  'Arete: $code',
                                ),
                              Text(
                                record.shift == null
                                    ? 'Ordeña ${record.milkingNumber}'
                                    : 'Ordeña ${record.milkingNumber} • ${record.shift}',
                              ),
                              if (record.observations?.trim().isNotEmpty ==
                                  true)
                                Text(
                                  record.observations!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${record.liters.toStringAsFixed(1)} L',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Eliminar',
                                onPressed: () {
                                  _confirmDelete(
                                    record,
                                  );
                                },
                                icon: const Icon(
                                  Icons.delete_outline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
      ),
    );
  }
}
