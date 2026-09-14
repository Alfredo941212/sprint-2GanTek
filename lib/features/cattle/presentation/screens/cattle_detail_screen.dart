import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../core/theme/app_colors.dart';

import '../../data/models/cattle.dart';
import '../../data/repositories/cattle_repository.dart';

import '../../../milk_production/data/models/milking_record.dart';
import '../../../milk_production/data/repositories/milking_repository.dart';

import 'register_cattle_screen.dart';

class CattleDetailScreen extends StatefulWidget {
  const CattleDetailScreen({
    super.key,
    required this.cattle,
    required this.lotName,
  });

  final Cattle cattle;
  final String lotName;

  @override
  State<CattleDetailScreen> createState() => _CattleDetailScreenState();
}

class _CattleDetailScreenState extends State<CattleDetailScreen> {
  final CattleRepository _repository = CattleRepository();

  final MilkingRepository _milkingRepository = MilkingRepository();

  late Cattle _cattle;

  bool _isDeleting = false;
  bool _isLoadingProduction = true;

  double _todayProduction = 0;
  double _monthlyProduction = 0;
  double _monthlyAverage = 0;

  List<MilkingRecord> _todayMilkings = [];
  List<MilkingRecord> _recentMilkings = [];

  Map<int, double> _dailyProduction = {};

  @override
  void initState() {
    super.initState();

    _cattle = widget.cattle;

    _loadProductionData();
  }

  // =========================================================
  // CARGAR PRODUCCIÓN
  // =========================================================

  Future<void> _loadProductionData() async {
    final int? cattleId = _cattle.id;

    if (cattleId == null) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingProduction = false;
      });

      return;
    }

    try {
      final DateTime now = DateTime.now();

      final double todayProduction =
          await _milkingRepository.getDailyProductionByCattle(
        cattleId: cattleId,
        date: now,
      );

      final double monthlyProduction =
          await _milkingRepository.getMonthlyProductionByCattle(
        cattleId: cattleId,
        month: now,
      );

      final List<MilkingRecord> todayMilkings =
          await _milkingRepository.getMilkingsByCattleAndDate(
        cattleId: cattleId,
        date: now,
      );

      final Map<int, double> dailyProduction =
          await _milkingRepository.getDailyProductionForCattleInMonth(
        cattleId: cattleId,
        month: now,
      );

      final int daysWithProduction = dailyProduction.values
          .where(
            (double liters) => liters > 0,
          )
          .length;

      final double monthlyAverage =
          daysWithProduction > 0 ? monthlyProduction / daysWithProduction : 0;

      final List<MilkingRecord> recentMilkings =
          await _milkingRepository.getRecentMilkingsByCattle(
        cattleId: cattleId,
        limit: 10,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _todayProduction = todayProduction;

        _monthlyProduction = monthlyProduction;

        _monthlyAverage = monthlyAverage;

        _todayMilkings = todayMilkings;

        _recentMilkings = recentMilkings;

        _dailyProduction = dailyProduction;

        _isLoadingProduction = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingProduction = false;
      });

      debugPrint(
        'Error cargando producción de la vaca: $error',
      );
    }
  }

  // =========================================================
  // EDITAR
  // =========================================================

  Future<void> _editCattle() async {
    final bool? updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RegisterCattleScreen(
          cattle: _cattle,
        ),
      ),
    );

    if (updated != true) {
      return;
    }

    final int? cattleId = _cattle.id;

    if (cattleId == null) {
      return;
    }

    try {
      final Cattle? updatedCattle = await _repository.getCattleById(
        cattleId,
      );

      if (!mounted) {
        return;
      }

      if (updatedCattle != null) {
        setState(() {
          _cattle = updatedCattle;
        });
      }

      await _loadProductionData();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'Animal actualizado correctamente.',
          ),
        ),
      );
    } catch (error) {
      debugPrint(
        'Error actualizando detalle: $error',
      );
    }
  }

  // =========================================================
  // ELIMINAR
  // =========================================================

  Future<void> _deleteCattle() async {
    final int? cattleId = _cattle.id;

    if (cattleId == null) {
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (
        BuildContext dialogContext,
      ) {
        return AlertDialog(
          title: const Text(
            'Eliminar animal',
          ),
          content: Text(
            '¿Deseas eliminar a '
            '${_displayName()}?',
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
      await _repository.deleteCattle(
        cattleId,
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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'No fue posible eliminar el animal.',
          ),
        ),
      );

      debugPrint(
        'Error eliminando ganado: $error',
      );
    }
  }

  // =========================================================
  // TEXTOS
  // =========================================================

  String _displayName() {
    if (_cattle.name.trim().isNotEmpty) {
      return _cattle.name;
    }

    return 'Arete ${_cattle.code}';
  }

  String _dateText(
    DateTime? date,
  ) {
    if (date == null) {
      return 'Sin registro';
    }

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

  String _formatMilkingDate(
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

  String _weightText() {
    final double? weight = _cattle.initialWeight;

    if (weight == null) {
      return 'Sin registro';
    }

    return '${weight.toStringAsFixed(1)} kg';
  }

  // =========================================================
  // COLOR ESTADO PRODUCTIVO
  // =========================================================

  Color _productiveStatusColor() {
    switch (_cattle.productiveStatus) {
      case 'En producción':
        return AppColors.success;

      case 'Seca':
        return Colors.orange.shade700;

      case 'Gestante':
        return Colors.blue.shade700;

      default:
        return Colors.grey.shade700;
    }
  }

  Color _productiveStatusBackground() {
    switch (_cattle.productiveStatus) {
      case 'En producción':
        return AppColors.successSoft;

      case 'Seca':
        return Colors.orange.shade50;

      case 'Gestante':
        return Colors.blue.shade50;

      default:
        return Colors.grey.shade200;
    }
  }

  // =========================================================
  // GRÁFICA DE PRODUCCIÓN
  // =========================================================

  LineChartData _buildProductionChart() {
    final List<int> days = _dailyProduction.keys.toList()..sort();

    final List<FlSpot> spots = days.map(
      (int day) {
        return FlSpot(
          day.toDouble(),
          _dailyProduction[day] ?? 0,
        );
      },
    ).toList();

    double maximumProduction = 0;

    for (final double liters in _dailyProduction.values) {
      if (liters > maximumProduction) {
        maximumProduction = liters;
      }
    }

    final double maxY = maximumProduction < 5 ? 5 : maximumProduction + 2;

    return LineChartData(
      minX: 1,
      maxX: 31,
      minY: 0,
      maxY: maxY,
      gridData: const FlGridData(
        show: true,
      ),
      borderData: FlBorderData(
        show: false,
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(
          sideTitles: SideTitles(
            showTitles: false,
          ),
        ),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(
            showTitles: false,
          ),
        ),
        leftTitles: const AxisTitles(
          axisNameWidget: Text(
            'Litros',
          ),
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
          ),
        ),
        bottomTitles: AxisTitles(
          axisNameWidget: const Text(
            'Día del mes',
          ),
          sideTitles: SideTitles(
            showTitles: true,
            interval: 5,
            reservedSize: 32,
            getTitlesWidget: (
              double value,
              TitleMeta meta,
            ) {
              final int day = value.toInt();

              if (day != 1 &&
                  day != 5 &&
                  day != 10 &&
                  day != 15 &&
                  day != 20 &&
                  day != 25 &&
                  day != 30) {
                return const SizedBox.shrink();
              }

              return SideTitleWidget(
                meta: meta,
                child: Text(
                  '$day',
                  style: const TextStyle(
                    fontSize: 11,
                  ),
                ),
              );
            },
          ),
        ),
      ),
      lineTouchData: LineTouchData(
        enabled: true,
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (
            List<LineBarSpot> touchedSpots,
          ) {
            return touchedSpots.map(
              (
                LineBarSpot spot,
              ) {
                return LineTooltipItem(
                  'Día ${spot.x.toInt()}\n'
                  '${spot.y.toStringAsFixed(1)} L',
                  const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ).toList();
          },
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          barWidth: 3,
          dotData: const FlDotData(
            show: true,
          ),
          belowBarData: BarAreaData(
            show: true,
          ),
        ),
      ],
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
          'Detalle del animal',
        ),
        actions: [
          IconButton(
            tooltip: 'Editar',
            onPressed: _isDeleting ? null : _editCattle,
            icon: const Icon(
              Icons.edit_outlined,
            ),
          ),
          IconButton(
            tooltip: 'Eliminar',
            onPressed: _isDeleting ? null : _deleteCattle,
            icon: const Icon(
              Icons.delete_outline,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadProductionData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(
            16,
          ),
          children: [
            // ===============================================
            // FOTO Y NOMBRE
            // ===============================================

            Card(
              child: Padding(
                padding: const EdgeInsets.all(
                  16,
                ),
                child: Column(
                  children: [
                    _CattleDetailImage(
                      imagePath: _cattle.imagePath,
                    ),
                    const SizedBox(
                      height: 14,
                    ),
                    Text(
                      _displayName(),
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(
                      height: 4,
                    ),
                    Text(
                      'Arete: ${_cattle.code}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium,
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        _StatusChip(
                          text: _cattle.productiveStatus,
                          foreground: _productiveStatusColor(),
                          background: _productiveStatusBackground(),
                        ),
                        _StatusChip(
                          text: _cattle.status,
                          foreground: _cattle.status == 'Activo'
                              ? AppColors.success
                              : Colors.grey.shade700,
                          background: _cattle.status == 'Activo'
                              ? AppColors.successSoft
                              : Colors.grey.shade200,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(
              height: 16,
            ),

            // ===============================================
            // INFORMACIÓN GENERAL
            // ===============================================

            _SectionCard(
              title: 'Información general',
              icon: Icons.info_outline,
              children: [
                _DetailRow(
                  label: 'Nombre',
                  value:
                      _cattle.name.trim().isEmpty ? 'Sin nombre' : _cattle.name,
                ),
                _DetailRow(
                  label: 'Arete',
                  value: _cattle.code,
                ),
                _DetailRow(
                  label: 'Sexo',
                  value: _cattle.sex,
                ),
                _DetailRow(
                  label: 'Raza',
                  value: _cattle.breed.trim().isEmpty
                      ? 'Sin especificar'
                      : _cattle.breed,
                ),
                _DetailRow(
                  label: 'Fecha de nacimiento',
                  value: _dateText(
                    _cattle.birthDate,
                  ),
                ),
                _DetailRow(
                  label: 'Fecha de entrada',
                  value: _dateText(
                    _cattle.entryDate,
                  ),
                ),
                _DetailRow(
                  label: 'Peso inicial',
                  value: _weightText(),
                ),
              ],
            ),

            const SizedBox(
              height: 16,
            ),

            // ===============================================
            // INFORMACIÓN PRODUCTIVA
            // ===============================================

            _SectionCard(
              title: 'Información productiva',
              icon: Icons.water_drop_outlined,
              children: [
                _DetailRow(
                  label: 'Lote',
                  value: widget.lotName,
                ),
                _DetailRow(
                  label: 'Estado productivo',
                  value: _cattle.productiveStatus,
                ),
                _DetailRow(
                  label: 'Producción mínima',
                  value:
                      '${_cattle.minimumDailyProduction.toStringAsFixed(1)} L/día',
                ),
                const Divider(
                  height: 28,
                ),
                if (_isLoadingProduction)
                  const Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: 18,
                    ),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  )
                else ...[
                  Row(
                    children: [
                      Expanded(
                        child: _ProductionMetric(
                          label: 'Hoy',
                          value: '${_todayProduction.toStringAsFixed(1)} L',
                          icon: Icons.today_outlined,
                        ),
                      ),
                      Expanded(
                        child: _ProductionMetric(
                          label: 'Este mes',
                          value: '${_monthlyProduction.toStringAsFixed(1)} L',
                          icon: Icons.calendar_month_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: 18,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _ProductionMetric(
                          label: 'Promedio',
                          value: '${_monthlyAverage.toStringAsFixed(1)} L',
                          icon: Icons.analytics_outlined,
                        ),
                      ),
                      Expanded(
                        child: _ProductionMetric(
                          label: 'Ordeñas hoy',
                          value: '${_todayMilkings.length}',
                          icon: Icons.water_drop_outlined,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(
                  height: 12,
                ),
                _DetailRow(
                  label: 'Estado general',
                  value: _cattle.status,
                ),
              ],
            ),

            const SizedBox(
              height: 16,
            ),

            // ===============================================
            // GRÁFICA
            // ===============================================

            _SectionCard(
              title: 'Producción del mes',
              icon: Icons.show_chart,
              children: [
                if (_isLoadingProduction)
                  const Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: 24,
                    ),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_dailyProduction.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: 16,
                    ),
                    child: Text(
                      'Aún no hay producción registrada este mes.',
                    ),
                  )
                else
                  SizedBox(
                    height: 230,
                    child: LineChart(
                      _buildProductionChart(),
                    ),
                  ),
              ],
            ),

            const SizedBox(
              height: 16,
            ),

            // ===============================================
            // ORDEÑAS RECIENTES
            // ===============================================

            _SectionCard(
              title: 'Ordeñas recientes',
              icon: Icons.history,
              children: [
                if (_isLoadingProduction)
                  const Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: 16,
                    ),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_recentMilkings.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: 12,
                    ),
                    child: Text(
                      'Aún no hay ordeñas registradas para esta vaca.',
                    ),
                  )
                else
                  ..._recentMilkings.map(
                    (
                      MilkingRecord record,
                    ) {
                      final String shift =
                          record.shift?.trim().isNotEmpty == true
                              ? record.shift!
                              : 'Sin turno';

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.water_drop_outlined,
                              size: 22,
                              color: AppColors.primary,
                            ),
                            const SizedBox(
                              width: 12,
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${record.liters.toStringAsFixed(1)} L',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(
                                    height: 2,
                                  ),
                                  Text(
                                    '${_formatMilkingDate(record.date)}'
                                    ' · $shift'
                                    ' · Ordeña ${record.milkingNumber}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  if (record.observations?.trim().isNotEmpty ==
                                      true) ...[
                                    const SizedBox(
                                      height: 3,
                                    ),
                                    Text(
                                      record.observations!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),

            const SizedBox(
              height: 16,
            ),

            // ===============================================
            // OBSERVACIONES
            // ===============================================

            _SectionCard(
              title: 'Observaciones',
              icon: Icons.notes_outlined,
              children: [
                Text(
                  _cattle.observations.trim().isEmpty
                      ? 'Sin observaciones.'
                      : _cattle.observations,
                ),
              ],
            ),

            const SizedBox(
              height: 24,
            ),

            // ===============================================
            // BOTONES
            // ===============================================

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isDeleting ? null : _editCattle,
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
                    onPressed: _isDeleting ? null : _deleteCattle,
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

            const SizedBox(
              height: 30,
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================
// IMAGEN
// ===========================================================

class _CattleDetailImage extends StatelessWidget {
  const _CattleDetailImage({
    required this.imagePath,
  });

  final String? imagePath;

  @override
  Widget build(
    BuildContext context,
  ) {
    final String? path = imagePath;

    if (path == null || path.trim().isEmpty) {
      return Container(
        width: 130,
        height: 110,
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(
            16,
          ),
        ),
        alignment: Alignment.center,
        child: const FaIcon(
          FontAwesomeIcons.cow,
          size: 55,
          color: Color(
            0xFF0F5132,
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(
        16,
      ),
      child: Image.file(
        File(path),
        width: 130,
        height: 110,
        fit: BoxFit.cover,
        errorBuilder: (
          BuildContext context,
          Object error,
          StackTrace? stackTrace,
        ) {
          return Container(
            width: 130,
            height: 110,
            alignment: Alignment.center,
            color: AppColors.primaryLight,
            child: const FaIcon(
              FontAwesomeIcons.cow,
              size: 50,
              color: Color(
                0xFF0F5132,
              ),
            ),
          );
        },
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

// ===========================================================
// MÉTRICA PRODUCTIVA
// ===========================================================

class _ProductionMetric extends StatelessWidget {
  const _ProductionMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Column(
      children: [
        Icon(
          icon,
          size: 22,
          color: AppColors.primary,
        ),
        const SizedBox(
          height: 6,
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(
          height: 2,
        ),
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

// ===========================================================
// ESTADO
// ===========================================================

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.text,
    required this.foreground,
    required this.background,
  });

  final String text;
  final Color foreground;
  final Color background;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(
          20,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
