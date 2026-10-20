import 'package:flutter/material.dart';

import '../../data/repositories/milking_session_repository.dart';

class MilkingHistoryScreen extends StatefulWidget {
  const MilkingHistoryScreen({
    super.key,
  });

  @override
  State<MilkingHistoryScreen> createState() => _MilkingHistoryScreenState();
}

class _MilkingHistoryScreenState extends State<MilkingHistoryScreen> {
  final MilkingSessionRepository _repository = MilkingSessionRepository();

  List<Map<String, dynamic>> _sessions = [];

  bool _isLoading = true;

  String? _error;

  @override
  void initState() {
    super.initState();

    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final sessions = await _repository.getHistorySessions();

      if (!mounted) {
        return;
      }

      setState(() {
        _sessions = sessions;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _formatDateString(String date) {
    final parsed = DateTime.tryParse(date);

    if (parsed == null) {
      return date;
    }

    final day = parsed.day.toString().padLeft(2, '0');

    final month = parsed.month.toString().padLeft(2, '0');

    return '$day/$month/${parsed.year}';
  }

  double _averagePerCow(
    Map<String, dynamic> session,
  ) {
    final int cattleCount = (session['cattle_count'] as num?)?.toInt() ?? 0;

    final double? totalLiters = (session['total_liters'] as num?)?.toDouble();

    if (cattleCount <= 0 || totalLiters == null) {
      return 0;
    }

    return totalLiters / cattleCount;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Historial de jornadas',
        ),
        actions: [
          IconButton(
            onPressed: _loadHistory,
            icon: const Icon(
              Icons.refresh,
            ),
          ),
        ],
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
              const SizedBox(
                height: 12,
              ),
              Text(
                _error!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(
                height: 16,
              ),
              FilledButton(
                onPressed: _loadHistory,
                child: const Text(
                  'Reintentar',
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_sessions.isEmpty) {
      return const Center(
        child: Text(
          'Todavía no hay jornadas finalizadas.',
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _sessions.length,
        itemBuilder: (
          context,
          index,
        ) {
          final session = _sessions[index];

          final average = _averagePerCow(session);

          final String date = session['date']?.toString() ?? '';

          final String groupName = session['group_name']?.toString() ?? 'Grupo';

          final int cattleCount =
              (session['cattle_count'] as num?)?.toInt() ?? 0;

          final double totalLiters =
              (session['total_liters'] as num?)?.toDouble() ?? 0;

          final int durationMinutes =
              (session['duration_minutes'] as num?)?.toInt() ?? 0;

          final String observations = session['observations']?.toString() ?? '';

          return Card(
            margin: const EdgeInsets.only(
              bottom: 12,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatDateString(date),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  Text(
                    groupName,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Vacas: $cattleCount',
                  ),
                  Text(
                    'Producción: ${totalLiters.toStringAsFixed(1)} L',
                  ),
                  Text(
                    'Duración: $durationMinutes min',
                  ),
                  Text(
                    'Promedio: ${average.toStringAsFixed(1)} L/vaca',
                  ),
                  if (observations.trim().isNotEmpty) ...[
                    const SizedBox(
                      height: 8,
                    ),
                    Text(
                      'Observaciones: $observations',
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
