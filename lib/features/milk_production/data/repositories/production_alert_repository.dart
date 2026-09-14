import '../../../../core/database/database_helper.dart';
import '../../../../core/session/session_manager.dart';
import '../models/production_alert.dart';

class ProductionAlertRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  final SessionManager _sessionManager = SessionManager.instance;

  int _requireUserId() {
    final int? userId = _sessionManager.currentUserId;

    if (userId == null) {
      throw StateError(
        'No hay una sesión activa.',
      );
    }

    return userId;
  }

  // ============================================================
  // ALERTAS POR PRODUCCIÓN MÍNIMA DEL DÍA ANTERIOR
  // ============================================================

  Future<List<ProductionAlert>> getPreviousDayAlerts() async {
    final int userId = _requireUserId();

    final database = await _databaseHelper.database;

    final DateTime now = DateTime.now();

    final DateTime evaluatedDate = DateTime(
      now.year,
      now.month,
      now.day - 1,
    );

    final String dateText = _formatDate(
      evaluatedDate,
    );

    final List<ProductionAlert> alerts = [];

    // ------------------------------------------------------------
    // ALERTAS POR VACA
    // ------------------------------------------------------------

    final List<Map<String, dynamic>> cowResults = await database.rawQuery(
      '''
      SELECT
        c.id AS cattle_id,
        c.code,
        c.name,
        c.lot_id,
        c.minimum_daily_production,
        l.name AS lot_name,
        COALESCE(
          SUM(m.liters),
          0
        ) AS actual_production
      FROM ${DatabaseHelper.cattleTable} c
      LEFT JOIN ${DatabaseHelper.lotsTable} l
        ON l.id = c.lot_id
      LEFT JOIN ${DatabaseHelper.milkingRecordsTable} m
        ON m.cattle_id = c.id
        AND m.date = ?
      WHERE c.user_id = ?
        AND c.status = 'Activo'
        AND c.sex = 'Hembra'
        AND c.productive_status = 'En producción'
      GROUP BY
        c.id,
        c.code,
        c.name,
        c.lot_id,
        c.minimum_daily_production,
        l.name
      HAVING actual_production <
        c.minimum_daily_production
      ORDER BY actual_production ASC
      ''',
      [
        dateText,
        userId,
      ],
    );

    for (final Map<String, dynamic> row in cowResults) {
      final int cattleId = (row['cattle_id'] as num).toInt();

      final String code = row['code']?.toString().trim() ?? '';

      final String? name = row['name']?.toString().trim();

      final String title =
          name != null && name.isNotEmpty ? name : 'Arete $code';

      final double actual =
          (row['actual_production'] as num?)?.toDouble() ?? 0.0;

      final double expected =
          (row['minimum_daily_production'] as num?)?.toDouble() ?? 4.0;

      final int? lotId = (row['lot_id'] as num?)?.toInt();

      final String? lotName = row['lot_name']?.toString().trim();

      alerts.add(
        ProductionAlert(
          type: ProductionAlertType.trend,
          entityId: cattleId,
          title: title,
          message: 'Producción baja: '
              '${actual.toStringAsFixed(1)} L de '
              '${expected.toStringAsFixed(1)} L esperados.',
          actualProduction: actual,
          expectedProduction: expected,
          date: evaluatedDate,
          lotId: lotId,
          lotName: lotName,
        ),
      );
    }

    // ------------------------------------------------------------
    // ALERTAS POR LOTE
    // ------------------------------------------------------------

    final List<Map<String, dynamic>> lotResults = await database.rawQuery(
      '''
      SELECT
        l.id AS lot_id,
        l.name AS lot_name,
        l.minimum_production_per_cow,
        COUNT(c.id) AS productive_cows,
        COALESCE(
          SUM(m.liters),
          0
        ) AS actual_production
      FROM ${DatabaseHelper.lotsTable} l
      INNER JOIN ${DatabaseHelper.cattleTable} c
        ON c.lot_id = l.id
        AND c.user_id = ?
        AND c.status = 'Activo'
        AND c.sex = 'Hembra'
        AND c.productive_status = 'En producción'
      LEFT JOIN ${DatabaseHelper.milkingRecordsTable} m
        ON m.cattle_id = c.id
        AND m.date = ?
        AND m.historical_lot_id = l.id
      WHERE l.user_id = ?
        AND l.status = 'Activo'
      GROUP BY
        l.id,
        l.name,
        l.minimum_production_per_cow
      HAVING actual_production <
        (
          COUNT(c.id) *
          l.minimum_production_per_cow
        )
      ORDER BY actual_production ASC
      ''',
      [
        userId,
        dateText,
        userId,
      ],
    );

    for (final Map<String, dynamic> row in lotResults) {
      final int lotId = (row['lot_id'] as num).toInt();

      final String lotName = row['lot_name']?.toString().trim() ?? 'Lote';

      final int productiveCows = (row['productive_cows'] as num?)?.toInt() ?? 0;

      final double minimumPerCow =
          (row['minimum_production_per_cow'] as num?)?.toDouble() ?? 4.0;

      final double actual =
          (row['actual_production'] as num?)?.toDouble() ?? 0.0;

      final double expected = productiveCows * minimumPerCow;

      alerts.add(
        ProductionAlert(
          type: ProductionAlertType.lot,
          entityId: lotId,
          title: lotName,
          message: 'El lote produjo '
              '${actual.toStringAsFixed(1)} L de '
              '${expected.toStringAsFixed(1)} L esperados.',
          actualProduction: actual,
          expectedProduction: expected,
          date: evaluatedDate,
          lotId: lotId,
          lotName: lotName,
        ),
      );
    }

    return alerts;
  }

  Future<int> countPreviousDayAlerts() async {
    final List<ProductionAlert> alerts = await getPreviousDayAlerts();

    return alerts.length;
  }

  // ============================================================
  // ALERTAS POR TENDENCIA DE PRODUCCIÓN
  // ============================================================

  Future<List<ProductionAlert>> getTrendAlerts({
    double decreasePercentage = 20.0,
  }) async {
    final int userId = _requireUserId();

    final database = await _databaseHelper.database;

    final DateTime now = DateTime.now();

    // Hoy NO se toma en cuenta.
    final DateTime recentEnd = DateTime(
      now.year,
      now.month,
      now.day - 1,
    );

    // Últimos 3 días completos.
    final DateTime recentStart = recentEnd.subtract(
      const Duration(days: 2),
    );

    // 7 días anteriores.
    final DateTime previousEnd = recentStart.subtract(
      const Duration(days: 1),
    );

    final DateTime previousStart = previousEnd.subtract(
      const Duration(days: 6),
    );

    final String recentStartText = _formatDate(recentStart);

    final String recentEndText = _formatDate(recentEnd);

    final String previousStartText = _formatDate(previousStart);

    final String previousEndText = _formatDate(previousEnd);

    final List<Map<String, dynamic>> results = await database.rawQuery(
      '''
      SELECT
        c.id AS cattle_id,
        c.code,
        c.name,
        c.lot_id,
        l.name AS lot_name,

        COUNT(
          DISTINCT CASE
            WHEN m.date BETWEEN ? AND ?
            THEN m.date
          END
        ) AS recent_days,

        COUNT(
          DISTINCT CASE
            WHEN m.date BETWEEN ? AND ?
            THEN m.date
          END
        ) AS previous_days,

        COALESCE(
          SUM(
            CASE
              WHEN m.date BETWEEN ? AND ?
              THEN m.liters
              ELSE 0
            END
          ),
          0
        ) AS recent_total,

        COALESCE(
          SUM(
            CASE
              WHEN m.date BETWEEN ? AND ?
              THEN m.liters
              ELSE 0
            END
          ),
          0
        ) AS previous_total

      FROM ${DatabaseHelper.cattleTable} c

      LEFT JOIN ${DatabaseHelper.lotsTable} l
        ON l.id = c.lot_id

      LEFT JOIN ${DatabaseHelper.milkingRecordsTable} m
        ON m.cattle_id = c.id
        AND m.user_id = ?
        AND m.date BETWEEN ? AND ?

      WHERE c.user_id = ?
        AND c.status = 'Activo'
        AND c.sex = 'Hembra'
        AND c.productive_status = 'En producción'

      GROUP BY
        c.id,
        c.code,
        c.name,
        c.lot_id,
        l.name

      HAVING recent_days = 3
        AND previous_days = 7

      ORDER BY c.name ASC, c.code ASC
      ''',
      [
        recentStartText,
        recentEndText,
        previousStartText,
        previousEndText,
        recentStartText,
        recentEndText,
        previousStartText,
        previousEndText,
        userId,
        previousStartText,
        recentEndText,
        userId,
      ],
    );

    final List<ProductionAlert> alerts = [];

    for (final Map<String, dynamic> row in results) {
      final double recentTotal =
          (row['recent_total'] as num?)?.toDouble() ?? 0.0;

      final double previousTotal =
          (row['previous_total'] as num?)?.toDouble() ?? 0.0;

      if (previousTotal <= 0) {
        continue;
      }

      final double recentAverage = recentTotal / 3;

      final double previousAverage = previousTotal / 7;

      if (previousAverage <= 0) {
        continue;
      }

      final double decrease =
          ((previousAverage - recentAverage) / previousAverage) * 100;

      if (decrease < decreasePercentage) {
        continue;
      }

      final int cattleId = (row['cattle_id'] as num).toInt();

      final String code = row['code']?.toString().trim() ?? '';

      final String? name = row['name']?.toString().trim();

      final String title =
          name != null && name.isNotEmpty ? name : 'Arete $code';

      final int? lotId = (row['lot_id'] as num?)?.toInt();

      final String? lotName = row['lot_name']?.toString().trim();

      alerts.add(
        ProductionAlert(
          type: ProductionAlertType.cow,
          entityId: cattleId,
          title: title,
          message: 'La producción disminuyó '
              '${decrease.toStringAsFixed(1)} %. '
              'Promedio anterior: '
              '${previousAverage.toStringAsFixed(1)} L/día. '
              'Promedio reciente: '
              '${recentAverage.toStringAsFixed(1)} L/día.',
          actualProduction: recentAverage,
          expectedProduction: previousAverage,
          date: recentEnd,
          lotId: lotId,
          lotName: lotName,
        ),
      );
    }

    alerts.sort(
      (
        ProductionAlert a,
        ProductionAlert b,
      ) {
        final double decreaseA = a.expectedProduction > 0
            ? ((a.expectedProduction - a.actualProduction) /
                a.expectedProduction)
            : 0;

        final double decreaseB = b.expectedProduction > 0
            ? ((b.expectedProduction - b.actualProduction) /
                b.expectedProduction)
            : 0;

        return decreaseB.compareTo(
          decreaseA,
        );
      },
    );

    return alerts;
  }

  Future<int> countTrendAlerts({
    double decreasePercentage = 20.0,
  }) async {
    final List<ProductionAlert> alerts = await getTrendAlerts(
      decreasePercentage: decreasePercentage,
    );

    return alerts.length;
  }

  // ============================================================
  // TODAS LAS ALERTAS DE PRODUCCIÓN
  // ============================================================

  Future<List<ProductionAlert>> getAllProductionAlerts() async {
    final List<ProductionAlert> minimumProductionAlerts =
        await getPreviousDayAlerts();

    final List<ProductionAlert> trendAlerts = await getTrendAlerts();

    return [
      ...minimumProductionAlerts,
      ...trendAlerts,
    ];
  }

  Future<int> countAllProductionAlerts() async {
    final List<ProductionAlert> alerts = await getAllProductionAlerts();

    return alerts.length;
  }

  // ============================================================
  // UTILIDADES
  // ============================================================

  String _formatDate(
    DateTime date,
  ) {
    final String month = date.month.toString().padLeft(
          2,
          '0',
        );

    final String day = date.day.toString().padLeft(
          2,
          '0',
        );

    return '${date.year}-$month-$day';
  }
}
