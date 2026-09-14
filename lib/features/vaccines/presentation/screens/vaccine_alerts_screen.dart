import 'package:flutter/material.dart';

import '../../data/models/vaccine_record.dart';
import '../../data/repositories/vaccine_repository.dart';
import 'vaccine_detail_screen.dart';

class VaccineAlertsScreen extends StatefulWidget {
  const VaccineAlertsScreen({
    super.key,
  });

  @override
  State<VaccineAlertsScreen> createState() => _VaccineAlertsScreenState();
}

class _VaccineAlertsScreenState extends State<VaccineAlertsScreen> {
  final VaccineRepository _repository = VaccineRepository();

  bool _isLoading = true;

  List<VaccineRecord> _upcomingVaccines = [];
  List<VaccineRecord> _overdueVaccines = [];

  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final List<VaccineRecord> upcoming =
          await _repository.getUpcomingVaccines();

      final List<VaccineRecord> overdue =
          await _repository.getOverdueVaccines();

      if (!mounted) {
        return;
      }

      setState(() {
        _upcomingVaccines = upcoming;
        _overdueVaccines = overdue;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  String _formatDate(
    DateTime date,
  ) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  int _daysUntil(
    DateTime date,
  ) {
    final DateTime now = DateTime.now();

    final DateTime today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final DateTime target = DateTime(
      date.year,
      date.month,
      date.day,
    );

    return target.difference(today).inDays;
  }

  String _getUpcomingText(
    DateTime date,
  ) {
    final int days = _daysUntil(date);

    if (days == 0) {
      return 'Aplicar hoy';
    }

    if (days == 1) {
      return 'Falta 1 día';
    }

    return 'Faltan $days días';
  }

  String _getOverdueText(
    DateTime date,
  ) {
    final int days = _daysUntil(date).abs();

    if (days == 1) {
      return 'Vencida hace 1 día';
    }

    return 'Vencida hace $days días';
  }

  Future<void> _openDetail(
    VaccineRecord vaccine,
  ) async {
    final bool? changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => VaccineDetailScreen(
          vaccine: vaccine,
        ),
      ),
    );

    if (changed == true) {
      await _loadAlerts();
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Alertas de vacunación',
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadAlerts,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return ListView(
        children: const [
          SizedBox(
            height: 250,
          ),
          Center(
            child: CircularProgressIndicator(),
          ),
        ],
      );
    }

    if (_errorMessage != null) {
      return ListView(
        padding: const EdgeInsets.all(
          24,
        ),
        children: [
          const SizedBox(
            height: 120,
          ),
          const Icon(
            Icons.error_outline,
            size: 60,
          ),
          const SizedBox(
            height: 16,
          ),
          const Text(
            'No fue posible cargar las alertas.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(
            height: 8,
          ),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    if (_upcomingVaccines.isEmpty && _overdueVaccines.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(
          24,
        ),
        children: const [
          SizedBox(
            height: 120,
          ),
          Icon(
            Icons.verified_outlined,
            size: 72,
          ),
          SizedBox(
            height: 16,
          ),
          Text(
            'No hay alertas de vacunación.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(
            height: 8,
          ),
          Text(
            'No existen próximas dosis ni '
            'vacunas vencidas.',
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(
        16,
      ),
      children: [
        // ===============================================
        // RESUMEN
        // ===============================================

        Row(
          children: [
            Expanded(
              child: _SummaryBox(
                title: 'Próximas',
                value: '${_upcomingVaccines.length}',
                icon: Icons.schedule,
              ),
            ),
            const SizedBox(
              width: 12,
            ),
            Expanded(
              child: _SummaryBox(
                title: 'Vencidas',
                value: '${_overdueVaccines.length}',
                icon: Icons.warning_amber_rounded,
              ),
            ),
          ],
        ),

        const SizedBox(
          height: 24,
        ),

        // ===============================================
        // VENCIDAS
        // ===============================================

        if (_overdueVaccines.isNotEmpty) ...[
          const Text(
            'Vacunas vencidas',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(
            height: 10,
          ),
          ..._overdueVaccines.map(
            (VaccineRecord vaccine) {
              return _VaccineAlertCard(
                vaccine: vaccine,
                statusText: _getOverdueText(
                  vaccine.nextDoseDate!,
                ),
                isOverdue: true,
                formatDate: _formatDate,
                onTap: () {
                  _openDetail(
                    vaccine,
                  );
                },
              );
            },
          ),
          const SizedBox(
            height: 22,
          ),
        ],

        // ===============================================
        // PRÓXIMAS
        // ===============================================

        if (_upcomingVaccines.isNotEmpty) ...[
          const Text(
            'Próximas dosis',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(
            height: 10,
          ),
          ..._upcomingVaccines.map(
            (VaccineRecord vaccine) {
              return _VaccineAlertCard(
                vaccine: vaccine,
                statusText: _getUpcomingText(
                  vaccine.nextDoseDate!,
                ),
                isOverdue: false,
                formatDate: _formatDate,
                onTap: () {
                  _openDetail(
                    vaccine,
                  );
                },
              );
            },
          ),
        ],

        const SizedBox(
          height: 24,
        ),
      ],
    );
  }
}

class _SummaryBox extends StatelessWidget {
  const _SummaryBox({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

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
          children: [
            Icon(
              icon,
              size: 32,
            ),
            const SizedBox(
              height: 8,
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(
              height: 4,
            ),
            Text(
              title,
            ),
          ],
        ),
      ),
    );
  }
}

class _VaccineAlertCard extends StatelessWidget {
  const _VaccineAlertCard({
    required this.vaccine,
    required this.statusText,
    required this.isOverdue,
    required this.formatDate,
    required this.onTap,
  });

  final VaccineRecord vaccine;
  final String statusText;
  final bool isOverdue;

  final String Function(
    DateTime date,
  ) formatDate;

  final VoidCallback onTap;

  @override
  Widget build(
    BuildContext context,
  ) {
    final DateTime? nextDose = vaccine.nextDoseDate;

    return Card(
      margin: const EdgeInsets.only(
        bottom: 10,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(
          12,
        ),
        child: Padding(
          padding: const EdgeInsets.all(
            14,
          ),
          child: Row(
            children: [
              CircleAvatar(
                child: Icon(
                  isOverdue ? Icons.warning_amber_rounded : Icons.schedule,
                ),
              ),
              const SizedBox(
                width: 14,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vaccine.vaccineName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(
                      height: 4,
                    ),
                    Text(
                      'Animal: ${vaccine.cattleCode}',
                    ),
                    if (nextDose != null)
                      Text(
                        'Próxima dosis: '
                        '${formatDate(nextDose)}',
                      ),
                    const SizedBox(
                      height: 5,
                    ),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isOverdue ? Colors.red : Colors.orange.shade800,
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
    );
  }
}
