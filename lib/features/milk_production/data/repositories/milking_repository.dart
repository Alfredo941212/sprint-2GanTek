import '../../../../core/database/database_helper.dart';
import '../../../../core/session/session_manager.dart';
import '../models/milking_record.dart';
import 'dart:convert';
import '../../../../core/network/api_client.dart';

class MilkingRepository {
  MilkingRepository({
    DatabaseHelper? databaseHelper,
  }) : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;

  // =========================================================
  // USUARIO ACTUAL
  // =========================================================

  int _requireUserId() {
    final int? userId = SessionManager.instance.currentUserId;

    if (userId == null) {
      throw Exception(
        'No hay una sesión activa.',
      );
    }

    return userId;
  }

  Future<List<Map<String, dynamic>>> _getApiMilkings() async {
    final response = await ApiClient.instance.get(
      '/ordenios',
    );

    if (response.statusCode == 401) {
      throw Exception(
        'La sesión ha expirado. Inicia sesión nuevamente.',
      );
    }

    if (response.statusCode != 200) {
      throw Exception(
        'No fue posible cargar los ordeños '
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

    final dynamic data = decoded['data'];

    print('========== API ORDEÑOS ==========');
    print('Status: ${response.statusCode}');
    print('Data: $data');
    print('=================================');

    if (data is! List) {
      throw Exception(
        'El servidor no devolvió la lista de ordeños.',
      );
    }

    return data.whereType<Map<String, dynamic>>().toList();
  }

  Future<List<MilkingRecord>> getRecentMilkingsByCattle({
    required int cattleId,
    int limit = 10,
  }) async {
    final List<Map<String, dynamic>> milkings = await _getApiMilkings();

    final List<MilkingRecord> result = [];

    for (final Map<String, dynamic> milking in milkings) {
      final int? milkingCattleId = _toInt(
        milking['ganado_id'],
      );

      if (milkingCattleId != cattleId) {
        continue;
      }

      result.add(
        MilkingRecord.fromApi(
          milking,
        ),
      );
    }

    result.sort(
      (MilkingRecord a, MilkingRecord b) {
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
  // REGISTRAR ORDEÑA
  // =========================================================

  // =========================================================
  // REGISTRAR ORDEÑA EN API REST
  // =========================================================

  Future<int> insertMilking({
    required int cattleId,
    required DateTime date,
    required double liters,
    String? shift,
    String? observations,
  }) async {
    if (liters <= 0) {
      throw Exception(
        'La cantidad de leche debe ser mayor a 0.',
      );
    }

    final String? cleanShift = shift?.trim();
    final String? cleanObservations = observations?.trim();

    final response = await ApiClient.instance.post(
      '/ordenios',
      body: {
        'ganado_id': cattleId,
        'fecha': _formatDate(date),
        'litros': liters,
        if (cleanShift != null && cleanShift.isNotEmpty) 'turno': cleanShift,
        if (cleanObservations != null && cleanObservations.isNotEmpty)
          'observaciones': cleanObservations,
      },
    );

    if (response.statusCode == 401) {
      throw Exception(
        'La sesión ha expirado. Inicia sesión nuevamente.',
      );
    }

    dynamic decoded;

    try {
      decoded = jsonDecode(
        response.body,
      );
    } catch (_) {
      decoded = null;
    }

    if (response.statusCode == 201) {
      if (decoded is Map<String, dynamic>) {
        final dynamic data = decoded['data'];

        if (data is Map<String, dynamic>) {
          final int? id = _toInt(
            data['id'],
          );

          if (id != null) {
            return id;
          }
        }

        // Algunos controladores pueden devolver directamente
        // los datos del registro.
        final int? id = _toInt(
          decoded['id'],
        );

        if (id != null) {
          return id;
        }
      }

      // El registro sí fue creado aunque el servidor
      // no haya devuelto el ID en el formato esperado.
      return 0;
    }

    if (response.statusCode == 422) {
      String message = 'Los datos de la ordeña no son válidos.';

      if (decoded is Map<String, dynamic>) {
        final dynamic serverMessage = decoded['message'];

        if (serverMessage != null &&
            serverMessage.toString().trim().isNotEmpty) {
          message = serverMessage.toString();
        }

        final dynamic errors = decoded['errors'];

        if (errors is Map) {
          for (final dynamic value in errors.values) {
            if (value is List && value.isNotEmpty) {
              message = value.first.toString();
              break;
            }

            if (value != null) {
              message = value.toString();
              break;
            }
          }
        }
      }

      throw Exception(
        message,
      );
    }

    if (response.statusCode == 403) {
      throw Exception(
        'No tienes permiso para registrar esta ordeña.',
      );
    }

    if (response.statusCode == 404) {
      throw Exception(
        'No se encontró el animal seleccionado.',
      );
    }

    String message =
        'No fue posible registrar la ordeña (${response.statusCode}).';

    if (decoded is Map<String, dynamic>) {
      final dynamic serverMessage = decoded['message'];

      if (serverMessage != null && serverMessage.toString().trim().isNotEmpty) {
        message = serverMessage.toString();
      }
    }

    throw Exception(
      message,
    );
  }

  // =========================================================
  // OBTENER ORDEÑAS DE UNA FECHA
  // =========================================================

  Future<List<MilkingRecord>> getMilkingsByDate(
    DateTime date,
  ) async {
    final List<Map<String, dynamic>> milkings = await _getApiMilkings();

    final List<MilkingRecord> result = [];

    for (final Map<String, dynamic> milking in milkings) {
      final DateTime? milkingDate = DateTime.tryParse(
        milking['fecha']?.toString() ?? '',
      );

      if (milkingDate == null) {
        continue;
      }

      final bool sameDate = milkingDate.year == date.year &&
          milkingDate.month == date.month &&
          milkingDate.day == date.day;

      if (!sameDate) {
        continue;
      }

      result.add(
        MilkingRecord.fromApi(
          milking,
        ),
      );
    }

    result.sort(
      (MilkingRecord a, MilkingRecord b) {
        final int cattleComparison = a.cattleId.compareTo(b.cattleId);

        if (cattleComparison != 0) {
          return cattleComparison;
        }

        return a.milkingNumber.compareTo(
          b.milkingNumber,
        );
      },
    );

    return result;
  }

  // =========================================================
  // ORDEÑAS DE UNA VACA EN UNA FECHA
  // =========================================================

  Future<List<MilkingRecord>> getMilkingsByCattleAndDate({
    required int cattleId,
    required DateTime date,
  }) async {
    final List<Map<String, dynamic>> milkings = await _getApiMilkings();

    final List<MilkingRecord> result = [];

    for (final Map<String, dynamic> milking in milkings) {
      final int? milkingCattleId = _toInt(
        milking['ganado_id'],
      );

      if (milkingCattleId != cattleId) {
        continue;
      }

      final DateTime? milkingDate = DateTime.tryParse(
        milking['fecha']?.toString() ?? '',
      );

      if (milkingDate == null) {
        continue;
      }

      final bool sameDate = milkingDate.year == date.year &&
          milkingDate.month == date.month &&
          milkingDate.day == date.day;

      if (!sameDate) {
        continue;
      }

      result.add(
        MilkingRecord.fromApi(
          milking,
        ),
      );
    }

    result.sort(
      (MilkingRecord a, MilkingRecord b) {
        return a.milkingNumber.compareTo(
          b.milkingNumber,
        );
      },
    );

    return result;
  }

  // =========================================================
  // PRODUCCIÓN TOTAL DE UN DÍA
  // =========================================================

  Future<double> getDailyProduction(
    DateTime date,
  ) async {
    final List<Map<String, dynamic>> milkings = await _getApiMilkings();

    double total = 0.0;

    for (final Map<String, dynamic> milking in milkings) {
      final DateTime? milkingDate = DateTime.tryParse(
        milking['fecha']?.toString() ?? '',
      );

      if (milkingDate == null) {
        continue;
      }

      final bool sameDate = milkingDate.year == date.year &&
          milkingDate.month == date.month &&
          milkingDate.day == date.day;

      if (!sameDate) {
        continue;
      }

      total += _toDouble(
        milking['litros'],
      );
    }

    return total;
  }

  // =========================================================
  // PRODUCCIÓN DE UNA VACA EN UN DÍA
  // =========================================================

  Future<double> getDailyProductionByCattle({
    required int cattleId,
    required DateTime date,
  }) async {
    final List<Map<String, dynamic>> milkings = await _getApiMilkings();

    double total = 0.0;

    for (final Map<String, dynamic> milking in milkings) {
      final int? milkingCattleId = _toInt(
        milking['ganado_id'],
      );

      if (milkingCattleId != cattleId) {
        continue;
      }

      final DateTime? milkingDate = DateTime.tryParse(
        milking['fecha']?.toString() ?? '',
      );

      if (milkingDate == null) {
        continue;
      }

      final bool sameDate = milkingDate.year == date.year &&
          milkingDate.month == date.month &&
          milkingDate.day == date.day;

      if (!sameDate) {
        continue;
      }

      total += _toDouble(
        milking['litros'],
      );
    }

    return total;
  }

  // =========================================================
  // PRODUCCIÓN DE UN LOTE EN UN DÍA
  // =========================================================

  Future<double> getDailyProductionByLot({
    required int lotId,
    required DateTime date,
  }) async {
    final List<Map<String, dynamic>> milkings = await _getApiMilkings();

    double total = 0.0;

    for (final Map<String, dynamic> milking in milkings) {
      final int? historicalLotId = _toInt(milking['lote_historico_id']);

      if (historicalLotId != lotId) {
        continue;
      }

      final DateTime? milkingDate = DateTime.tryParse(
        milking['fecha']?.toString() ?? '',
      );

      if (milkingDate == null) {
        continue;
      }

      final bool sameDate = milkingDate.year == date.year &&
          milkingDate.month == date.month &&
          milkingDate.day == date.day;

      if (!sameDate) {
        continue;
      }

      total += _toDouble(
        milking['litros'],
      );
    }

    return total;
  }

  // =========================================================
  // PRODUCCIÓN TOTAL DEL MES
  // =========================================================

  Future<double> getMonthlyProduction(
    DateTime month,
  ) async {
    final database = await _databaseHelper.database;

    final int userId = _requireUserId();

    final DateTime firstDay = DateTime(
      month.year,
      month.month,
      1,
    );

    final DateTime nextMonth = DateTime(
      month.year,
      month.month + 1,
      1,
    );

    final List<Map<String, dynamic>> result = await database.rawQuery(
      '''
      SELECT COALESCE(
        SUM(liters),
        0
      ) AS total
      FROM ${DatabaseHelper.milkingRecordsTable}
      WHERE user_id = ?
        AND date >= ?
        AND date < ?
      ''',
      [
        userId,
        _formatDate(firstDay),
        _formatDate(nextMonth),
      ],
    );

    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  // =========================================================
  // PRODUCCIÓN MENSUAL POR VACA
  // =========================================================

  Future<double> getMonthlyProductionByCattle({
    required int cattleId,
    required DateTime month,
  }) async {
    final database = await _databaseHelper.database;

    final int userId = _requireUserId();

    final DateTime firstDay = DateTime(
      month.year,
      month.month,
      1,
    );

    final DateTime nextMonth = DateTime(
      month.year,
      month.month + 1,
      1,
    );

    final List<Map<String, dynamic>> result = await database.rawQuery(
      '''
      SELECT COALESCE(
        SUM(liters),
        0
      ) AS total
      FROM ${DatabaseHelper.milkingRecordsTable}
      WHERE user_id = ?
        AND cattle_id = ?
        AND date >= ?
        AND date < ?
      ''',
      [
        userId,
        cattleId,
        _formatDate(firstDay),
        _formatDate(nextMonth),
      ],
    );

    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  // =========================================================
  // PRODUCCIÓN MENSUAL POR LOTE
  // =========================================================

  Future<double> getMonthlyProductionByLot({
    required int lotId,
    required DateTime month,
  }) async {
    final List<Map<String, dynamic>> milkings = await _getApiMilkings();

    double total = 0.0;

    for (final Map<String, dynamic> milking in milkings) {
      final int? historicalLotId = _toInt(milking['lote_historico_id']);

      if (historicalLotId != lotId) {
        continue;
      }

      final DateTime? milkingDate = DateTime.tryParse(
        milking['fecha']?.toString() ?? '',
      );

      if (milkingDate == null) {
        continue;
      }

      if (milkingDate.year != month.year || milkingDate.month != month.month) {
        continue;
      }

      total += _toDouble(
        milking['litros'],
      );
    }

    return total;
  }

  Future<Map<int, double>> getDailyProductionForCattleInMonth({
    required int cattleId,
    required DateTime month,
  }) async {
    final database = await _databaseHelper.database;

    final int userId = _requireUserId();

    final DateTime firstDay = DateTime(
      month.year,
      month.month,
      1,
    );

    final DateTime nextMonth = DateTime(
      month.year,
      month.month + 1,
      1,
    );

    final List<Map<String, dynamic>> result = await database.rawQuery(
      '''
    SELECT
      CAST(
        strftime('%d', date)
        AS INTEGER
      ) AS day,
      COALESCE(
        SUM(liters),
        0
      ) AS total
    FROM ${DatabaseHelper.milkingRecordsTable}
    WHERE user_id = ?
      AND cattle_id = ?
      AND date >= ?
      AND date < ?
    GROUP BY date
    ORDER BY date
    ''',
      [
        userId,
        cattleId,
        _formatDate(firstDay),
        _formatDate(nextMonth),
      ],
    );

    final Map<int, double> productionByDay = {};

    for (final Map<String, dynamic> row in result) {
      final int day = (row['day'] as num).toInt();

      final double total = (row['total'] as num?)?.toDouble() ?? 0.0;

      productionByDay[day] = total;
    }

    return productionByDay;
  }
  // =========================================================
  // ELIMINAR ORDEÑA
  // =========================================================

  Future<int> deleteMilking(
    int milkingId,
  ) async {
    final response = await ApiClient.instance.delete(
      '/ordenios/$milkingId',
    );

    if (response.statusCode == 200 || response.statusCode == 204) {
      return 1;
    }

    if (response.statusCode == 401) {
      throw Exception(
        'La sesión ha expirado. Inicia sesión nuevamente.',
      );
    }

    if (response.statusCode == 403) {
      throw Exception(
        'No tienes permiso para eliminar esta ordeña.',
      );
    }

    if (response.statusCode == 404) {
      throw Exception(
        'La ordeña ya no existe o no fue encontrada.',
      );
    }

    String message =
        'No fue posible eliminar la ordeña (${response.statusCode}).';

    try {
      final dynamic decoded = jsonDecode(response.body);

      if (decoded is Map<String, dynamic>) {
        final dynamic serverMessage = decoded['message'];

        if (serverMessage != null &&
            serverMessage.toString().trim().isNotEmpty) {
          message = serverMessage.toString();
        }
      }
    } catch (_) {
      // Conserva el mensaje predeterminado.
    }

    throw Exception(message);
  }

  Future<Map<int, double>> getDailyProductionForMonth(
    DateTime month,
  ) async {
    final List<Map<String, dynamic>> milkings = await _getApiMilkings();

    final Map<int, double> productionByDay = {};

    for (final Map<String, dynamic> milking in milkings) {
      final DateTime? date = DateTime.tryParse(
        milking['fecha']?.toString() ?? '',
      );

      if (date == null) {
        continue;
      }

      if (date.year != month.year || date.month != month.month) {
        continue;
      }

      final double liters = _toDouble(
        milking['litros'],
      );

      productionByDay[date.day] = (productionByDay[date.day] ?? 0.0) + liters;
    }

    return productionByDay;
  }

  // =========================================================
  // FORMATO DE FECHA PARA SQLITE
  // =========================================================
  Future<Map<String, double>> getMonthlyProductionByLots(
    DateTime month,
  ) async {
    final List<Map<String, dynamic>> milkings = await _getApiMilkings();

    final Map<String, double> productionByLot = {};

    for (final Map<String, dynamic> milking in milkings) {
      final DateTime? date = DateTime.tryParse(
        milking['fecha']?.toString() ?? '',
      );

      if (date == null) {
        continue;
      }

      if (date.year != month.year || date.month != month.month) {
        continue;
      }

      final dynamic lotData = milking['lote_historico'];

      String lotName = 'Sin lote';

      if (lotData is Map<String, dynamic>) {
        final String name = lotData['nombre']?.toString().trim() ?? '';

        if (name.isNotEmpty) {
          lotName = name;
        }
      }

      final double liters = _toDouble(
        milking['litros'],
      );

      productionByLot[lotName] = (productionByLot[lotName] ?? 0.0) + liters;
    }

    return productionByLot;
  }

  String _formatDate(
    DateTime date,
  ) {
    final String year = date.year.toString();

    final String month = date.month.toString().padLeft(2, '0');

    final String day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  int? _toInt(
    dynamic value,
  ) {
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

  double _toDouble(
    dynamic value,
  ) {
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
