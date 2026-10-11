import 'dart:convert';

import '../../../../core/network/api_client.dart';
import '../models/report_summary.dart';

class ReportRepository {
  ReportRepository();

  // =========================================================
  // RESUMEN GENERAL
  // =========================================================

  Future<ReportSummary> getSummary({
    required int userId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final DateTime now = DateTime.now();

    final DateTime start = startDate ??
        DateTime(
          now.year,
          now.month,
          1,
        );

    final DateTime end = endDate ?? now;

    final List<dynamic> responses = await Future.wait([
      ApiClient.instance.get('/ganado'),
      ApiClient.instance.get('/ordenios'),
      ApiClient.instance.get('/vacunaciones'),
    ]);

    final ganadoResponse = responses[0];
    final ordeniosResponse = responses[1];
    final vacunacionesResponse = responses[2];

    _validateResponse(
      ganadoResponse.statusCode,
      'ganado',
    );

    _validateResponse(
      ordeniosResponse.statusCode,
      'ordeños',
    );

    _validateResponse(
      vacunacionesResponse.statusCode,
      'vacunaciones',
    );

    final List<Map<String, dynamic>> cattle = _extractList(ganadoResponse.body);

    final List<Map<String, dynamic>> milkings =
        _extractList(ordeniosResponse.body);

    final List<Map<String, dynamic>> vaccinations =
        _extractList(vacunacionesResponse.body);

    // =======================================================
    // GANADO
    // =======================================================

    final List<Map<String, dynamic>> activeCattle = cattle.where(
      (animal) {
        return _value(
              animal,
              ['estado', 'status'],
            ).toLowerCase() ==
            'activo';
      },
    ).toList();

    final int totalCattle = activeCattle.length;

    final int productiveCattle = activeCattle.where(
      (animal) {
        final String sex = _value(
          animal,
          ['sexo', 'sex'],
        ).toLowerCase();

        final String productiveStatus = _value(
          animal,
          [
            'estado_productivo',
            'productive_status',
          ],
        ).toLowerCase();

        return sex == 'hembra' && productiveStatus == 'en producción';
      },
    ).length;

    final int dryCattle = activeCattle.where(
      (animal) {
        final String sex = _value(
          animal,
          ['sexo', 'sex'],
        ).toLowerCase();

        final String productiveStatus = _value(
          animal,
          [
            'estado_productivo',
            'productive_status',
          ],
        ).toLowerCase();

        return sex == 'hembra' && productiveStatus == 'seca';
      },
    ).length;

    // =======================================================
    // ORDEÑOS DEL PERIODO
    // =======================================================

    final List<Map<String, dynamic>> periodMilkings = milkings.where(
      (milking) {
        final DateTime? date = _parseDate(
          milking['fecha'] ?? milking['date'],
        );

        if (date == null) {
          return false;
        }

        return !_dateOnly(date).isBefore(
              _dateOnly(start),
            ) &&
            !_dateOnly(date).isAfter(
              _dateOnly(end),
            );
      },
    ).toList();

    double totalMilkProduction = 0.0;

    final Set<String> productionDays = {};

    for (final milking in periodMilkings) {
      totalMilkProduction += _toDouble(
        milking['litros'] ?? milking['liters'],
      );

      final DateTime? date = _parseDate(
        milking['fecha'] ?? milking['date'],
      );

      if (date != null) {
        productionDays.add(
          _formatDate(date),
        );
      }
    }

    final int totalMilkings = periodMilkings.length;

    final double averageDailyProduction = productionDays.isNotEmpty
        ? totalMilkProduction / productionDays.length
        : 0.0;

    final double averageProductionPerCow =
        productiveCattle > 0 ? totalMilkProduction / productiveCattle : 0.0;

    // =======================================================
    // VACUNACIONES
    // =======================================================

    int appliedVaccines = 0;
    int upcomingVaccines = 0;
    int overdueVaccines = 0;

    final DateTime today = _dateOnly(now);

    final DateTime nextThirtyDays = today.add(
      const Duration(days: 30),
    );

    for (final vaccination in vaccinations) {
      final DateTime? applicationDate = _parseDate(
        vaccination['fecha_aplicacion'] ?? vaccination['application_date'],
      );

      if (applicationDate != null) {
        final DateTime normalized = _dateOnly(applicationDate);

        if (!normalized.isBefore(_dateOnly(start)) &&
            !normalized.isAfter(_dateOnly(end))) {
          appliedVaccines++;
        }
      }

      final DateTime? nextDate = _parseDate(
        vaccination['proxima_aplicacion'] ?? vaccination['next_dose_date'],
      );

      if (nextDate == null) {
        continue;
      }

      final DateTime normalizedNext = _dateOnly(nextDate);

      if (normalizedNext.isBefore(today)) {
        overdueVaccines++;
      } else if (!normalizedNext.isAfter(
        nextThirtyDays,
      )) {
        upcomingVaccines++;
      }
    }

    // =======================================================
    // ALERTAS DE BAJA PRODUCCIÓN
    // =======================================================

    int lowProductionAlerts = 0;

    for (final animal in activeCattle) {
      final String sex = _value(
        animal,
        ['sexo', 'sex'],
      ).toLowerCase();

      final String productiveStatus = _value(
        animal,
        [
          'estado_productivo',
          'productive_status',
        ],
      ).toLowerCase();

      if (sex != 'hembra' || productiveStatus != 'en producción') {
        continue;
      }

      final int? cattleId = _toInt(
        animal['id'],
      );

      if (cattleId == null) {
        continue;
      }

      final double minimumDailyProduction = _toDouble(
        animal['produccion_minima_diaria'] ??
            animal['minimum_daily_production'],
      );

      double cattleProduction = 0.0;

      for (final milking in periodMilkings) {
        final int? milkingCattleId = _toInt(
          milking['ganado_id'] ?? milking['cattle_id'],
        );

        if (milkingCattleId == cattleId) {
          cattleProduction += _toDouble(
            milking['litros'] ?? milking['liters'],
          );
        }
      }

      final int days = _dateOnly(end).difference(_dateOnly(start)).inDays + 1;

      final double expected = minimumDailyProduction * days;

      if (cattleProduction < expected) {
        lowProductionAlerts++;
      }
    }

    return ReportSummary(
      totalCattle: totalCattle,
      productiveCattle: productiveCattle,
      dryCattle: dryCattle,
      totalMilkProduction: totalMilkProduction,
      averageDailyProduction: averageDailyProduction,
      averageProductionPerCow: averageProductionPerCow,
      totalMilkings: totalMilkings,
      appliedVaccines: appliedVaccines,
      upcomingVaccines: upcomingVaccines,
      overdueVaccines: overdueVaccines,
      lowProductionAlerts: lowProductionAlerts,
    );
  }

  // =========================================================
  // PRODUCCIÓN POR LOTE
  // =========================================================

  Future<List<LotProductionReport>> getProductionByLot({
    required int userId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final DateTime now = DateTime.now();

    final DateTime start = startDate ??
        DateTime(
          now.year,
          now.month,
          1,
        );

    final DateTime end = endDate ?? now;

    final response = await ApiClient.instance.get(
      '/ordenios',
    );

    _validateResponse(
      response.statusCode,
      'ordeños',
    );

    final List<Map<String, dynamic>> milkings = _extractList(response.body);

    final Map<int, _LotAccumulator> totals = {};

    for (final milking in milkings) {
      final DateTime? date = _parseDate(
        milking['fecha'] ?? milking['date'],
      );

      if (date == null ||
          _dateOnly(date).isBefore(_dateOnly(start)) ||
          _dateOnly(date).isAfter(_dateOnly(end))) {
        continue;
      }

      final int lotId = _toInt(
            milking['lote_historico_id'] ?? milking['historical_lot_id'],
          ) ??
          0;

      String lotName = 'Sin lote';

      final dynamic lot = milking['lote_historico'];

      if (lot is Map) {
        lotName = lot['nombre']?.toString() ?? 'Sin lote';
      }

      final double liters = _toDouble(
        milking['litros'] ?? milking['liters'],
      );

      final _LotAccumulator current = totals[lotId] ??
          _LotAccumulator(
            name: lotName,
            liters: 0,
          );

      totals[lotId] = _LotAccumulator(
        name: current.name,
        liters: current.liters + liters,
      );
    }

    final List<LotProductionReport> result = totals.entries.map(
      (entry) {
        return LotProductionReport(
          lotId: entry.key,
          lotName: entry.value.name,
          totalLiters: entry.value.liters,
        );
      },
    ).toList();

    result.sort(
      (a, b) => b.totalLiters.compareTo(a.totalLiters),
    );

    return result;
  }

  // =========================================================
  // ORDEÑAS RECIENTES
  // =========================================================

  Future<List<RecentMilkingReport>> getRecentMilkings({
    required int userId,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 10,
  }) async {
    final response = await ApiClient.instance.get(
      '/ordenios',
    );

    _validateResponse(
      response.statusCode,
      'ordeños',
    );

    final List<Map<String, dynamic>> milkings = _extractList(response.body);

    final List<RecentMilkingReport> result = [];

    for (final milking in milkings) {
      final DateTime? date = _parseDate(
        milking['fecha'] ?? milking['date'],
      );

      if (date == null) {
        continue;
      }

      if (startDate != null &&
          _dateOnly(date).isBefore(
            _dateOnly(startDate),
          )) {
        continue;
      }

      if (endDate != null &&
          _dateOnly(date).isAfter(
            _dateOnly(endDate),
          )) {
        continue;
      }

      final dynamic cattle = milking['ganado'];

      final dynamic lot = milking['lote_historico'];

      String cattleCode = '';
      String? cattleName;
      String lotName = 'Sin lote';

      if (cattle is Map) {
        cattleCode = cattle['arete_siniiga']?.toString() ??
            cattle['codigo']?.toString() ??
            '';

        cattleName = cattle['nombre']?.toString();
      }

      if (lot is Map) {
        lotName = lot['nombre']?.toString() ?? 'Sin lote';
      }

      result.add(
        RecentMilkingReport(
          id: _toInt(milking['id']) ?? 0,
          cattleCode: cattleCode,
          cattleName: cattleName,
          lotName: lotName,
          date: date,
          milkingNumber: _toInt(
                milking['numero_ordenio'] ?? milking['milking_number'],
              ) ??
              0,
          shift: (milking['turno'] ?? milking['shift'])?.toString(),
          liters: _toDouble(
            milking['litros'] ?? milking['liters'],
          ),
        ),
      );
    }

    result.sort(
      (a, b) {
        final int dateComparison = b.date.compareTo(a.date);

        if (dateComparison != 0) {
          return dateComparison;
        }

        return b.milkingNumber.compareTo(
          a.milkingNumber,
        );
      },
    );

    if (result.length > limit) {
      return result.take(limit).toList();
    }

    return result;
  }

  // =========================================================
  // HELPERS
  // =========================================================

  List<Map<String, dynamic>> _extractList(
    String body,
  ) {
    final dynamic decoded = jsonDecode(body);

    if (decoded is! Map<String, dynamic>) {
      return [];
    }

    final dynamic data = decoded['data'];

    if (data is! List) {
      return [];
    }

    return data.whereType<Map<String, dynamic>>().toList();
  }

  void _validateResponse(
    int statusCode,
    String module,
  ) {
    if (statusCode == 401) {
      throw Exception(
        'La sesión ha expirado. Inicia sesión nuevamente.',
      );
    }

    if (statusCode < 200 || statusCode >= 300) {
      throw Exception(
        'No fue posible cargar $module '
        '($statusCode).',
      );
    }
  }

  String _value(
    Map<String, dynamic> map,
    List<String> keys,
  ) {
    for (final String key in keys) {
      final dynamic value = map[key];

      if (value != null) {
        return value.toString().trim();
      }
    }

    return '';
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(
      value.toString(),
    );
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(
      date.year,
      date.month,
      date.day,
    );
  }

  String _formatDate(DateTime date) {
    final String month = date.month.toString().padLeft(2, '0');

    final String day = date.day.toString().padLeft(2, '0');

    return '${date.year}-$month-$day';
  }

  int? _toInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
      value.toString(),
    );
  }

  double _toDouble(dynamic value) {
    if (value == null) {
      return 0.0;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value.toString(),
        ) ??
        0.0;
  }
}

class _LotAccumulator {
  final String name;
  final double liters;

  const _LotAccumulator({
    required this.name,
    required this.liters,
  });
}
