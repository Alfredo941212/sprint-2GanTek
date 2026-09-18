import 'package:flutter/material.dart';

import '../../data/models/vaccine_record.dart';
import '../../data/repositories/vaccine_repository.dart';
import 'register_vaccine_screen.dart';

class VaccineDetailScreen extends StatefulWidget {
  const VaccineDetailScreen({
    super.key,
    required this.vaccine,
  });

  final VaccineRecord vaccine;

  @override
  State<VaccineDetailScreen> createState() => _VaccineDetailScreenState();
}

class _VaccineDetailScreenState extends State<VaccineDetailScreen> {
  final VaccineRepository _repository = VaccineRepository();

  late VaccineRecord _vaccine;

  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _vaccine = widget.vaccine;
  }

  // =========================================================
  // EDITAR
  // =========================================================

  Future<void> _editVaccine() async {
    final bool? updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RegisterVaccineScreen(
          vaccine: _vaccine,
        ),
      ),
    );

    if (updated != true) {
      return;
    }

    if (!mounted) {
      return;
    }

    Navigator.pop(
      context,
      true,
    );
  }

  // =========================================================
  // ELIMINAR
  // =========================================================

  Future<void> _deleteVaccine() async {
    final int? vaccineId = _vaccine.id;

    if (vaccineId == null) {
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (
        BuildContext dialogContext,
      ) {
        return AlertDialog(
          title: const Text(
            'Eliminar vacunación',
          ),
          content: Text(
            '¿Deseas eliminar el registro de '
            '${_vaccine.vaccineName} aplicado al '
            'animal ${_vaccine.cattleCode}?',
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

    setState(() {
      _isDeleting = true;
    });

    try {
      await _repository.deleteVaccineRecord(
        vaccineId,
      );

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
        _isDeleting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No fue posible eliminar la vacunación.',
          ),
        ),
      );

      debugPrint(
        'Error eliminando vacunación: $error',
      );
    }
  }

  // =========================================================
  // FECHAS
  // =========================================================

  String _formatDate(
    DateTime date,
  ) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _nextDoseText() {
    final DateTime? nextDoseDate = _vaccine.nextDoseDate;

    if (nextDoseDate == null) {
      return 'Sin próxima dosis';
    }

    return _formatDate(
      nextDoseDate,
    );
  }

  // =========================================================
  // ESTADO DE PRÓXIMA DOSIS
  // =========================================================

  String _doseStatus() {
    final DateTime? nextDoseDate = _vaccine.nextDoseDate;

    if (nextDoseDate == null) {
      return 'Sin próxima dosis';
    }

    final DateTime today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    final DateTime limit = today.add(
      const Duration(
        days: 30,
      ),
    );

    if (nextDoseDate.isBefore(
      today,
    )) {
      return 'Vencida';
    }

    if (!nextDoseDate.isAfter(
      limit,
    )) {
      return 'Próxima';
    }

    return 'Programada';
  }

  Color _doseStatusColor() {
    switch (_doseStatus()) {
      case 'Vencida':
        return Colors.red.shade700;

      case 'Próxima':
        return Colors.orange.shade700;

      case 'Programada':
        return Colors.green.shade700;

      default:
        return Colors.grey.shade700;
    }
  }

  Color _doseStatusBackground() {
    switch (_doseStatus()) {
      case 'Vencida':
        return Colors.red.shade50;

      case 'Próxima':
        return Colors.orange.shade50;

      case 'Programada':
        return Colors.green.shade50;

      default:
        return Colors.grey.shade200;
    }
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
          'Detalle de vacunación',
        ),
        actions: [
          IconButton(
            tooltip: 'Editar',
            onPressed: _isDeleting ? null : _editVaccine,
            icon: const Icon(
              Icons.edit_outlined,
            ),
          ),
          IconButton(
            tooltip: 'Eliminar',
            onPressed: _isDeleting ? null : _deleteVaccine,
            icon: const Icon(
              Icons.delete_outline,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(
          16,
        ),
        children: [
          // ===================================================
          // CABECERA
          // ===================================================

          Card(
            child: Padding(
              padding: const EdgeInsets.all(
                18,
              ),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 36,
                    child: Icon(
                      Icons.vaccines,
                      size: 34,
                    ),
                  ),
                  const SizedBox(
                    height: 12,
                  ),
                  Text(
                    _vaccine.vaccineName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(
                    height: 6,
                  ),
                  Text(
                    'Animal: ${_vaccine.cattleCode}',
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _doseStatusBackground(),
                      borderRadius: BorderRadius.circular(
                        20,
                      ),
                    ),
                    child: Text(
                      _doseStatus(),
                      style: TextStyle(
                        color: _doseStatusColor(),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(
            height: 16,
          ),

          // ===================================================
          // DATOS DE VACUNACIÓN
          // ===================================================

          _SectionCard(
            title: 'Datos de vacunación',
            icon: Icons.vaccines_outlined,
            children: [
              _DetailRow(
                label: 'Vacuna',
                value: _vaccine.vaccineName,
              ),
              _DetailRow(
                label: 'Animal',
                value: _vaccine.cattleCode,
              ),
              _DetailRow(
                label: 'Fecha de aplicación',
                value: _formatDate(
                  _vaccine.applicationDate,
                ),
              ),
              _DetailRow(
                label: 'Número de dosis',
                value: _vaccine.dose,
              ),
              _DetailRow(
                label: 'Próxima dosis',
                value: _nextDoseText(),
              ),
              _DetailRow(
                label: 'Estado',
                value: _doseStatus(),
              ),
            ],
          ),

          const SizedBox(
            height: 16,
          ),

          // ===================================================
          // RESPONSABLE
          // ===================================================

          _SectionCard(
            title: 'Responsable',
            icon: Icons.medical_services_outlined,
            children: [
              _DetailRow(
                label: 'Responsable',
                value: _vaccine.responsible.trim().isEmpty
                    ? 'Sin especificar'
                    : _vaccine.responsible,
              ),
            ],
          ),

          const SizedBox(
            height: 16,
          ),

          // ===================================================
          // OBSERVACIONES
          // ===================================================

          _SectionCard(
            title: 'Observaciones',
            icon: Icons.notes_outlined,
            children: [
              Text(
                _vaccine.observations.trim().isEmpty
                    ? 'Sin observaciones.'
                    : _vaccine.observations,
              ),
            ],
          ),

          const SizedBox(
            height: 24,
          ),

          // ===================================================
          // BOTONES
          // ===================================================

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isDeleting ? null : _editVaccine,
                  icon: const Icon(
                    Icons.edit_outlined,
                  ),
                  label: const Text(
                    'Editar',
                  ),
                ),
              ),
              const SizedBox(
                width: 12,
              ),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isDeleting ? null : _deleteVaccine,
                  icon: _isDeleting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.delete_outline,
                        ),
                  label: Text(
                    _isDeleting ? 'Eliminando...' : 'Eliminar',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ===========================================================
// SECCIÓN
// ===========================================================

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(
          16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 21,
                ),
                const SizedBox(
                  width: 8,
                ),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 14,
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

// ===========================================================
// FILA DE DETALLE
// ===========================================================

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
              ),
            ),
          ),
          const SizedBox(
            width: 12,
          ),
          Expanded(
            flex: 5,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
