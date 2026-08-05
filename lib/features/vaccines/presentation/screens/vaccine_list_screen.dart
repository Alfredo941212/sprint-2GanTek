import 'package:flutter/material.dart';

import '../../data/models/vaccine_record.dart';
import '../../data/repositories/vaccine_repository.dart';
import 'register_vaccine_screen.dart';

class VaccineListScreen extends StatefulWidget {
  const VaccineListScreen({super.key});

  @override
  State<VaccineListScreen> createState() => _VaccineListScreenState();
}

class _VaccineListScreenState extends State<VaccineListScreen> {
  final VaccineRepository _repository = VaccineRepository();

  late Future<List<VaccineRecord>> _vaccinesFuture;

  @override
  void initState() {
    super.initState();
    _loadVaccines();
  }

  void _loadVaccines() {
    _vaccinesFuture = _repository.getAllVaccines();
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  bool _isUpcoming(DateTime? nextDoseDate) {
    if (nextDoseDate == null) {
      return false;
    }

    final DateTime today = DateTime.now();

    final DateTime limit = today.add(
      const Duration(days: 30),
    );

    return !nextDoseDate.isBefore(today) && !nextDoseDate.isAfter(limit);
  }

  bool _isOverdue(DateTime? nextDoseDate) {
    if (nextDoseDate == null) {
      return false;
    }

    final DateTime today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    return nextDoseDate.isBefore(today);
  }

  Future<void> _openRegisterVaccine() async {
    final bool? wasSaved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const RegisterVaccineScreen(),
      ),
    );

    if (wasSaved == true) {
      setState(_loadVaccines);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Vacunación registrada correctamente.',
          ),
        ),
      );
    }
  }

  Future<void> _openEditVaccine(
    VaccineRecord vaccine,
  ) async {
    final bool? updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RegisterVaccineScreen(
          vaccine: vaccine,
        ),
      ),
    );

    if (updated != true) {
      return;
    }

    setState(_loadVaccines);

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Vacunación actualizada correctamente.',
          ),
        ),
      );
  }

  Future<void> _deleteVaccine(
    VaccineRecord vaccine,
  ) async {
    if (vaccine.id == null) {
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text(
            'Eliminar vacunación',
          ),
          content: Text(
            '¿Deseas eliminar el registro de '
            '${vaccine.vaccineName} aplicado al '
            'animal ${vaccine.cattleCode}?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await _repository.deleteVaccineRecord(
      vaccine.id!,
    );

    setState(_loadVaccines);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Historial de vacunas',
        ),
      ),
      body: FutureBuilder<List<VaccineRecord>>(
        future: _vaccinesFuture,
        builder: (
          BuildContext context,
          AsyncSnapshot<List<VaccineRecord>> snapshot,
        ) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No fue posible cargar las vacunas.\n'
                  '${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final List<VaccineRecord> vaccines =
              snapshot.data ?? <VaccineRecord>[];

          if (vaccines.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.vaccines_outlined,
                      size: 72,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Todavía no hay vacunas registradas.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(_loadVaccines);
              await _vaccinesFuture;
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: vaccines.length,
              separatorBuilder: (_, __) {
                return const SizedBox(height: 12);
              },
              itemBuilder: (
                BuildContext context,
                int index,
              ) {
                final VaccineRecord vaccine = vaccines[index];

                final bool upcoming = _isUpcoming(
                  vaccine.nextDoseDate,
                );

                final bool overdue = _isOverdue(
                  vaccine.nextDoseDate,
                );

                String nextDoseText = 'Sin próxima dosis';

                if (vaccine.nextDoseDate != null) {
                  nextDoseText =
                      'Próxima: ${_formatDate(vaccine.nextDoseDate!)}';
                }

                if (overdue) {
                  nextDoseText += ' — Vencida';
                } else if (upcoming) {
                  nextDoseText += ' — Próxima';
                }

                return Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      _openEditVaccine(vaccine);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            child: Icon(Icons.vaccines),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  vaccine.vaccineName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                  ),
                                ),
                                Text(
                                  'Animal: ${vaccine.cattleCode}',
                                ),
                                Text(
                                  'Aplicación: '
                                  '${_formatDate(vaccine.applicationDate)}',
                                ),
                                Text(
                                  'Dosis: ${vaccine.doseNumber}',
                                ),
                                Text(nextDoseText),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Eliminar',
                            onPressed: () {
                              _deleteVaccine(vaccine);
                            },
                            icon: const Icon(
                              Icons.delete_outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openRegisterVaccine,
        icon: const Icon(Icons.add),
        label: const Text(
          'Registrar vacuna',
        ),
      ),
    );
  }
}
