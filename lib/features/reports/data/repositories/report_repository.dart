import 'package:sqflite/sqflite.dart';

import 'package:gantek/core/database/database_helper.dart';
import 'package:gantek/features/reports/data/models/report_summary.dart';

class ReportRepository {
  ReportRepository({
    DatabaseHelper? databaseHelper,
  }) : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;

  Future<ReportSummary> getSummary({
    required int userId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final Database database = await _databaseHelper.database;

    // =======================================================
    // RANGO DE FECHAS
    // =======================================================

    final DateTime now = DateTime.now();

    final DateTime defaultStart = DateTime(
      now.year,
      now.month,
      1,
    );

    final DateTime defaultEnd = DateTime(
      now.year,
      now.month + 1,
      1,
    ).subtract(
      const Duration(days: 1),
    );

    final DateTime normalizedStart = DateTime(
      (startDate ?? defaultStart).year,
      (startDate ?? defaultStart).month,
      (startDate ?? defaultStart).day,
    );

    final DateTime normalizedEnd = DateTime(
      (endDate ?? defaultEnd).year,
      (endDate ?? defaultEnd).month,
      (endDate ?? defaultEnd).day,
    );

    final String startDateText = _formatDate(
      normalizedStart,
    );

    final String endDateText = _formatDate(
      normalizedEnd,
    );

    // =======================================================
    // GANADO TOTAL
    // =======================================================

    final int totalCattle = Sqflite.firstIntValue(
          await database.rawQuery(
            '''
            SELECT COUNT(*)
            FROM ${DatabaseHelper.cattleTable}
            WHERE user_id = ?
              AND status = 'Activo'
            ''',
            [
              userId,
            ],
          ),
        ) ??
        0;

    // =======================================================
    // VACAS EN PRODUCCIÓN
    // =======================================================

    final int productiveCattle = Sqflite.firstIntValue(
          await database.rawQuery(
            '''
            SELECT COUNT(*)
            FROM ${DatabaseHelper.cattleTable}
            WHERE user_id = ?
              AND status = 'Activo'
              AND sex = 'Hembra'
              AND productive_status = 'En producción'
            ''',
            [
              userId,
            ],
          ),
        ) ??
        0;

    // =======================================================
    // VACAS SECAS
    // =======================================================

    final int dryCattle = Sqflite.firstIntValue(
          await database.rawQuery(
            '''
            SELECT COUNT(*)
            FROM ${DatabaseHelper.cattleTable}
            WHERE user_id = ?
              AND status = 'Activo'
              AND sex = 'Hembra'
              AND productive_status = 'Seca'
            ''',
            [
              userId,
            ],
          ),
        ) ??
        0;

    // =======================================================
    // PRODUCCIÓN DE LECHE DEL PERIODO
    // =======================================================

    final List<Map<String, dynamic>> milkResult = await database.rawQuery(
      '''
      SELECT
        COALESCE(
          SUM(liters),
          0
        ) AS total_liters,
        COUNT(*) AS total_milkings,
        COUNT(
          DISTINCT date
        ) AS production_days
      FROM ${DatabaseHelper.milkingRecordsTable}
      WHERE user_id = ?
        AND date >= ?
        AND date <= ?
      ''',
      [
        userId,
        startDateText,
        endDateText,
      ],
    );

    final Map<String, dynamic> milkData = milkResult.first;

    final double totalMilkProduction =
        (milkData['total_liters'] as num?)?.toDouble() ?? 0.0;

    final int totalMilkings =
        (milkData['total_milkings'] as num?)?.toInt() ?? 0;

    final int productionDays =
        (milkData['production_days'] as num?)?.toInt() ?? 0;

    // =======================================================
    // PROMEDIO DIARIO
    // =======================================================

    final double averageDailyProduction =
        productionDays > 0 ? totalMilkProduction / productionDays : 0.0;

    // =======================================================
    // PROMEDIO POR VACA
    // =======================================================

    final double averageProductionPerCow =
        productiveCattle > 0 ? totalMilkProduction / productiveCattle : 0.0;

    // =======================================================
    // VACUNAS APLICADAS
    // =======================================================

    final List<String> vaccineConditions = [
      'user_id = ?',
    ];

    final List<Object?> vaccineArguments = [
      userId,
    ];

    if (startDate != null) {
      vaccineConditions.add(
        'application_date >= ?',
      );

      vaccineArguments.add(
        startDateText,
      );
    }

    if (endDate != null) {
      vaccineConditions.add(
        'application_date <= ?',
      );

      vaccineArguments.add(
        endDateText,
      );
    }

    final int appliedVaccines = Sqflite.firstIntValue(
          await database.rawQuery(
            '''
                SELECT COUNT(*)
                FROM ${DatabaseHelper.vaccinesTable}
                WHERE ${vaccineConditions.join(' AND ')}
                ''',
            vaccineArguments,
          ),
        ) ??
        0;

    // =======================================================
    // VACUNAS PRÓXIMAS Y VENCIDAS
    // =======================================================

    final DateTime today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final DateTime nextThirtyDays = today.add(
      const Duration(
        days: 30,
      ),
    );

    final String todayText = _formatDate(
      today,
    );

    final String nextThirtyDaysText = _formatDate(
      nextThirtyDays,
    );

    final int upcomingVaccines = Sqflite.firstIntValue(
          await database.rawQuery(
            '''
                SELECT COUNT(*)
                FROM ${DatabaseHelper.vaccinesTable}
                WHERE user_id = ?
                  AND next_dose_date IS NOT NULL
                  AND next_dose_date >= ?
                  AND next_dose_date <= ?
                ''',
            [
              userId,
              todayText,
              nextThirtyDaysText,
            ],
          ),
        ) ??
        0;

    final int overdueVaccines = Sqflite.firstIntValue(
          await database.rawQuery(
            '''
                SELECT COUNT(*)
                FROM ${DatabaseHelper.vaccinesTable}
                WHERE user_id = ?
                  AND next_dose_date IS NOT NULL
                  AND next_dose_date < ?
                ''',
            [
              userId,
              todayText,
            ],
          ),
        ) ??
        0;

    // =======================================================
    // ALERTAS DE BAJA PRODUCCIÓN
    // =======================================================

    final List<Map<String, dynamic>> lowProductionResult =
        await database.rawQuery(
      '''
      SELECT COUNT(*) AS total
      FROM (
        SELECT
          c.id
        FROM ${DatabaseHelper.cattleTable} c

        LEFT JOIN ${DatabaseHelper.milkingRecordsTable} m
          ON m.cattle_id = c.id
          AND m.user_id = c.user_id
          AND m.date >= ?
          AND m.date <= ?

        WHERE c.user_id = ?
          AND c.status = 'Activo'
          AND c.sex = 'Hembra'
          AND c.productive_status = 'En producción'

        GROUP BY
          c.id,
          c.minimum_daily_production

        HAVING
          COALESCE(
            SUM(m.liters),
            0
          ) <
          (
            c.minimum_daily_production *
            (
              JULIANDAY(?) -
              JULIANDAY(?) +
              1
            )
          )
      )
      ''',
      [
        startDateText,
        endDateText,
        userId,
        endDateText,
        startDateText,
      ],
    );

    final int lowProductionAlerts =
        (lowProductionResult.first['total'] as num?)?.toInt() ?? 0;

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
    final Database database = await _databaseHelper.database;

    final DateTime now = DateTime.now();

    final DateTime defaultStart = DateTime(
      now.year,
      now.month,
      1,
    );

    final DateTime defaultEnd = DateTime(
      now.year,
      now.month + 1,
      1,
    ).subtract(
      const Duration(
        days: 1,
      ),
    );

    final DateTime normalizedStart = DateTime(
      (startDate ?? defaultStart).year,
      (startDate ?? defaultStart).month,
      (startDate ?? defaultStart).day,
    );

    final DateTime normalizedEnd = DateTime(
      (endDate ?? defaultEnd).year,
      (endDate ?? defaultEnd).month,
      (endDate ?? defaultEnd).day,
    );

    final List<Map<String, dynamic>> result = await database.rawQuery(
      '''
      SELECT
        l.id AS lot_id,
        l.name AS lot_name,
        COALESCE(
          SUM(m.liters),
          0
        ) AS total_liters
      FROM ${DatabaseHelper.lotsTable} l

      LEFT JOIN ${DatabaseHelper.milkingRecordsTable} m
        ON m.historical_lot_id = l.id
        AND m.user_id = ?
        AND m.date >= ?
        AND m.date <= ?

      WHERE l.user_id = ?
        AND l.status = 'Activo'

      GROUP BY
        l.id,
        l.name

      ORDER BY
        total_liters DESC,
        l.name ASC
      ''',
      [
        userId,
        _formatDate(
          normalizedStart,
        ),
        _formatDate(
          normalizedEnd,
        ),
        userId,
      ],
    );

    return result
        .map(
          LotProductionReport.fromMap,
        )
        .toList();
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
    final Database database = await _databaseHelper.database;

    final List<String> conditions = [
      'm.user_id = ?',
    ];

    final List<Object?> arguments = [
      userId,
    ];

    if (startDate != null) {
      final DateTime normalizedStart = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
      );

      conditions.add(
        'm.date >= ?',
      );

      arguments.add(
        _formatDate(
          normalizedStart,
        ),
      );
    }

    if (endDate != null) {
      final DateTime normalizedEnd = DateTime(
        endDate.year,
        endDate.month,
        endDate.day,
      );

      conditions.add(
        'm.date <= ?',
      );

      arguments.add(
        _formatDate(
          normalizedEnd,
        ),
      );
    }

    final List<Map<String, dynamic>> result = await database.rawQuery(
      '''
      SELECT
        m.id,
        c.code AS cattle_code,
        c.name AS cattle_name,
        COALESCE(
          l.name,
          'Sin lote'
        ) AS lot_name,
        m.date,
        m.milking_number,
        m.shift,
        m.liters
      FROM ${DatabaseHelper.milkingRecordsTable} m

      INNER JOIN ${DatabaseHelper.cattleTable} c
        ON c.id = m.cattle_id

      LEFT JOIN ${DatabaseHelper.lotsTable} l
        ON l.id = m.historical_lot_id

      WHERE ${conditions.join(' AND ')}

      ORDER BY
        m.date DESC,
        m.milking_number DESC

      LIMIT ?
      ''',
      [
        ...arguments,
        limit,
      ],
    );

    return result
        .map(
          RecentMilkingReport.fromMap,
        )
        .toList();
  }

  String _formatDate(
    DateTime date,
  ) {
    final String year = date.year.toString();

    final String month = date.month.toString().padLeft(
          2,
          '0',
        );

    final String day = date.day.toString().padLeft(
          2,
          '0',
        );

    return '$year-$month-$day';
  }
}
