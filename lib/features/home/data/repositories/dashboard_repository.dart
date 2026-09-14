import 'package:sqflite/sqflite.dart';

import '../../../../core/database/database_helper.dart';
import '../../../../core/session/session_manager.dart';
import '../models/dashboard_summary.dart';

import '../../../milk_production/data/repositories/production_alert_repository.dart';
import '../../../vaccines/data/repositories/vaccine_repository.dart';

class DashboardRepository {
  DashboardRepository({
    DatabaseHelper? databaseHelper,
  }) : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;

  final ProductionAlertRepository _productionAlertRepository =
      ProductionAlertRepository();

  final VaccineRepository _vaccineRepository = VaccineRepository();

  Future<DashboardSummary> getSummary() async {
    final int? userId = SessionManager.instance.currentUserId;

    if (userId == null) {
      return DashboardSummary.empty();
    }

    final Database database = await _databaseHelper.database;

    // =======================================================
    // FECHA ACTUAL
    // =======================================================

    final DateTime now = DateTime.now();

    final String today = _formatDate(now);

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

    final String firstDayMonth = _formatDate(
      firstDayOfMonth,
    );

    final String firstDayNextMonthText = _formatDate(
      firstDayNextMonth,
    );

    final String todayLabel = _buildDayLabel(now);

    final String monthLabel = _buildMonthLabel(now);

    // =======================================================
    // GANADO REGISTRADO
    // =======================================================

    final int registeredCattle = Sqflite.firstIntValue(
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
    // LOTES DEL GANADO REGISTRADO
    // =======================================================

    final List<Map<String, dynamic>> registeredLotsResult =
        await database.rawQuery(
      '''
      SELECT DISTINCT l.name
      FROM ${DatabaseHelper.cattleTable} c
      INNER JOIN ${DatabaseHelper.lotsTable} l
        ON l.id = c.lot_id
      WHERE c.user_id = ?
        AND c.status = 'Activo'
        AND l.user_id = ?
        AND l.status = 'Activo'
      ORDER BY l.name ASC
      ''',
      [
        userId,
        userId,
      ],
    );

    final List<String> registeredCattleLots = registeredLotsResult
        .map(
          (Map<String, dynamic> row) => row['name']?.toString().trim() ?? '',
        )
        .where(
          (String name) => name.isNotEmpty,
        )
        .toList();

    // =======================================================
    // LOTES CON VACAS EN PRODUCCIÓN
    // =======================================================

    final List<Map<String, dynamic>> productiveLotsResult =
        await database.rawQuery(
      '''
      SELECT DISTINCT l.name
      FROM ${DatabaseHelper.cattleTable} c
      INNER JOIN ${DatabaseHelper.lotsTable} l
        ON l.id = c.lot_id
      WHERE c.user_id = ?
        AND c.status = 'Activo'
        AND c.sex = 'Hembra'
        AND c.productive_status = 'En producción'
        AND l.user_id = ?
        AND l.status = 'Activo'
      ORDER BY l.name ASC
      ''',
      [
        userId,
        userId,
      ],
    );

    final List<String> productiveCattleLots = productiveLotsResult
        .map(
          (Map<String, dynamic> row) => row['name']?.toString().trim() ?? '',
        )
        .where(
          (String name) => name.isNotEmpty,
        )
        .toList();

    // =======================================================
    // PRODUCCIÓN DE HOY
    // =======================================================

    final List<Map<String, dynamic>> todayProductionResult =
        await database.rawQuery(
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
        today,
      ],
    );

    final double todayMilkProduction =
        (todayProductionResult.first['total'] as num?)?.toDouble() ?? 0.0;

    // =======================================================
    // PRODUCCIÓN DEL MES
    // =======================================================

    final List<Map<String, dynamic>> monthlyProductionResult =
        await database.rawQuery(
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
        firstDayMonth,
        firstDayNextMonthText,
      ],
    );

    final double monthlyMilkProduction =
        (monthlyProductionResult.first['total'] as num?)?.toDouble() ?? 0.0;

    // =======================================================
    // PROMEDIO POR VACA
    // =======================================================

    final double averagePerCow =
        productiveCattle > 0 ? todayMilkProduction / productiveCattle : 0.0;

    // =======================================================
    // ALERTAS DE BAJA PRODUCCIÓN
    // =======================================================

    final int lowProductionAlerts =
        await _productionAlertRepository.countAllProductionAlerts();

// =======================================================
// ALERTAS DE VACUNACIÓN
// =======================================================

    final int upcomingVaccines =
        await _vaccineRepository.countUpcomingVaccines();

    final int overdueVaccines = await _vaccineRepository.countOverdueVaccines();

    return DashboardSummary(
      registeredCattle: registeredCattle,
      productiveCattle: productiveCattle,
      todayMilkProduction: todayMilkProduction,
      monthlyMilkProduction: monthlyMilkProduction,
      averagePerCow: averagePerCow,
      lowProductionAlerts: lowProductionAlerts,
      upcomingVaccines: upcomingVaccines,
      overdueVaccines: overdueVaccines,
      registeredCattleLots: registeredCattleLots,
      productiveCattleLots: productiveCattleLots,
      todayLabel: todayLabel,
      monthLabel: monthLabel,
    );
  }

  // =========================================================
  // FORMATO FECHA SQLITE
  // =========================================================

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

  // =========================================================
  // NOMBRE DEL DÍA
  // =========================================================

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

    final String dayName = days[date.weekday - 1];

    return '$dayName ${date.day}';
  }

  // =========================================================
  // NOMBRE DEL MES
  // =========================================================

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
