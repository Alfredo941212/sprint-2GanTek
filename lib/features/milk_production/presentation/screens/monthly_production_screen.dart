import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../data/repositories/milking_repository.dart';

class MonthlyProductionScreen extends StatefulWidget {
  const MonthlyProductionScreen({super.key});

  @override
  State<MonthlyProductionScreen> createState() =>
      _MonthlyProductionScreenState();
}

class _MonthlyProductionScreenState extends State<MonthlyProductionScreen> {
  final MilkingRepository _repository = MilkingRepository();

  late DateTime _selectedMonth;

  Map<int, double> _productionByDay = {};
  Map<String, double> _productionByLot = {};

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    final DateTime now = DateTime.now();

    _selectedMonth = DateTime(
      now.year,
      now.month,
      1,
    );

    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final Map<int, double> dailyData =
          await _repository.getDailyProductionForMonth(
        _selectedMonth,
      );

      final Map<String, double> lotData =
          await _repository.getMonthlyProductionByLots(
        _selectedMonth,
      );

      if (!mounted) return;

      setState(() {
        _productionByDay = dailyData;
        _productionByLot = lotData;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'No fue posible cargar la producción.';
        _isLoading = false;
      });

      debugPrint(
        'Error cargando producción mensual: $error',
      );
    }
  }

  Future<void> _previousMonth() async {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month - 1,
        1,
      );
    });

    await _loadData();
  }

  Future<void> _nextMonth() async {
    final DateTime now = DateTime.now();

    final DateTime currentMonth = DateTime(
      now.year,
      now.month,
      1,
    );

    final DateTime nextMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + 1,
      1,
    );

    if (nextMonth.isAfter(currentMonth)) {
      return;
    }

    setState(() {
      _selectedMonth = nextMonth;
    });

    await _loadData();
  }

  double get _totalProduction {
    return _productionByDay.values.fold(
      0,
      (double sum, double value) => sum + value,
    );
  }

  int get _daysWithProduction {
    return _productionByDay.values
        .where(
          (double value) => value > 0,
        )
        .length;
  }

  double get _dailyAverage {
    if (_daysWithProduction == 0) {
      return 0;
    }

    return _totalProduction / _daysWithProduction;
  }

  String get _monthName {
    const List<String> months = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];

    return months[_selectedMonth.month - 1];
  }

  bool get _canGoNext {
    final DateTime now = DateTime.now();

    final DateTime currentMonth = DateTime(
      now.year,
      now.month,
      1,
    );

    final DateTime nextMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + 1,
      1,
    );

    return !nextMonth.isAfter(
      currentMonth,
    );
  }

  List<FlSpot> _buildSpots() {
    final int daysInMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + 1,
      0,
    ).day;

    return List<FlSpot>.generate(
      daysInMonth,
      (int index) {
        final int day = index + 1;

        final double liters = _productionByDay[day] ?? 0;

        return FlSpot(
          day.toDouble(),
          liters,
        );
      },
    );
  }

  double _getMaxY() {
    if (_productionByDay.isEmpty) {
      return 10;
    }

    double maximum = 0;

    for (final double value in _productionByDay.values) {
      if (value > maximum) {
        maximum = value;
      }
    }

    if (maximum <= 5) {
      return 5;
    }

    return maximum + 2;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Producción mensual',
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(
            16,
          ),
          children: [
            _buildMonthSelector(),
            const SizedBox(height: 20),
            _buildSummary(),
            const SizedBox(height: 24),
            _buildChartSection(),
            const SizedBox(height: 24),
            _buildProductionByLot(),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Row(
      children: [
        IconButton(
          onPressed: _previousMonth,
          icon: const Icon(
            Icons.chevron_left,
          ),
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                _monthName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${_selectedMonth.year}',
                style: TextStyle(
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: _canGoNext ? _nextMonth : null,
          icon: const Icon(
            Icons.chevron_right,
          ),
        ),
      ],
    );
  }

  Widget _buildSummary() {
    return Row(
      children: [
        Expanded(
          child: _SummaryItem(
            icon: Icons.water_drop,
            title: 'Total',
            value: '${_totalProduction.toStringAsFixed(1)} L',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryItem(
            icon: Icons.calendar_today,
            title: 'Días',
            value: '$_daysWithProduction',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryItem(
            icon: Icons.analytics_outlined,
            title: 'Promedio',
            value: '${_dailyAverage.toStringAsFixed(1)} L',
          ),
        ),
      ],
    );
  }

  Widget _buildChartSection() {
    if (_isLoading) {
      return const SizedBox(
        height: 320,
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return SizedBox(
        height: 300,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadData,
                child: const Text(
                  'Reintentar',
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_productionByDay.isEmpty) {
      return const SizedBox(
        height: 300,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.bar_chart,
                size: 60,
              ),
              SizedBox(height: 12),
              Text(
                'No hay producción registrada\npara este mes.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          12,
          24,
          20,
          16,
        ),
        child: SizedBox(
          height: 320,
          child: LineChart(
            LineChartData(
              minX: 1,
              maxX: DateTime(
                _selectedMonth.year,
                _selectedMonth.month + 1,
                0,
              ).day.toDouble(),
              minY: 0,
              maxY: _getMaxY(),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: _getMaxY() / 5,
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
                leftTitles: AxisTitles(
                  axisNameWidget: const Text(
                    'Litros',
                  ),
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 44,
                    getTitlesWidget: (
                      double value,
                      TitleMeta meta,
                    ) {
                      return Text(
                        value.toStringAsFixed(
                          0,
                        ),
                        style: const TextStyle(
                          fontSize: 11,
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  axisNameWidget: const Text(
                    'Día del mes',
                  ),
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    interval: 5,
                    getTitlesWidget: (
                      double value,
                      TitleMeta meta,
                    ) {
                      final int day = value.toInt();

                      if (day == 1 ||
                          day == 5 ||
                          day == 10 ||
                          day == 15 ||
                          day == 20 ||
                          day == 25 ||
                          day == 30) {
                        return Padding(
                          padding: const EdgeInsets.only(
                            top: 8,
                          ),
                          child: Text(
                            '$day',
                            style: const TextStyle(
                              fontSize: 11,
                            ),
                          ),
                        );
                      }

                      return const SizedBox.shrink();
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
                  spots: _buildSpots(),
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
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductionByLot() {
    if (_isLoading) {
      return const SizedBox.shrink();
    }

    if (_productionByLot.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: const [
              Icon(
                Icons.inventory_2_outlined,
                size: 40,
              ),
              SizedBox(height: 10),
              Text(
                'No hay producción por lote registrada este mes.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                ),
                SizedBox(width: 10),
                Text(
                  'Producción por lote',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._productionByLot.entries.map(
              (MapEntry<String, double> entry) {
                final double percentage =
                    _totalProduction > 0 ? entry.value / _totalProduction : 0;

                return Padding(
                  padding: const EdgeInsets.only(
                    bottom: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry.key,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            '${entry.value.toStringAsFixed(1)} L',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: 6,
                      ),
                      LinearProgressIndicator(
                        value: percentage.clamp(
                          0.0,
                          1.0,
                        ),
                      ),
                      const SizedBox(
                        height: 4,
                      ),
                      Text(
                        '${(percentage * 100).toStringAsFixed(1)} % del total',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
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

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _SummaryItem({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 8,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 25,
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
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
