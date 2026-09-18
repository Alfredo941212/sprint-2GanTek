import 'dart:convert';

import '../../../../core/network/api_client.dart';
import '../models/dashboard_summary.dart';

class DashboardRepository {
  DashboardRepository({
    ApiClient? apiClient,
  }) : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  Future<DashboardSummary> getSummary() async {
    final response = await _apiClient.get(
      '/dashboard',
    );

    if (response.statusCode == 401) {
      throw Exception(
        'La sesión ha expirado. Inicia sesión nuevamente.',
      );
    }

    if (response.statusCode != 200) {
      throw Exception(
        'No fue posible cargar el dashboard '
        '(${response.statusCode}).',
      );
    }

    final dynamic decoded = jsonDecode(
      response.body,
    );

    if (decoded is! Map<String, dynamic>) {
      throw Exception(
        'El servidor devolvió una respuesta inválida.',
      );
    }

    final dynamic dataValue = decoded['data'];

    if (dataValue is! Map<String, dynamic>) {
      throw Exception(
        'El servidor no devolvió los datos del dashboard.',
      );
    }

    final dynamic summaryValue = dataValue['resumen'];

    if (summaryValue is! Map<String, dynamic>) {
      throw Exception(
        'El servidor no devolvió el resumen del dashboard.',
      );
    }

    final DateTime now = DateTime.now();

    return DashboardSummary(
      registeredCattle: _toInt(
        summaryValue['ganado_activo'],
      ),
      productiveCattle: _toInt(
        summaryValue['vacas_en_produccion'],
      ),
      todayMilkProduction: _toDouble(
        summaryValue['litros_hoy'],
      ),
      monthlyMilkProduction: _toDouble(
        summaryValue['litros_mes'],
      ),
      averagePerCow: _toDouble(
        summaryValue['promedio_por_vaca'],
      ),
      lowProductionAlerts: _toInt(
        summaryValue['alertas_produccion'],
      ),
      upcomingVaccines: _toInt(
        summaryValue['vacunas_proximas'],
      ),
      overdueVaccines: _toInt(
        summaryValue['vacunas_vencidas'],
      ),
      registeredCattleLots: _toStringList(
        summaryValue['lotes_ganado'],
      ),
      productiveCattleLots: _toStringList(
        summaryValue['lotes_produccion'],
      ),
      todayLabel: _buildDayLabel(
        now,
      ),
      monthLabel: _buildMonthLabel(
        now,
      ),
    );
  }

  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0.0;
  }

  List<String> _toStringList(dynamic value) {
    if (value is! List) {
      return <String>[];
    }

    return value
        .map(
          (dynamic item) => item?.toString().trim() ?? '',
        )
        .where(
          (String item) => item.isNotEmpty,
        )
        .toList();
  }

  String _buildDayLabel(
    DateTime date,
  ) {
    const List<String> days = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];

    return '${days[date.weekday - 1]} ${date.day}';
  }

  String _buildMonthLabel(
    DateTime date,
  ) {
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

    return months[date.month - 1];
  }
}
