import 'package:flutter/material.dart';

import '../../data/models/production_alert.dart';
import '../../data/repositories/production_alert_repository.dart';

class ProductionAlertsScreen extends StatefulWidget {
  const ProductionAlertsScreen({super.key});

  @override
  State<ProductionAlertsScreen> createState() => _ProductionAlertsScreenState();
}

class _ProductionAlertsScreenState extends State<ProductionAlertsScreen> {
  final ProductionAlertRepository _repository = ProductionAlertRepository();

  bool _isLoading = true;
  String? _errorMessage;

  List<ProductionAlert> _minimumAlerts = [];
  List<ProductionAlert> _trendAlerts = [];

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final List<ProductionAlert> minimumAlerts =
          await _repository.getPreviousDayAlerts();

      final List<ProductionAlert> trendAlerts =
          await _repository.getTrendAlerts();

      if (!mounted) {
        return;
      }

      setState(() {
        _minimumAlerts = minimumAlerts;
        _trendAlerts = trendAlerts;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'No fue posible cargar las alertas.';
        _isLoading = false;
      });

      debugPrint(
        'Error cargando alertas: $error',
      );
    }
  }

  String _formatDate(
    DateTime date,
  ) {
    final String day = date.day.toString().padLeft(
          2,
          '0',
        );

    final String month = date.month.toString().padLeft(
          2,
          '0',
        );

    return '$day/$month/${date.year}';
  }

  String _typeLabel(
    ProductionAlert alert,
  ) {
    switch (alert.type) {
      case ProductionAlertType.cow:
        return 'Vaca';

      case ProductionAlertType.lot:
        return 'Lote';

      case ProductionAlertType.trend:
        return 'Tendencia';
    }
  }

  IconData _typeIcon(
    ProductionAlert alert,
  ) {
    switch (alert.type) {
      case ProductionAlertType.cow:
        return Icons.pets_outlined;

      case ProductionAlertType.lot:
        return Icons.inventory_2_outlined;

      case ProductionAlertType.trend:
        return Icons.trending_down;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Alertas de producción',
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _isLoading ? null : _loadAlerts,
            icon: const Icon(
              Icons.refresh,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAlerts,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          const Icon(
            Icons.error_outline,
            size: 60,
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton(
              onPressed: _loadAlerts,
              child: const Text(
                'Reintentar',
              ),
            ),
          ),
        ],
      );
    }

    final int totalAlerts = _minimumAlerts.length + _trendAlerts.length;

    if (totalAlerts == 0) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          const Icon(
            Icons.check_circle_outline,
            size: 70,
          ),
          const SizedBox(height: 16),
          const Text(
            'Sin alertas de producción',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'No se detectó producción por debajo '
            'del mínimo ni tendencias de disminución '
            'del 20 % o más.',
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    final int cowAlerts = _minimumAlerts
        .where(
          (ProductionAlert alert) => alert.type == ProductionAlertType.cow,
        )
        .length;

    final int lotAlerts = _minimumAlerts
        .where(
          (ProductionAlert alert) => alert.type == ProductionAlertType.lot,
        )
        .length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSummaryCard(
          cowAlerts: cowAlerts,
          lotAlerts: lotAlerts,
          trendAlerts: _trendAlerts.length,
          totalAlerts: totalAlerts,
        ),
        const SizedBox(height: 20),
        _SectionHeader(
          title: 'Producción baja',
          subtitle: 'Evaluación del último día completo',
          icon: Icons.warning_amber_rounded,
          count: _minimumAlerts.length,
        ),
        const SizedBox(height: 10),
        if (_minimumAlerts.isEmpty)
          const _EmptySectionCard(
            message: 'No hay vacas ni lotes por debajo '
                'de su producción mínima.',
          )
        else
          ..._minimumAlerts.map(
            (ProductionAlert alert) {
              return _AlertCard(
                alert: alert,
                typeLabel: _typeLabel(alert),
                icon: _typeIcon(alert),
                formattedDate: _formatDate(alert.date),
                isTrend: false,
              );
            },
          ),
        const SizedBox(height: 20),
        _SectionHeader(
          title: 'Tendencia a la baja',
          subtitle: 'Últimos 3 días vs. 7 días anteriores',
          icon: Icons.trending_down,
          count: _trendAlerts.length,
        ),
        const SizedBox(height: 10),
        if (_trendAlerts.isEmpty)
          const _EmptySectionCard(
            message: 'No se detectaron disminuciones '
                'de producción del 20 % o más.',
          )
        else
          ..._trendAlerts.map(
            (ProductionAlert alert) {
              return _AlertCard(
                alert: alert,
                typeLabel: 'Tendencia',
                icon: Icons.trending_down,
                formattedDate: _formatDate(alert.date),
                isTrend: true,
              );
            },
          ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required int cowAlerts,
    required int lotAlerts,
    required int trendAlerts,
    required int totalAlerts,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Resumen',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            _SummaryRow(
              label: 'Vacas bajo mínimo',
              value: cowAlerts,
              icon: Icons.pets_outlined,
            ),
            const SizedBox(height: 10),
            _SummaryRow(
              label: 'Lotes bajo mínimo',
              value: lotAlerts,
              icon: Icons.inventory_2_outlined,
            ),
            const SizedBox(height: 10),
            _SummaryRow(
              label: 'Tendencias a la baja',
              value: trendAlerts,
              icon: Icons.trending_down,
            ),
            const Divider(height: 24),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Total de alertas',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '$totalAlerts',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final int count;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 26,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 5,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.grey.shade200,
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;

  const _SummaryRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label),
        ),
        Text(
          '$value',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _EmptySectionCard extends StatelessWidget {
  final String message;

  const _EmptySectionCard({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const Icon(
              Icons.check_circle_outline,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final ProductionAlert alert;
  final String typeLabel;
  final IconData icon;
  final String formattedDate;
  final bool isTrend;

  const _AlertCard({
    required this.alert,
    required this.typeLabel,
    required this.icon,
    required this.formattedDate,
    required this.isTrend,
  });

  @override
  Widget build(BuildContext context) {
    final double difference = alert.expectedProduction > alert.actualProduction
        ? alert.expectedProduction - alert.actualProduction
        : 0;

    final double percentage = alert.expectedProduction > 0
        ? alert.actualProduction / alert.expectedProduction
        : 0;

    final double decreasePercentage = alert.expectedProduction > 0
        ? ((alert.expectedProduction - alert.actualProduction) /
                alert.expectedProduction) *
            100
        : 0;

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
              children: [
                CircleAvatar(
                  child: Icon(icon),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alert.title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(
                        height: 2,
                      ),
                      Text(
                        typeLabel,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isTrend ? Icons.trending_down : Icons.warning_amber_rounded,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              alert.message,
            ),
            const SizedBox(height: 14),
            LinearProgressIndicator(
              value: percentage.clamp(
                0.0,
                1.0,
              ),
            ),
            const SizedBox(height: 10),
            if (isTrend)
              Row(
                children: [
                  Expanded(
                    child: _ValueItem(
                      label: 'Prom. anterior',
                      value: '${alert.expectedProduction.toStringAsFixed(1)} L',
                    ),
                  ),
                  Expanded(
                    child: _ValueItem(
                      label: 'Prom. reciente',
                      value: '${alert.actualProduction.toStringAsFixed(1)} L',
                    ),
                  ),
                  Expanded(
                    child: _ValueItem(
                      label: 'Disminución',
                      value: '${decreasePercentage.toStringAsFixed(1)} %',
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _ValueItem(
                      label: 'Real',
                      value: '${alert.actualProduction.toStringAsFixed(1)} L',
                    ),
                  ),
                  Expanded(
                    child: _ValueItem(
                      label: 'Mínimo',
                      value: '${alert.expectedProduction.toStringAsFixed(1)} L',
                    ),
                  ),
                  Expanded(
                    child: _ValueItem(
                      label: 'Faltaron',
                      value: '${difference.toStringAsFixed(1)} L',
                    ),
                  ),
                ],
              ),
            if (alert.lotName != null) ...[
              const SizedBox(height: 12),
              Text(
                'Lote: ${alert.lotName}',
                style: TextStyle(
                  color: Colors.grey.shade700,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              isTrend
                  ? 'Último día evaluado: '
                      '$formattedDate'
                  : 'Fecha: $formattedDate',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ValueItem extends StatelessWidget {
  final String label;
  final String value;

  const _ValueItem({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}
