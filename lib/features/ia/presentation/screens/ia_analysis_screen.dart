import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../data/models/ia_analysis_model.dart';
import '../../data/repositories/ia_repository.dart';

class IaAnalysisScreen extends StatefulWidget {
  const IaAnalysisScreen({super.key});

  @override
  State<IaAnalysisScreen> createState() => _IaAnalysisScreenState();
}

class _IaAnalysisScreenState extends State<IaAnalysisScreen> {
  final IaRepository _repository = IaRepository();

  bool _isLoading = true;
  String? _error;
  IaAnalysisModel? _analysis;

  int _horizonte = 7;
  int? _grupoSeleccionado;

  DateTime? _fechaInicio;
  DateTime? _fechaFin;

  @override
  void initState() {
    super.initState();
    _loadAnalysis();
  }

  Future<void> _loadAnalysis() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final result = await _repository.obtenerAnalisisProduccion(
        horizonte: _horizonte,
        fechaInicio:
            _fechaInicio == null ? null : _formatApiDate(_fechaInicio!),
        fechaFin: _fechaFin == null ? null : _formatApiDate(_fechaFin!),
      );

      if (!mounted) return;

      setState(() {
        _analysis = result;

        if (_grupoSeleccionado != null) {
          final existe = result.grupos.any(
            (grupo) => grupo.grupoId == _grupoSeleccionado,
          );

          if (!existe) {
            _grupoSeleccionado = null;
          }
        }

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'IA de Producción',
        ),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadAnalysis,
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
              const SizedBox(height: 12),
              const Text(
                'No se pudo cargar el análisis de producción.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadAnalysis,
                child: const Text(
                  'Reintentar',
                ),
              ),
            ],
          ),
        ),
      );
    }

    final analysis = _analysis;

    if (analysis == null) {
      return const Center(
        child: Text(
          'No hay información disponible.',
        ),
      );
    }

    final grupos = _grupoSeleccionado == null
        ? analysis.grupos
        : analysis.grupos
            .where(
              (grupo) => grupo.grupoId == _grupoSeleccionado,
            )
            .toList();

    return RefreshIndicator(
      onRefresh: _loadAnalysis,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildFilters(analysis),
          const SizedBox(height: 16),
          _buildSummary(analysis),
          const SizedBox(height: 16),
          _buildKpiSection(analysis),
          const SizedBox(height: 16),
          if (_grupoSeleccionado == null)
            _buildComparativeChart(
              analysis.grupos,
            )
          else if (grupos.isNotEmpty)
            _buildProductionChart(
              grupos.first,
            ),
          const SizedBox(height: 16),
          _buildGroupBarChart(
            grupos,
          ),
          const SizedBox(height: 16),
          _buildInsightsSection(
            grupos,
          ),
          const SizedBox(height: 16),
          ...grupos.map(
            _buildGroupCard,
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(
    IaAnalysisModel analysis,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Consultar predicción',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Horizonte',
            ),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment<int>(
                  value: 7,
                  label: Text(
                    '1 semana',
                  ),
                ),
                ButtonSegment<int>(
                  value: 30,
                  label: Text(
                    '1 mes',
                  ),
                ),
              ],
              selected: {
                _horizonte,
              },
              onSelectionChanged: (Set<int> value) {
                setState(() {
                  _horizonte = value.first;
                });
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int?>(
              initialValue: _grupoSeleccionado,
              decoration: const InputDecoration(
                labelText: 'Grupo',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text(
                    'Todos los grupos',
                  ),
                ),
                ...analysis.grupos.map(
                  (grupo) {
                    return DropdownMenuItem<int?>(
                      value: grupo.grupoId,
                      child: Text(
                        grupo.grupo,
                      ),
                    );
                  },
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _grupoSeleccionado = value;
                });
              },
            ),
            const SizedBox(height: 16),
            const SizedBox(height: 12),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _loadAnalysis,
                icon: const Icon(
                  Icons.auto_graph,
                ),
                label: const Text(
                  'Consultar',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(
    IaAnalysisModel analysis,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Resumen del análisis',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _dataRow(
              'Modelo de predicción',
              analysis.modeloPrediccion,
            ),
            _dataRow(
              'Detección de anomalías',
              analysis.modeloAnomalias,
            ),
            _dataRow(
              'Registros analizados',
              '${analysis.totalRegistros}',
            ),
            const Divider(height: 28),
            const Text(
              'Métricas del modelo',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            /*   _dataRow(
              'MAE',
              '${analysis.mae.toStringAsFixed(2)} L',
            ),
            _dataRow(
              'RMSE',
              '${analysis.rmse.toStringAsFixed(2)} L',
            ),
            _dataRow(
              'R²',
              analysis.r2.toStringAsFixed(3),
            ),
            _dataRow(
              'Registros de entrenamiento',
              '${analysis.registrosEntrenamiento}',
            ),
            _dataRow(
              'Registros de prueba',
              '${analysis.registrosPrueba}',
            ),*/
            _dataRow(
              'Horizonte',
              '${analysis.horizonteDias} días',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupCard(
    IaGroupModel grupo,
  ) {
    final color = _getClassificationColor(
      grupo.clasificacion.color,
    );

    return Card(
      margin: const EdgeInsets.only(
        bottom: 16,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    grupo.grupo,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildStatusChip(
                  grupo.clasificacion.nivel,
                  color,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _dataRow(
              'Producción actual',
              '${grupo.produccionActual.toStringAsFixed(2)} L',
            ),
            _dataRow(
              'Cantidad de vacas',
              '${grupo.cantidadVacas}',
            ),
            _dataRow(
              'Promedio por vaca',
              '${grupo.promedioPorVaca.toStringAsFixed(2)} L',
            ),
            _dataRow(
              'Duración',
              '${grupo.duracionMinutos} min',
            ),
            _dataRow(
              'Tendencia',
              _formatTendencia(
                grupo.tendencia,
              ),
            ),
            _dataRow(
              'Anomalía detectada',
              grupo.anomaliaModelo ? 'Sí' : 'No',
            ),
            /* const SizedBox(height: 16),
            _buildProductionChart(
              grupo,
            ),*/
            const SizedBox(height: 16),
            const Divider(
              height: 28,
            ),
            Text(
              grupo.clasificacion.mensaje,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Historial',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (grupo.historial.isEmpty)
              const Text(
                'No hay historial disponible.',
              )
            else
              ...grupo.historial.map(
                (item) {
                  return _dataRow(
                    item.fecha,
                    '${item.litros.toStringAsFixed(2)} L',
                  );
                },
              ),
            const SizedBox(height: 16),
            const Text(
              'Predicción',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...grupo.predicciones.map(
              (prediccion) {
                return _buildPredictionRow(
                  prediccion,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiSection(IaAnalysisModel analysis) {
    final grupos = analysis.grupos;

    final produccionTotal = grupos.fold<double>(
      0,
      (sum, grupo) => sum + grupo.produccionActual,
    );

    final promedioGrupo =
        grupos.isEmpty ? 0.0 : produccionTotal / grupos.length;

    final gruposConAnomalia = grupos
        .where(
          (grupo) => grupo.anomaliaModelo,
        )
        .length;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      mainAxisExtent: 175,
      children: [
        _buildKpiCard(
          title: 'Producción total',
          value: '${produccionTotal.toStringAsFixed(2)} L',
          subtitle: 'Producción actual analizada',
          icon: Icons.water_drop_outlined,
        ),
        _buildKpiCard(
          title: 'Promedio por grupo',
          value: '${promedioGrupo.toStringAsFixed(2)} L',
          subtitle: 'Promedio de producción',
          icon: Icons.groups_outlined,
        ),
        _buildKpiCard(
          title: 'Horizonte',
          value: '${analysis.horizonteDias} días',
          subtitle: 'Periodo de predicción',
          icon: Icons.calendar_month_outlined,
        ),
        _buildKpiCard(
          title: 'Grupos con anomalía',
          value: '$gruposConAnomalia',
          subtitle: 'de ${grupos.length} grupos',
          icon: Icons.warning_amber_rounded,
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.green.shade700,
                    size: 21,
                  ),
                ),
                const Spacer(),
              ],
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupBarChart(
    List<IaGroupModel> grupos,
  ) {
    if (grupos.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxY = grupos.map((grupo) => grupo.produccionActual).fold<double>(
              0,
              (max, value) => value > max ? value : max,
            ) +
        10;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Producción por grupo',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Comparación de la producción actual entre los grupos analizados.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 260,
              child: BarChart(
                BarChartData(
                  maxY: maxY,
                  alignment: BarChartAlignment.spaceAround,
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
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 42,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (
                          value,
                          meta,
                        ) {
                          final index = value.toInt();

                          if (index < 0 || index >= grupos.length) {
                            return const SizedBox.shrink();
                          }

                          return SideTitleWidget(
                            meta: meta,
                            child: Text(
                              grupos[index].grupo,
                              style: const TextStyle(
                                fontSize: 10,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: List.generate(
                    grupos.length,
                    (index) {
                      final grupo = grupos[index];

                      return BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: grupo.produccionActual,
                            width: 22,
                            borderRadius: BorderRadius.circular(
                              6,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (
                        group,
                        groupIndex,
                        rod,
                        rodIndex,
                      ) {
                        final grupo = grupos[groupIndex];

                        return BarTooltipItem(
                          '${grupo.grupo}\n'
                          '${rod.toY.toStringAsFixed(2)} L',
                          const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

//resumen inteligente + hallazgos y recomendaciones en Flutter.
  Widget _buildInsightsSection(
    List<IaGroupModel> grupos,
  ) {
    if (grupos.isEmpty) {
      return const SizedBox.shrink();
    }

    final gruposOrdenados = [...grupos]..sort(
        (a, b) => b.produccionActual.compareTo(a.produccionActual),
      );

    final grupoMejor = gruposOrdenados.first;
    final grupoMenor = gruposOrdenados.last;

    final gruposConAnomalia = grupos
        .where(
          (grupo) => grupo.anomaliaModelo,
        )
        .toList();

    final ascendentes = grupos
        .where(
          (grupo) => grupo.tendencia.toLowerCase() == 'ascendente',
        )
        .length;

    final descendentes = grupos
        .where(
          (grupo) => grupo.tendencia.toLowerCase() == 'descendente',
        )
        .length;

    return Column(
      children: [
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(
                          12,
                        ),
                      ),
                      child: Icon(
                        Icons.auto_awesome,
                        color: Colors.green.shade700,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Resumen inteligente',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Interpretación general de la producción analizada',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Se analizaron ${grupos.length} grupos de ordeña.',
                ),
                const SizedBox(height: 8),
                Text(
                  'El grupo con mayor producción actual es '
                  '${grupoMejor.grupo} con '
                  '${grupoMejor.produccionActual.toStringAsFixed(2)} L.',
                ),
                const SizedBox(height: 8),
                Text(
                  'El grupo con menor producción actual es '
                  '${grupoMenor.grupo} con '
                  '${grupoMenor.produccionActual.toStringAsFixed(2)} L.',
                ),
                const SizedBox(height: 8),
                Text(
                  'Tendencias ascendentes: $ascendentes | '
                  'Tendencias descendentes: $descendentes',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(
                          12,
                        ),
                      ),
                      child: Icon(
                        Icons.lightbulb_outline,
                        color: Colors.orange.shade700,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hallazgos y recomendaciones',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Aspectos relevantes detectados en los grupos',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (gruposConAnomalia.isEmpty)
                  _buildFindingCard(
                    title: 'Sin anomalías relevantes',
                    message:
                        'No se detectaron comportamientos atípicos en los grupos analizados.',
                    success: true,
                  )
                else
                  ...gruposConAnomalia.map(
                    (grupo) => _buildFindingCard(
                      title: grupo.grupo,
                      message: 'Se detectó un comportamiento atípico. '
                          '${grupo.clasificacion.mensaje}',
                      success: false,
                    ),
                  ),
                const SizedBox(height: 12),
                _buildFindingCard(
                  title: 'Grupo a revisar: ${grupoMenor.grupo}',
                  message: 'Presenta la producción más baja del periodo. '
                      'Se recomienda revisar alimentación, cantidad de vacas, '
                      'duración del ordeño y posibles factores sanitarios.',
                  success: false,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFindingCard({
    required String title,
    required String message,
    required bool success,
  }) {
    final background = success ? Colors.green.shade50 : Colors.orange.shade50;

    final borderColor =
        success ? Colors.green.shade600 : Colors.orange.shade600;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            color: borderColor,
            width: 4,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparativeChart(
    List<IaGroupModel> grupos,
  ) {
    if (grupos.isEmpty) {
      return const SizedBox.shrink();
    }

    final lineBars = <LineChartBarData>[];
    final labels = <String>[];

    int maxPuntos = 0;

    for (final grupo in grupos) {
      final historial = grupo.historial;
      final predicciones = grupo.predicciones;

      final puntos = <FlSpot>[];

      for (int i = 0; i < historial.length; i++) {
        puntos.add(
          FlSpot(
            i.toDouble(),
            historial[i].litros,
          ),
        );
      }

      final predictionStart = historial.isEmpty ? 0 : historial.length - 1;

      if (historial.isNotEmpty) {
        puntos.add(
          FlSpot(
            predictionStart.toDouble(),
            historial.last.litros,
          ),
        );
      }

      for (int i = 0; i < predicciones.length; i++) {
        puntos.add(
          FlSpot(
            (predictionStart + i + 1).toDouble(),
            predicciones[i].litros,
          ),
        );
      }

      if (puntos.length > maxPuntos) {
        maxPuntos = puntos.length;
      }

      lineBars.add(
        LineChartBarData(
          spots: puntos,
          isCurved: true,
          barWidth: 3,
          dotData: const FlDotData(
            show: true,
          ),
          belowBarData: BarAreaData(
            show: false,
          ),
        ),
      );

      if (labels.isEmpty) {
        labels.addAll(
          historial.map(
            (item) => _shortDate(item.fecha),
          ),
        );

        labels.addAll(
          predicciones.map(
            (item) => _shortDate(item.fecha),
          ),
        );
      }
    }

    final valores = <double>[
      for (final grupo in grupos) ...[
        ...grupo.historial.map(
          (item) => item.litros,
        ),
        ...grupo.predicciones.map(
          (item) => item.litros,
        ),
      ],
    ];

    if (valores.isEmpty) {
      return const SizedBox.shrink();
    }

    double minY = valores.reduce(
      (a, b) => a < b ? a : b,
    );

    double maxY = valores.reduce(
      (a, b) => a > b ? a : b,
    );

    minY = (minY - 5).clamp(
      0,
      double.infinity,
    );

    maxY += 5;

    if (maxY <= minY) {
      maxY = minY + 10;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Comparativa de producción',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Producción histórica y predicción de todos los grupos.',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: grupos
                  .map(
                    (grupo) => Chip(
                      label: Text(
                        grupo.grupo,
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 280,
              child: LineChart(
                LineChartData(
                  minY: minY,
                  maxY: maxY,
                  gridData: const FlGridData(
                    show: true,
                  ),
                  borderData: FlBorderData(
                    show: true,
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
                        reservedSize: 42,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        reservedSize: 32,
                        getTitlesWidget: (
                          value,
                          meta,
                        ) {
                          final index = value.toInt();

                          if (index < 0 || index >= labels.length) {
                            return const SizedBox.shrink();
                          }

                          if (_horizonte == 30 &&
                              index % 5 != 0 &&
                              index != labels.length - 1) {
                            return const SizedBox.shrink();
                          }

                          return SideTitleWidget(
                            meta: meta,
                            child: Text(
                              labels[index],
                              style: const TextStyle(
                                fontSize: 10,
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
                        touchedSpots,
                      ) {
                        return touchedSpots.map(
                          (spot) {
                            final grupo = grupos[spot.barIndex];

                            return LineTooltipItem(
                              '${grupo.grupo}\n'
                              '${spot.y.toStringAsFixed(2)} L',
                              const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ).toList();
                      },
                    ),
                  ),
                  lineBarsData: lineBars,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductionChart(
    IaGroupModel grupo,
  ) {
    final historial = grupo.historial;
    final predicciones = grupo.predicciones;

    if (historial.isEmpty && predicciones.isEmpty) {
      return const SizedBox.shrink();
    }

    final historicalSpots = <FlSpot>[];
    final predictionSpots = <FlSpot>[];

    for (int i = 0; i < historial.length; i++) {
      historicalSpots.add(
        FlSpot(
          i.toDouble(),
          historial[i].litros,
        ),
      );
    }

    final predictionStart = historial.isEmpty ? 0 : historial.length - 1;

    if (historial.isNotEmpty) {
      predictionSpots.add(
        FlSpot(
          predictionStart.toDouble(),
          historial.last.litros,
        ),
      );
    }

    for (int i = 0; i < predicciones.length; i++) {
      predictionSpots.add(
        FlSpot(
          (predictionStart + i + 1).toDouble(),
          predicciones[i].litros,
        ),
      );
    }

    final allValues = <double>[
      ...historial.map(
        (item) => item.litros,
      ),
      ...predicciones.map(
        (item) => item.litros,
      ),
    ];

    double minY = allValues.reduce(
      (a, b) => a < b ? a : b,
    );

    double maxY = allValues.reduce(
      (a, b) => a > b ? a : b,
    );

    minY = (minY - 5).clamp(
      0,
      double.infinity,
    );

    maxY += 5;

    if (maxY <= minY) {
      maxY = minY + 10;
    }

    final labels = <String>[
      ...historial.map(
        (item) => _shortDate(item.fecha),
      ),
      ...predicciones.map(
        (item) => _shortDate(item.fecha),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Producción y predicción',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _legend(
              Colors.blue,
              'Histórico',
            ),
            const SizedBox(width: 16),
            _legend(
              Colors.orange,
              'Predicción IA',
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 240,
          child: LineChart(
            LineChartData(
              minY: minY,
              maxY: maxY,
              gridData: const FlGridData(
                show: true,
              ),
              borderData: FlBorderData(
                show: true,
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
                  sideTitles: const SideTitles(
                    showTitles: true,
                    reservedSize: 42,
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    interval: 1,
                    getTitlesWidget: (
                      value,
                      meta,
                    ) {
                      final index = value.toInt();

                      if (index < 0 || index >= labels.length) {
                        return const SizedBox.shrink();
                      }

                      if (_horizonte == 30 &&
                          index % 5 != 0 &&
                          index != labels.length - 1) {
                        return const SizedBox.shrink();
                      }

                      return SideTitleWidget(
                        meta: meta,
                        child: Text(
                          labels[index],
                          style: const TextStyle(
                            fontSize: 10,
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
                    touchedSpots,
                  ) {
                    return touchedSpots.map(
                      (spot) {
                        return LineTooltipItem(
                          '${spot.y.toStringAsFixed(2)} L',
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
                if (historicalSpots.isNotEmpty)
                  LineChartBarData(
                    spots: historicalSpots,
                    isCurved: true,
                    barWidth: 3,
                    color: Colors.blue,
                    dotData: const FlDotData(
                      show: true,
                    ),
                    belowBarData: BarAreaData(
                      show: false,
                    ),
                  ),
                if (predictionSpots.isNotEmpty)
                  LineChartBarData(
                    spots: predictionSpots,
                    isCurved: true,
                    barWidth: 3,
                    color: Colors.orange,
                    dashArray: const [
                      6,
                      4,
                    ],
                    dotData: const FlDotData(
                      show: true,
                    ),
                    belowBarData: BarAreaData(
                      show: false,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _legend(
    Color color,
    String text,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 4,
          color: color,
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  String _shortDate(
    String fecha,
  ) {
    final parsed = DateTime.tryParse(
      fecha,
    );

    if (parsed == null) {
      return fecha;
    }

    return '${parsed.day}/${parsed.month}';
  }

  Widget _buildPredictionRow(
    IaPredictionModel prediccion,
  ) {
    final color = _getClassificationColor(
      prediccion.clasificacion.color,
    );

    return Padding(
      padding: const EdgeInsets.only(
        bottom: 8,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              prediccion.fecha,
            ),
          ),
          Text(
            '${prediccion.litros.toStringAsFixed(2)} L',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dataRow(
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
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

  Widget _buildStatusChip(
    String nivel,
    Color color,
  ) {
    return Chip(
      label: Text(
        _formatNivel(
          nivel,
        ),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
      side: BorderSide(
        color: color,
      ),
      backgroundColor: color.withValues(
        alpha: 0.08,
      ),
    );
  }

  String _formatNivel(
    String nivel,
  ) {
    switch (nivel) {
      case 'anomalia_baja':
        return 'Anomalía baja';

      case 'baja':
        return 'Baja';

      case 'media':
        return 'Media';

      case 'buena':
        return 'Buena';

      case 'anomalia_alta':
        return 'Anomalía alta';

      default:
        return nivel;
    }
  }

  String _formatTendencia(
    String tendencia,
  ) {
    switch (tendencia) {
      case 'ascendente':
        return 'Ascendente';

      case 'descendente':
        return 'Descendente';

      case 'estable':
        return 'Estable';

      default:
        return 'Sin datos';
    }
  }

  Color _getClassificationColor(
    String color,
  ) {
    switch (color) {
      case 'rojo_oscuro':
        return Colors.red.shade900;

      case 'rojo':
        return Colors.red;

      case 'amarillo':
        return Colors.amber.shade700;

      case 'verde':
        return Colors.green;

      case 'morado':
        return Colors.purple;

      default:
        return Colors.blueGrey;
    }
  }

  String _formatApiDate(
    DateTime fecha,
  ) {
    final year = fecha.year.toString();

    final month = fecha.month.toString().padLeft(
          2,
          '0',
        );

    final day = fecha.day.toString().padLeft(
          2,
          '0',
        );

    return '$year-$month-$day';
  }
}
