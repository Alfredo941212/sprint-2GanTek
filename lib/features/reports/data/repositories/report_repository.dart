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

    /*
     * GANADO
     */

    final int totalCattle = Sqflite.firstIntValue(
          await database.rawQuery(
            '''
                SELECT COUNT(*)
                FROM ${DatabaseHelper.cattleTable}
                WHERE user_id = ?
                ''',
            [userId],
          ),
        ) ??
        0;

    final int soldCattle = Sqflite.firstIntValue(
          await database.rawQuery(
            '''
            SELECT COUNT(DISTINCT cattle_id)
            FROM ${DatabaseHelper.salesTable}
            WHERE user_id = ?
              AND status = ?
            ''',
            [
              userId,
              'completada',
            ],
          ),
        ) ??
        0;

    final int availableCattle = totalCattle - soldCattle;

    /*
     * VENTAS
     */

    final List<String> saleConditions = [
      'user_id = ?',
      'status = ?',
    ];

    final List<Object?> saleArguments = [
      userId,
      'completada',
    ];

    if (startDate != null) {
      final DateTime normalizedStart = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
      );

      saleConditions.add(
        'sale_date >= ?',
      );

      saleArguments.add(
        normalizedStart.toIso8601String(),
      );
    }

    if (endDate != null) {
      final DateTime normalizedEnd = DateTime(
        endDate.year,
        endDate.month,
        endDate.day,
        23,
        59,
        59,
        999,
      );

      saleConditions.add(
        'sale_date <= ?',
      );

      saleArguments.add(
        normalizedEnd.toIso8601String(),
      );
    }

    final String saleWhere = saleConditions.join(' AND ');

    final int completedSales = Sqflite.firstIntValue(
          await database.rawQuery(
            '''
                SELECT COUNT(*)
                FROM ${DatabaseHelper.salesTable}
                WHERE $saleWhere
                ''',
            saleArguments,
          ),
        ) ??
        0;

    final List<Map<String, dynamic>> salesResult = await database.rawQuery(
      '''
      SELECT
        COALESCE(SUM(total), 0)
            AS total_sales_amount,
        COALESCE(SUM(sale_weight), 0)
            AS total_sold_weight,
        COALESCE(AVG(price_per_kg), 0)
            AS average_price_per_kg
      FROM ${DatabaseHelper.salesTable}
      WHERE $saleWhere
      ''',
      saleArguments,
    );

    final Map<String, dynamic> salesData = salesResult.first;

    final double totalSalesAmount =
        (salesData['total_sales_amount'] as num?)?.toDouble() ?? 0;

    final double totalSoldWeight =
        (salesData['total_sold_weight'] as num?)?.toDouble() ?? 0;

    final double averagePricePerKg =
        (salesData['average_price_per_kg'] as num?)?.toDouble() ?? 0;

    /*
     * VACUNAS
     */

    final int appliedVaccines = Sqflite.firstIntValue(
          await database.rawQuery(
            '''
                SELECT COUNT(*)
                FROM ${DatabaseHelper.vaccinesTable}
                WHERE user_id = ?
                ''',
            [userId],
          ),
        ) ??
        0;

    final DateTime now = DateTime.now();

    final DateTime today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final DateTime nextThirtyDays = today.add(
      const Duration(days: 30),
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
              today.toIso8601String(),
              nextThirtyDays.toIso8601String(),
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
              today.toIso8601String(),
            ],
          ),
        ) ??
        0;

    return ReportSummary(
      totalCattle: totalCattle,
      availableCattle: availableCattle,
      soldCattle: soldCattle,
      completedSales: completedSales,
      totalSalesAmount: totalSalesAmount,
      totalSoldWeight: totalSoldWeight,
      averagePricePerKg: averagePricePerKg,
      appliedVaccines: appliedVaccines,
      upcomingVaccines: upcomingVaccines,
      overdueVaccines: overdueVaccines,
    );
  }

  Future<List<RecentSaleReport>> getRecentSales({
    required int userId,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 5,
  }) async {
    final Database database = await _databaseHelper.database;

    final List<String> conditions = [
      'user_id = ?',
      'status = ?',
    ];

    final List<Object?> arguments = [
      userId,
      'completada',
    ];

    if (startDate != null) {
      final DateTime normalizedStart = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
      );

      conditions.add(
        'sale_date >= ?',
      );

      arguments.add(
        normalizedStart.toIso8601String(),
      );
    }

    if (endDate != null) {
      final DateTime normalizedEnd = DateTime(
        endDate.year,
        endDate.month,
        endDate.day,
        23,
        59,
        59,
        999,
      );

      conditions.add(
        'sale_date <= ?',
      );

      arguments.add(
        normalizedEnd.toIso8601String(),
      );
    }

    final List<Map<String, dynamic>> result = await database.query(
      DatabaseHelper.salesTable,
      where: conditions.join(' AND '),
      whereArgs: arguments,
      orderBy: 'sale_date DESC',
      limit: limit,
    );

    return result
        .map(
          RecentSaleReport.fromMap,
        )
        .toList();
  }
}
