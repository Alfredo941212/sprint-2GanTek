import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:gantek/core/session/session_manager.dart';

import '../../data/models/report_summary.dart';
import '../../data/repositories/report_repository.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final ReportRepository _repository = ReportRepository();

  DateTimeRange? _selectedRange;

  bool _isLoading = true;
  String? _errorMessage;

  ReportSummary _summary = ReportSummary.empty();

  List<RecentSaleReport> _recentSales = <RecentSaleReport>[];

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

      debugPrint(
        'Cargando reportes para user_id: $userId',
      );

      final ReportSummary summary = await _repository.getSummary(
        userId: userId,
        startDate: _selectedRange?.start,
        endDate: _selectedRange?.end,
      );

      final List<RecentSaleReport> recentSales =
          await _repository.getRecentSales(
        userId: userId,
        startDate: _selectedRange?.start,
        endDate: _selectedRange?.end,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _summary = summary;
        _recentSales = recentSales;
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

        _recentSales = <RecentSaleReport>[];

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

  String _formatMoney(
    double value,
  ) {
    final String valueText = value.toStringAsFixed(2);

    final List<String> parts = valueText.split('.');

    final String integerPart = parts.first;

    final String decimalPart = parts.last;

    final StringBuffer formatted = StringBuffer();

    for (int index = 0; index < integerPart.length; index++) {
      final int positionFromEnd = integerPart.length - index;

      formatted.write(
        integerPart[index],
      );

      if (positionFromEnd > 1 && positionFromEnd % 3 == 1) {
        formatted.write(',');
      }
    }

    return '\$${formatted.toString()}.$decimalPart MXN';
  }

  String get _periodText {
    if (_selectedRange == null) {
      return 'Todos los registros';
    }

    return '${_formatDate(_selectedRange!.start)}'
        ' – '
        '${_formatDate(_selectedRange!.end)}';
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes'),
        actions: [
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
        padding: const EdgeInsets.all(16),
        children: [
          _PeriodCard(
            periodText: _periodText,
            hasFilter: _selectedRange != null,
            onSelectPeriod: _selectDateRange,
            onClearPeriod: _clearDateRange,
          ),
          const SizedBox(
            height: 18,
          ),
          const _SectionTitle(
            title: 'Resumen del animal',
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
                description: 'Total de animales',
                icon: const FaIcon(
                  FontAwesomeIcons.cow,
                  size: 26,
                ),
              ),
              _SummaryCard(
                title: 'Disponible',
                value: '${_summary.availableCattle}',
                description: 'Animales no vendidos',
                icon: const Icon(
                  Icons.check_circle_outline,
                ),
              ),
              _SummaryCard(
                title: 'Vendido',
                value: '${_summary.soldCattle}',
                description: 'Animales vendidos',
                icon: const Icon(
                  Icons.sell_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 22,
          ),
          const _SectionTitle(
            title: 'Resumen de ventas',
            icon: Icons.point_of_sale,
          ),
          const SizedBox(
            height: 10,
          ),
          _ResponsiveSummaryGrid(
            children: [
              _SummaryCard(
                title: 'Ventas',
                value: '${_summary.completedSales}',
                description: 'Ventas completadas',
                icon: const Icon(
                  Icons.receipt_long_outlined,
                ),
              ),
              _SummaryCard(
                title: 'Ingresos',
                value: _formatMoney(
                  _summary.totalSalesAmount,
                ),
                description: 'Monto total vendido',
                icon: const Icon(
                  Icons.attach_money,
                ),
              ),
              _SummaryCard(
                title: 'Peso vendido',
                value: '${_summary.totalSoldWeight.toStringAsFixed(1)} kg',
                description: 'Peso acumulado',
                icon: const Icon(
                  Icons.monitor_weight_outlined,
                ),
              ),
              _SummaryCard(
                title: 'Precio promedio',
                value: '\$${_summary.averagePricePerKg.toStringAsFixed(2)}',
                description: 'Promedio por kilogramo',
                icon: const Icon(
                  Icons.trending_up,
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 22,
          ),
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
                description: 'En los próximos 30 días',
                icon: const Icon(
                  Icons.event_available_outlined,
                ),
              ),
              _SummaryCard(
                title: 'Vencidas',
                value: '${_summary.overdueVaccines}',
                description: 'Requieren atención',
                icon: const Icon(
                  Icons.warning_amber,
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 24,
          ),
          const _SectionTitle(
            title: 'Ventas recientes',
            icon: Icons.history,
          ),
          const SizedBox(
            height: 10,
          ),
          if (_recentSales.isEmpty)
            const _EmptySalesCard()
          else
            ..._recentSales.map(
              (
                RecentSaleReport sale,
              ) {
                return _RecentSaleCard(
                  sale: sale,
                  formatDate: _formatDate,
                  formatMoney: _formatMoney,
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
                  Text(periodText),
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
        Icon(icon),
        const SizedBox(
          width: 8,
        ),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ],
    );
  }
}

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

class _RecentSaleCard extends StatelessWidget {
  const _RecentSaleCard({
    required this.sale,
    required this.formatDate,
    required this.formatMoney,
  });

  final RecentSaleReport sale;
  final String Function(
    DateTime,
  ) formatDate;

  final String Function(
    double,
  ) formatMoney;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Card(
      margin: const EdgeInsets.only(
        bottom: 10,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        leading: const CircleAvatar(
          child: Icon(
            Icons.sell_outlined,
          ),
        ),
        title: Text(
          'Arete ${sale.cattleCode}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          'Comprador: ${sale.buyerName}\n'
          'Fecha: ${formatDate(sale.saleDate)}\n'
          '${sale.saleWeight.toStringAsFixed(1)} kg × '
          '\$${sale.pricePerKg.toStringAsFixed(2)}',
        ),
        isThreeLine: true,
        trailing: Text(
          formatMoney(sale.total),
          textAlign: TextAlign.end,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _EmptySalesCard extends StatelessWidget {
  const _EmptySalesCard();

  @override
  Widget build(
    BuildContext context,
  ) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 52,
            ),
            SizedBox(
              height: 12,
            ),
            Text(
              'No hay ventas registradas en el periodo seleccionado.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
