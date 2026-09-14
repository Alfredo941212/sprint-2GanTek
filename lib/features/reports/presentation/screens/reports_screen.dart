import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:gantek/core/session/session_manager.dart';

import '../../data/models/report_summary.dart';
import '../../data/repositories/report_repository.dart';
import 'package:printing/printing.dart';

import '../../data/services/report_pdf_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final ReportRepository _repository = ReportRepository();
  final ReportPdfService _pdfService = ReportPdfService();

  DateTimeRange? _selectedRange;

  bool _isLoading = true;
  String? _errorMessage;

  ReportSummary _summary = ReportSummary.empty();

  List<LotProductionReport> _lotProduction = <LotProductionReport>[];

  List<RecentMilkingReport> _recentMilkings = <RecentMilkingReport>[];

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final int? userId = SessionManager.instance.currentUserId;

      if (userId == null) {
        throw StateError(
          'No hay una sesión activa.',
        );
      }

      final ReportSummary summary = await _repository.getSummary(
        userId: userId,
        startDate: _selectedRange?.start,
        endDate: _selectedRange?.end,
      );

      final List<LotProductionReport> lotProduction =
          await _repository.getProductionByLot(
        userId: userId,
        startDate: _selectedRange?.start,
        endDate: _selectedRange?.end,
      );

      final List<RecentMilkingReport> recentMilkings =
          await _repository.getRecentMilkings(
        userId: userId,
        startDate: _selectedRange?.start,
        endDate: _selectedRange?.end,
        limit: 10,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _summary = summary;
        _lotProduction = lotProduction;
        _recentMilkings = recentMilkings;
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint(
        'Error cargando reportes: $error',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _summary = ReportSummary.empty();

        _lotProduction = <LotProductionReport>[];

        _recentMilkings = <RecentMilkingReport>[];

        _errorMessage = error.toString();

        _isLoading = false;
      });
    }
  }

  Future<void> _selectDateRange() async {
    final DateTime now = DateTime.now();

    final DateTimeRange? range = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedRange,
      firstDate: DateTime(2020),
      lastDate: now,
      helpText: 'Seleccionar periodo',
      cancelText: 'Cancelar',
      confirmText: 'Aplicar',
      saveText: 'Aplicar',
    );

    if (range == null) {
      return;
    }

    setState(() {
      _selectedRange = range;
    });

    await _loadReports();
  }

  Future<void> _clearDateRange() async {
    setState(() {
      _selectedRange = null;
    });

    await _loadReports();
  }

  String _formatDate(
    DateTime date,
  ) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String get _periodText {
    if (_selectedRange == null) {
      return 'Mes actual';
    }

    return '${_formatDate(_selectedRange!.start)}'
        ' – '
        '${_formatDate(_selectedRange!.end)}';
  }

  Future<void> _generatePdf() async {
    try {
      final bytes = await _pdfService.generateReport(
        summary: _summary,
        lotProduction: _lotProduction,
        recentMilkings: _recentMilkings,
        periodText: _periodText,
      );

      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: 'reporte_gantek.pdf',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No fue posible generar el PDF: $error',
          ),
        ),
      );
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Reportes',
        ),
        actions: [
          IconButton(
            tooltip: 'Generar PDF',
            onPressed: _isLoading ? null : _generatePdf,
            icon: const Icon(
              Icons.picture_as_pdf_outlined,
            ),
          ),
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _isLoading ? null : _loadReports,
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

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
              ),
              const SizedBox(
                height: 16,
              ),
              const Text(
                'No fue posible generar los reportes.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(
                height: 8,
              ),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(
                height: 20,
              ),
              ElevatedButton.icon(
                onPressed: _loadReports,
                icon: const Icon(
                  Icons.refresh,
                ),
                label: const Text(
                  'Intentar de nuevo',
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadReports,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _PeriodCard(
            periodText: _periodText,
            hasFilter: _selectedRange != null,
            onSelectPeriod: _selectDateRange,
            onClearPeriod: _clearDateRange,
          ),

          const SizedBox(
            height: 20,
          ),

          // =================================================
          // GANADO
          // =================================================

          const _SectionTitle(
            title: 'Resumen del ganado',
            icon: Icons.pets,
          ),

          const SizedBox(
            height: 10,
          ),

          _ResponsiveSummaryGrid(
            children: [
              _SummaryCard(
                title: 'Registrado',
                value: '${_summary.totalCattle}',
                description: 'Animales activos',
                icon: const FaIcon(
                  FontAwesomeIcons.cow,
                  size: 26,
                ),
              ),
              _SummaryCard(
                title: 'En producción',
                value: '${_summary.productiveCattle}',
                description: 'Vacas produciendo leche',
                icon: const Icon(
                  Icons.water_drop_outlined,
                ),
              ),
              _SummaryCard(
                title: 'Secas',
                value: '${_summary.dryCattle}',
                description: 'Vacas fuera de producción',
                icon: const Icon(
                  Icons.pause_circle_outline,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 24,
          ),

          // =================================================
          // PRODUCCIÓN
          // =================================================

          const _SectionTitle(
            title: 'Producción de leche',
            icon: Icons.water_drop_outlined,
          ),

          const SizedBox(
            height: 10,
          ),

          _ResponsiveSummaryGrid(
            children: [
              _SummaryCard(
                title: 'Producción total',
                value: '${_summary.totalMilkProduction.toStringAsFixed(1)} L',
                description: 'Litros del periodo',
                icon: const Icon(
                  Icons.water_drop,
                ),
              ),
              _SummaryCard(
                title: 'Promedio diario',
                value:
                    '${_summary.averageDailyProduction.toStringAsFixed(1)} L',
                description: 'Promedio por día con producción',
                icon: const Icon(
                  Icons.calendar_today_outlined,
                ),
              ),
              _SummaryCard(
                title: 'Promedio por vaca',
                value:
                    '${_summary.averageProductionPerCow.toStringAsFixed(1)} L',
                description: 'Producción promedio',
                icon: const FaIcon(
                  FontAwesomeIcons.cow,
                  size: 24,
                ),
              ),
              _SummaryCard(
                title: 'Ordeñas',
                value: '${_summary.totalMilkings}',
                description: 'Registros de ordeña',
                icon: const Icon(
                  Icons.format_list_numbered,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 24,
          ),

          // =================================================
          // PRODUCCIÓN POR LOTE
          // =================================================

          const _SectionTitle(
            title: 'Producción por lote',
            icon: Icons.grid_view_outlined,
          ),

          const SizedBox(
            height: 10,
          ),

          if (_lotProduction.isEmpty)
            const _EmptyCard(
              icon: Icons.grid_view_outlined,
              message: 'No hay lotes registrados.',
            )
          else
            ..._lotProduction.map(
              (
                LotProductionReport lot,
              ) {
                return _LotProductionCard(
                  lot: lot,
                );
              },
            ),

          const SizedBox(
            height: 24,
          ),

          // =================================================
          // SANIDAD
          // =================================================

          const _SectionTitle(
            title: 'Control sanitario',
            icon: Icons.vaccines_outlined,
          ),

          const SizedBox(
            height: 10,
          ),

          _ResponsiveSummaryGrid(
            children: [
              _SummaryCard(
                title: 'Aplicadas',
                value: '${_summary.appliedVaccines}',
                description: 'Vacunas registradas',
                icon: const Icon(
                  Icons.vaccines,
                ),
              ),
              _SummaryCard(
                title: 'Próximas',
                value: '${_summary.upcomingVaccines}',
                description: 'Próximos 30 días',
                icon: const Icon(
                  Icons.event_available_outlined,
                ),
              ),
              _SummaryCard(
                title: 'Vencidas',
                value: '${_summary.overdueVaccines}',
                description: 'Requieren atención',
                icon: const Icon(
                  Icons.warning_amber_rounded,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 24,
          ),

          // =================================================
          // ALERTAS
          // =================================================

          const _SectionTitle(
            title: 'Alertas',
            icon: Icons.notifications_active_outlined,
          ),

          const SizedBox(
            height: 10,
          ),

          _ResponsiveSummaryGrid(
            children: [
              _SummaryCard(
                title: 'Baja producción',
                value: '${_summary.lowProductionAlerts}',
                description: 'Vacas debajo del mínimo',
                icon: const Icon(
                  Icons.trending_down,
                ),
              ),
              _SummaryCard(
                title: 'Alertas sanitarias',
                value:
                    '${_summary.upcomingVaccines + _summary.overdueVaccines}',
                description: '${_summary.upcomingVaccines} próximas · '
                    '${_summary.overdueVaccines} vencidas',
                icon: const Icon(
                  Icons.health_and_safety_outlined,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 24,
          ),

          // =================================================
          // ORDEÑAS RECIENTES
          // =================================================

          const _SectionTitle(
            title: 'Ordeñas recientes',
            icon: Icons.history,
          ),

          const SizedBox(
            height: 10,
          ),

          if (_recentMilkings.isEmpty)
            const _EmptyCard(
              icon: Icons.water_drop_outlined,
              message: 'No hay ordeñas registradas en el periodo.',
            )
          else
            ..._recentMilkings.map(
              (
                RecentMilkingReport milking,
              ) {
                return _RecentMilkingCard(
                  milking: milking,
                  formatDate: _formatDate,
                );
              },
            ),

          const SizedBox(
            height: 30,
          ),
        ],
      ),
    );
  }
}

// ===========================================================
// PERIODO
// ===========================================================

class _PeriodCard extends StatelessWidget {
  const _PeriodCard({
    required this.periodText,
    required this.hasFilter,
    required this.onSelectPeriod,
    required this.onClearPeriod,
  });

  final String periodText;
  final bool hasFilter;
  final VoidCallback onSelectPeriod;
  final VoidCallback onClearPeriod;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const CircleAvatar(
              child: Icon(
                Icons.date_range,
              ),
            ),
            const SizedBox(
              width: 14,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Periodo del reporte',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(
                    height: 4,
                  ),
                  Text(
                    periodText,
                  ),
                ],
              ),
            ),
            if (hasFilter)
              IconButton(
                tooltip: 'Quitar filtro',
                onPressed: onClearPeriod,
                icon: const Icon(
                  Icons.close,
                ),
              ),
            IconButton(
              tooltip: 'Seleccionar periodo',
              onPressed: onSelectPeriod,
              icon: const Icon(
                Icons.calendar_month,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================
// TÍTULO
// ===========================================================

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.icon,
  });

  final String title;
  final IconData icon;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Row(
      children: [
        Icon(
          icon,
        ),
        const SizedBox(
          width: 8,
        ),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
      ],
    );
  }
}

// ===========================================================
// GRID
// ===========================================================

class _ResponsiveSummaryGrid extends StatelessWidget {
  const _ResponsiveSummaryGrid({
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(
    BuildContext context,
  ) {
    return LayoutBuilder(
      builder: (
        BuildContext context,
        BoxConstraints constraints,
      ) {
        final int columns = constraints.maxWidth >= 700 ? 4 : 2;

        final double itemWidth =
            (constraints.maxWidth - ((columns - 1) * 12)) / columns;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: children.map(
            (
              Widget child,
            ) {
              return SizedBox(
                width: itemWidth,
                child: child,
              );
            },
          ).toList(),
        );
      },
    );
  }
}

// ===========================================================
// TARJETA DE RESUMEN
// ===========================================================

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.description,
    required this.icon,
  });

  final String title;
  final String value;
  final String description;
  final Widget icon;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            icon,
            const SizedBox(
              height: 12,
            ),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(
              height: 4,
            ),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(
              height: 2,
            ),
            Text(
              description,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================
// PRODUCCIÓN POR LOTE
// ===========================================================

class _LotProductionCard extends StatelessWidget {
  const _LotProductionCard({
    required this.lot,
  });

  final LotProductionReport lot;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Card(
      margin: const EdgeInsets.only(
        bottom: 10,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        leading: const CircleAvatar(
          child: Icon(
            Icons.grid_view_outlined,
          ),
        ),
        title: Text(
          lot.lotName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: const Text(
          'Producción acumulada',
        ),
        trailing: Text(
          '${lot.totalLiters.toStringAsFixed(1)} L',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ),
    );
  }
}

// ===========================================================
// ORDEÑA RECIENTE
// ===========================================================

class _RecentMilkingCard extends StatelessWidget {
  const _RecentMilkingCard({
    required this.milking,
    required this.formatDate,
  });

  final RecentMilkingReport milking;

  final String Function(
    DateTime,
  ) formatDate;

  @override
  Widget build(
    BuildContext context,
  ) {
    final String cattleTitle = milking.cattleName?.trim().isNotEmpty == true
        ? '${milking.cattleName} · '
            'Arete ${milking.cattleCode}'
        : 'Arete ${milking.cattleCode}';

    final String shift =
        milking.shift?.trim().isNotEmpty == true ? milking.shift! : 'Sin turno';

    return Card(
      margin: const EdgeInsets.only(
        bottom: 10,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        leading: const CircleAvatar(
          child: Icon(
            Icons.water_drop_outlined,
          ),
        ),
        title: Text(
          cattleTitle,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          '${milking.lotName}\n'
          '${formatDate(milking.date)} · '
          '$shift · '
          'Ordeña ${milking.milkingNumber}',
        ),
        isThreeLine: true,
        trailing: Text(
          '${milking.liters.toStringAsFixed(1)} L',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ),
    );
  }
}

// ===========================================================
// VACÍO
// ===========================================================

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              icon,
              size: 48,
            ),
            const SizedBox(
              height: 12,
            ),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
