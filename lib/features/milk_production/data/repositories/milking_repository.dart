import '../../../../core/database/database_helper.dart';
import '../../../../core/session/session_manager.dart';
import '../models/milking_record.dart';

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

  Future<List<MilkingRecord>> getRecentMilkingsByCattle({
    required int cattleId,
    int limit = 10,
  }) async {
    final database = await _databaseHelper.database;
    final int userId = _requireUserId();

    final List<Map<String, dynamic>> result = await database.query(
      DatabaseHelper.milkingRecordsTable,
      where: '''
      user_id = ?
      AND cattle_id = ?
    ''',
      whereArgs: [
        userId,
        cattleId,
      ],
      orderBy: '''
      date DESC,
      milking_number DESC
    ''',
      limit: limit,
    );

    return result
        .map(
          (Map<String, dynamic> row) => MilkingRecord.fromMap(row),
        )
        .toList();
  }
  // =========================================================
  // REGISTRAR ORDEÑA
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

    final database = await _databaseHelper.database;

    final int userId = _requireUserId();

    final String dateText = _formatDate(date);

    return database.transaction<int>(
      (transaction) async {
        // ---------------------------------------------
        // Verificar que la vaca pertenece al usuario
        // ---------------------------------------------

        final List<Map<String, dynamic>> cattleResult = await transaction.query(
          DatabaseHelper.cattleTable,
          columns: [
            'id',
            'lot_id',
            'sex',
            'productive_status',
            'status',
          ],
          where: '''
            id = ?
            AND user_id = ?
          ''',
          whereArgs: [
            cattleId,
            userId,
          ],
          limit: 1,
        );

        if (cattleResult.isEmpty) {
          throw Exception(
            'El animal seleccionado no existe.',
          );
        }

        final Map<String, dynamic> cattle = cattleResult.first;

        if (cattle['status'] != 'Activo') {
          throw Exception(
            'No se pueden registrar ordeñas para un animal inactivo.',
          );
        }

        if (cattle['sex'] != 'Hembra') {
          throw Exception(
            'Solo se puede registrar producción de leche para hembras.',
          );
        }

        if (cattle['productive_status'] != 'En producción') {
          throw Exception(
            'La vaca seleccionada no está marcada como En producción.',
          );
        }

        final int? historicalLotId = (cattle['lot_id'] as num?)?.toInt();

        // ---------------------------------------------
        // Calcular siguiente número de ordeña
        // ---------------------------------------------

        final List<Map<String, dynamic>> numberResult =
            await transaction.rawQuery(
          '''
          SELECT COALESCE(
            MAX(milking_number),
            0
          ) + 1 AS next_number
          FROM ${DatabaseHelper.milkingRecordsTable}
          WHERE cattle_id = ?
            AND date = ?
          ''',
          [
            cattleId,
            dateText,
          ],
        );

        final int milkingNumber =
            (numberResult.first['next_number'] as num?)?.toInt() ?? 1;

        final MilkingRecord record = MilkingRecord(
          userId: userId,
          cattleId: cattleId,
          historicalLotId: historicalLotId,
          date: date,
          milkingNumber: milkingNumber,
          shift: shift,
          liters: liters,
          observations: observations,
          createdAt: DateTime.now(),
        );

        return transaction.insert(
          DatabaseHelper.milkingRecordsTable,
          record.toMap(),
        );
      },
    );
  }

  // =========================================================
  // OBTENER ORDEÑAS DE UNA FECHA
  // =========================================================

  Future<List<MilkingRecord>> getMilkingsByDate(
    DateTime date,
  ) async {
    final database = await _databaseHelper.database;

    final int userId = _requireUserId();

    final List<Map<String, dynamic>> maps = await database.query(
      DatabaseHelper.milkingRecordsTable,
      where: '''
        user_id = ?
        AND date = ?
      ''',
      whereArgs: [
        userId,
        _formatDate(date),
      ],
      orderBy: 'cattle_id ASC, milking_number ASC',
    );

    return maps.map(MilkingRecord.fromMap).toList();
  }

  // =========================================================
  // ORDEÑAS DE UNA VACA EN UNA FECHA
  // =========================================================

  Future<List<MilkingRecord>> getMilkingsByCattleAndDate({
    required int cattleId,
    required DateTime date,
  }) async {
    final database = await _databaseHelper.database;

    final int userId = _requireUserId();

    final List<Map<String, dynamic>> maps = await database.query(
      DatabaseHelper.milkingRecordsTable,
      where: '''
        user_id = ?
        AND cattle_id = ?
        AND date = ?
      ''',
      whereArgs: [
        userId,
        cattleId,
        _formatDate(date),
      ],
      orderBy: 'milking_number ASC',
    );

    return maps.map(MilkingRecord.fromMap).toList();
  }

  // =========================================================
  // PRODUCCIÓN TOTAL DE UN DÍA
  // =========================================================

  Future<double> getDailyProduction(
    DateTime date,
  ) async {
    final database = await _databaseHelper.database;

    final int userId = _requireUserId();

    final List<Map<String, dynamic>> result = await database.rawQuery(
      '''
      SELECT COALESCE(
        SUM(liters),
        0
      ) AS total
      FROM ${DatabaseHelper.milkingRecordsTable}
      WHERE user_id = ?
        AND date = ?
      ''',
      [
        userId,
        _formatDate(date),
      ],
    );

    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  // =========================================================
  // PRODUCCIÓN DE UNA VACA EN UN DÍA
  // =========================================================

  Future<double> getDailyProductionByCattle({
    required int cattleId,
    required DateTime date,
  }) async {
    final database = await _databaseHelper.database;

    final int userId = _requireUserId();

    final List<Map<String, dynamic>> result = await database.rawQuery(
      '''
      SELECT COALESCE(
        SUM(liters),
        0
      ) AS total
      FROM ${DatabaseHelper.milkingRecordsTable}
      WHERE user_id = ?
        AND cattle_id = ?
        AND date = ?
      ''',
      [
        userId,
        cattleId,
        _formatDate(date),
      ],
    );

    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  // =========================================================
  // PRODUCCIÓN DE UN LOTE EN UN DÍA
  // =========================================================

  Future<double> getDailyProductionByLot({
    required int lotId,
    required DateTime date,
  }) async {
    final database = await _databaseHelper.database;

    final int userId = _requireUserId();

    final List<Map<String, dynamic>> result = await database.rawQuery(
      '''
      SELECT COALESCE(
        SUM(liters),
        0
      ) AS total
      FROM ${DatabaseHelper.milkingRecordsTable}
      WHERE user_id = ?
        AND historical_lot_id = ?
        AND date = ?
      ''',
      [
        userId,
        lotId,
        _formatDate(date),
      ],
    );

    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
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
        AND historical_lot_id = ?
        AND date >= ?
        AND date < ?
      ''',
      [
        userId,
        lotId,
        _formatDate(firstDay),
        _formatDate(nextMonth),
      ],
    );

    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
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
    final database = await _databaseHelper.database;

    final int userId = _requireUserId();

    return database.delete(
      DatabaseHelper.milkingRecordsTable,
      where: '''
        id = ?
        AND user_id = ?
      ''',
      whereArgs: [
        milkingId,
        userId,
      ],
    );
  }

  Future<Map<int, double>> getDailyProductionForMonth(
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
    SELECT
      date,
      COALESCE(
        SUM(liters),
        0
      ) AS total
    FROM ${DatabaseHelper.milkingRecordsTable}
    WHERE user_id = ?
      AND date >= ?
      AND date < ?
    GROUP BY date
    ORDER BY date ASC
    ''',
      [
        userId,
        _formatDate(firstDay),
        _formatDate(nextMonth),
      ],
    );

    final Map<int, double> productionByDay = {};
    // =========================================================
    // FORMATO DE GRAFICA
    // =========================================================
    for (final Map<String, dynamic> row in result) {
      final String? dateText = row['date']?.toString();

      if (dateText == null) {
        continue;
      }

      final DateTime? date = DateTime.tryParse(
        dateText,
      );

      if (date == null) {
        continue;
      }

      final double total = (row['total'] as num?)?.toDouble() ?? 0.0;

      productionByDay[date.day] = total;
    }

    return productionByDay;
  }

  // =========================================================
  // FORMATO DE FECHA PARA SQLITE
  // =========================================================
  Future<Map<String, double>> getMonthlyProductionByLots(
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
    SELECT
      l.name AS lot_name,
      COALESCE(
        SUM(m.liters),
        0
      ) AS total
    FROM ${DatabaseHelper.milkingRecordsTable} m
    INNER JOIN ${DatabaseHelper.lotsTable} l
      ON l.id = m.historical_lot_id
    WHERE m.user_id = ?
      AND m.date >= ?
      AND m.date < ?
    GROUP BY
      m.historical_lot_id,
      l.name
    ORDER BY
      total DESC
    ''',
      [
        userId,
        _formatDate(firstDay),
        _formatDate(nextMonth),
      ],
    );

    final Map<String, double> productionByLot = {};

    for (final Map<String, dynamic> row in result) {
      final String lotName = row['lot_name']?.toString().trim() ?? 'Sin lote';

      final double total = (row['total'] as num?)?.toDouble() ?? 0.0;

      productionByLot[lotName] = total;
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
}
