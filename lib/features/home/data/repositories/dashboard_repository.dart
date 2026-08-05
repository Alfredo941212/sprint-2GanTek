import 'package:sqflite/sqflite.dart';

import '../../../../core/database/database_helper.dart';
import '../../../../core/session/session_manager.dart';
import '../models/dashboard_summary.dart';

class DashboardRepository {
  DashboardRepository({
    DatabaseHelper? databaseHelper,
  }) : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;

  Future<DashboardSummary> getSummary() async {
    final int? userId = SessionManager.instance.currentUserId;

    if (userId == null) {
      return DashboardSummary.empty();
    }

    final Database database = await _databaseHelper.database;

    final int registeredCattle = Sqflite.firstIntValue(
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
                  AND status = 'completada'
                ''',
            [userId],
          ),
        ) ??
        0;

    final int availableCattle =
        registeredCattle - soldCattle < 0 ? 0 : registeredCattle - soldCattle;

    final DateTime now = DateTime.now();

    final DateTime firstDayOfMonth = DateTime(
      now.year,
      now.month,
      1,
    );

    final DateTime firstDayNextMonth = DateTime(
      now.year,
      now.month + 1,
      1,
    );

    final List<Map<String, dynamic>> salesResult = await database.rawQuery(
      '''
      SELECT
        COUNT(*) AS monthly_sales,
        COALESCE(SUM(total), 0) AS monthly_income
      FROM ${DatabaseHelper.salesTable}
      WHERE user_id = ?
        AND status = 'completada'
        AND sale_date >= ?
        AND sale_date < ?
      ''',
      [
        userId,
        firstDayOfMonth.toIso8601String(),
        firstDayNextMonth.toIso8601String(),
      ],
    );

    final Map<String, dynamic> salesData = salesResult.first;

    final int monthlySales = (salesData['monthly_sales'] as num?)?.toInt() ?? 0;

    final double monthlyIncome =
        (salesData['monthly_income'] as num?)?.toDouble() ?? 0;

    /*
     * Todavía no tienes una tabla o columna para
     * publicaciones. Por eso el resultado es 0.
     *
     * Cuando agreguemos el módulo Publicar ganado,
     * este valor consultará la tabla publications.
     */
    const int publishedCattle = 0;

    return DashboardSummary(
      registeredCattle: registeredCattle,
      availableCattle: availableCattle,
      publishedCattle: publishedCattle,
      monthlySales: monthlySales,
      monthlyIncome: monthlyIncome,
    );
  }
}
