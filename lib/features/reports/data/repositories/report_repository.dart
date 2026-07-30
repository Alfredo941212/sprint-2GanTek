import 'package:sqflite/sqflite.dart';

import '../../../../core/database/database_helper.dart';
import '../models/report_summary.dart';

class ReportRepository {
  final DatabaseHelper _databaseHelper;

  ReportRepository({
    DatabaseHelper? databaseHelper,
  }) : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  Future<ReportSummary> getSummary({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final Database database = await _databaseHelper.database;

    final int totalCattle = Sqflite.firstIntValue(
          await database.rawQuery(
            '''
            SELECT COUNT(*)
            FROM ${DatabaseHelper.cattleTable}
            ''',
          ),
        ) ??
        0;

    final int soldCattle = Sqflite.firstIntValue(
          await database.rawQuery(
            '''
            SELECT COUNT(DISTINCT cattle_id)
            FROM ${DatabaseHelper.salesTable}
            WHERE status = 'completada'
            ''',
          ),
        ) ??
        0;

    final int availableCattle =
        (totalCattle - soldCattle).clamp(0, totalCattle);

    final String salesCondition = _buildSalesDateCondition(
      startDate: startDate,
      endDate: endDate,
    );

    final List<Object?> salesArguments = _buildSalesDateArguments(
      startDate: startDate,
      endDate: endDate,
    );

    final List<Map<String, dynamic>> salesResult = await database.rawQuery(
      '''
      SELECT
        COUNT(*) AS completed_sales,
        COALESCE(SUM(total), 0) AS total_sales,
        COALESCE(SUM(sale_weight), 0) AS sold_weight,
        COALESCE(AVG(price_per_kg), 0) AS average_price
      FROM ${DatabaseHelper.salesTable}
      WHERE status = 'completada'
      $salesCondition
      ''',
      salesArguments,
    );

    final Map<String, dynamic> salesData = salesResult.first;

    final DateTime today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    final DateTime nextThirtyDays = today.add(
      const Duration(days: 30),
    );

    final int appliedVaccines = Sqflite.firstIntValue(
          await database.rawQuery(
            '''
            SELECT COUNT(*)
            FROM ${DatabaseHelper.vaccinesTable}
            ''',
          ),
        ) ??
        0;

    final int upcomingVaccines = Sqflite.firstIntValue(
          await database.rawQuery(
            '''
            SELECT COUNT(*)
            FROM ${DatabaseHelper.vaccinesTable}
            WHERE next_dose_date IS NOT NULL
              AND next_dose_date >= ?
              AND next_dose_date <= ?
            ''',
            [
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
            WHERE next_dose_date IS NOT NULL
              AND next_dose_date < ?
            ''',
            [
              today.toIso8601String(),
            ],
          ),
        ) ??
        0;

    return ReportSummary(
      totalCattle: totalCattle,
      availableCattle: availableCattle,
      soldCattle: soldCattle,
      completedSales: (salesData['completed_sales'] as num?)?.toInt() ?? 0,
      totalSalesAmount: (salesData['total_sales'] as num?)?.toDouble() ?? 0,
      totalSoldWeight: (salesData['sold_weight'] as num?)?.toDouble() ?? 0,
      averagePricePerKg: (salesData['average_price'] as num?)?.toDouble() ?? 0,
      appliedVaccines: appliedVaccines,
      upcomingVaccines: upcomingVaccines,
      overdueVaccines: overdueVaccines,
    );
  }

  Future<List<RecentSaleReport>> getRecentSales({
    DateTime? startDate,
    DateTime? endDate,
    int limit = 10,
  }) async {
    final Database database = await _databaseHelper.database;

    final String dateCondition = _buildSalesDateCondition(
      startDate: startDate,
      endDate: endDate,
    );

    final List<Object?> arguments = _buildSalesDateArguments(
      startDate: startDate,
      endDate: endDate,
    );

    arguments.add(limit);

    final List<Map<String, dynamic>> result = await database.rawQuery(
      '''
      SELECT
        id,
        cattle_code,
        buyer_name,
        sale_date,
        sale_weight,
        price_per_kg,
        total,
        status
      FROM ${DatabaseHelper.salesTable}
      WHERE status = 'completada'
      $dateCondition
      ORDER BY sale_date DESC
      LIMIT ?
      ''',
      arguments,
    );

    return result.map(RecentSaleReport.fromMap).toList();
  }

  String _buildSalesDateCondition({
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final StringBuffer condition = StringBuffer();

    if (startDate != null) {
      condition.write(' AND sale_date >= ?');
    }

    if (endDate != null) {
      condition.write(' AND sale_date <= ?');
    }

    return condition.toString();
  }

  List<Object?> _buildSalesDateArguments({
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final List<Object?> arguments = <Object?>[];

    if (startDate != null) {
      arguments.add(
        DateTime(
          startDate.year,
          startDate.month,
          startDate.day,
        ).toIso8601String(),
      );
    }

    if (endDate != null) {
      arguments.add(
        DateTime(
          endDate.year,
          endDate.month,
          endDate.day,
          23,
          59,
          59,
          999,
        ).toIso8601String(),
      );
    }

    return arguments;
  }
}
