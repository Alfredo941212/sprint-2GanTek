import 'package:flutter/material.dart';

import '../../data/models/ia_analysis_model.dart';
import '../../data/models/ia_animal_model.dart';
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

  @override
  void initState() {
    super.initState();
    _loadAnalysis();
  }

  Future<void> _agregarAAgenda(
    IaAnimalModel animal,
  ) async {
    try {
      final String message = await _repository.agregarAAgenda(
        animal.ganadoId,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              message,
            ),
          ),
        );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'No se pudo agregar la tarea. $error',
            ),
          ),
        );
    }
  }

  Future<void> _loadAnalysis() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final result = await _repository.obtenerPrediccionProduccion();

      if (!mounted) return;

      setState(() {
        _analysis = result;
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
        title: const Text('Análisis IA'),
        actions: [
          IconButton(
            onPressed: _loadAnalysis,
            icon: const Icon(Icons.refresh),
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
                'No se pudo cargar el análisis IA.',
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
                child: const Text('Reintentar'),
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

    return RefreshIndicator(
      onRefresh: _loadAnalysis,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSummary(analysis),
          const SizedBox(height: 16),
          ...analysis.animales.map(
            _buildAnimalCard,
          ),
        ],
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
              'Resumen',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Animales analizados: '
              '${analysis.totalAnimales}',
            ),
            const SizedBox(height: 4),
            Text(
              'Fecha de análisis: '
              '${analysis.fechaAnalisis}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimalCard(
    IaAnimalModel animal,
  ) {
    final bool sinDatos = animal.estadoIa == 'sin_datos_suficientes';

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
                    'Arete ${animal.arete}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildStatusChip(
                  animal.estadoIa,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (sinDatos)
              _buildNoData(animal)
            else
              _buildAnalysisData(
                animal,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoData(
    IaAnimalModel animal,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(animal.mensaje),
        const SizedBox(height: 12),
        Text(
          'Días registrados: '
          '${animal.diasRegistrados ?? 0}',
        ),
        Text(
          'Días incompletos: '
          '${animal.diasIncompletos}',
        ),
      ],
    );
  }

  Widget _buildAnalysisData(
    IaAnimalModel animal,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _dataRow(
          'Producción real',
          '${_format(animal.produccionReal)} L',
        ),
        _dataRow(
          'Producción esperada',
          '${_format(animal.produccionEsperada)} L',
        ),
        _dataRow(
          'Producción mínima',
          '${_format(animal.produccionMinima)} L',
        ),
        _dataRow(
          'Diferencia',
          '${_format(animal.diferenciaPorcentual)} %',
        ),
        _dataRow(
          'Tendencia',
          animal.tendencia ?? 'Sin datos',
        ),
        _dataRow(
          'Calidad del modelo',
          animal.calidadAjuste ?? 'Sin datos',
        ),
        _dataRow(
          'Ajuste R²',
          _format(animal.r2),
        ),
        _dataRow(
          'Predicción siguiente día',
          animal.prediccionSiguienteDia == null
              ? 'Sin predicción'
              : '${_format(
                  animal.prediccionSiguienteDia,
                )} L',
        ),
        _dataRow(
          'Días utilizados',
          '${animal.diasUtilizados ?? 0}',
        ),
        _dataRow(
          'Días incompletos',
          '${animal.diasIncompletos}',
        ),
        const Divider(height: 28),
        Text(
          animal.mensaje,
          style: const TextStyle(
            height: 1.4,
          ),
        ),
        if (animal.estadoIa == 'anomalia') ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                _agregarAAgenda(animal);
              },
              icon: const Icon(
                Icons.event_note_outlined,
              ),
              label: const Text(
                'Agregar a agenda',
              ),
            ),
          ),
        ],
      ],
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
            child: Text(label),
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
    String status,
  ) {
    String text;
    IconData icon;
    Color color;

    switch (status) {
      case 'anomalia':
        text = 'Anomalía';
        icon = Icons.warning_amber_rounded;
        color = Colors.red;
        break;

      case 'atencion':
        text = 'Atención';
        icon = Icons.visibility_outlined;
        color = Colors.orange;
        break;

      case 'normal':
        text = 'Normal';
        icon = Icons.check_circle_outline;
        color = Colors.green;
        break;

      default:
        text = 'Sin datos';
        icon = Icons.info_outline;
        color = Colors.blueGrey;
    }

    return Chip(
      avatar: Icon(
        icon,
        size: 18,
        color: color,
      ),
      label: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
      side: BorderSide(
        color: color,
      ),
      backgroundColor: color.withValues(alpha: 0.08),
    );
  }

  String _format(
    double? value,
  ) {
    if (value == null) {
      return '0.00';
    }

    return value.toStringAsFixed(2);
  }
}
