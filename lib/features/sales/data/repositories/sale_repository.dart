import 'package:sqflite/sqflite.dart';

import 'package:gantek/core/database/database_helper.dart';
import 'package:gantek/core/session/session_manager.dart';
import 'package:gantek/features/sales/data/models/sale.dart';

class SaleRepository {
  SaleRepository({
    DatabaseHelper? databaseHelper,
  }) : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;

  int _requireUserId() {
    final int? userId = SessionManager.instance.currentUserId;

    if (userId == null) {
      throw StateError(
        'No hay una sesión activa.',
      );
    }

    return userId;
  }

  Future<int> insertSale(Sale sale) async {
    final Database database = await _databaseHelper.database;

    final int userId = _requireUserId();

    if (sale.userId != userId) {
      throw StateError(
        'La venta no pertenece al usuario activo.',
      );
    }

    final Map<String, dynamic> data = sale.toMap();

    data.remove('id');

    return database.insert(
      DatabaseHelper.salesTable,
      data,
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<List<Sale>> getAllSales() async {
    final Database database = await _databaseHelper.database;

    final int userId = _requireUserId();

    final List<Map<String, dynamic>> result = await database.query(
      DatabaseHelper.salesTable,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'sale_date DESC',
    );

    return result.map(Sale.fromMap).toList();
  }

  Future<Sale?> getSaleById(int id) async {
    final Database database = await _databaseHelper.database;

    final int userId = _requireUserId();

    final List<Map<String, dynamic>> result = await database.query(
      DatabaseHelper.salesTable,
      where: 'id = ? AND user_id = ?',
      whereArgs: [
        id,
        userId,
      ],
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    return Sale.fromMap(result.first);
  }

  Future<int> updateSale(Sale sale) async {
    if (sale.id == null) {
      throw ArgumentError(
        'La venta no tiene identificador.',
      );
    }

    final Database database = await _databaseHelper.database;

    final int userId = _requireUserId();

    if (sale.userId != userId) {
      throw StateError(
        'La venta no pertenece al usuario activo.',
      );
    }

    final Map<String, dynamic> data = sale.toMap();

    data.remove('id');

    return database.update(
      DatabaseHelper.salesTable,
      data,
      where: 'id = ? AND user_id = ?',
      whereArgs: [
        sale.id,
        userId,
      ],
    );
  }

  Future<int> cancelSale(int id) async {
    final Database database = await _databaseHelper.database;

    final int userId = _requireUserId();

    return database.update(
      DatabaseHelper.salesTable,
      {
        'status': 'cancelada',
      },
      where: 'id = ? AND user_id = ?',
      whereArgs: [
        id,
        userId,
      ],
    );
  }

  Future<int> completeSale(int id) async {
    final Database database = await _databaseHelper.database;

    final int userId = _requireUserId();

    return database.update(
      DatabaseHelper.salesTable,
      {
        'status': 'completada',
      },
      where: 'id = ? AND user_id = ?',
      whereArgs: [
        id,
        userId,
      ],
    );
  }

  Future<int> deleteSale(int id) async {
    final Database database = await _databaseHelper.database;

    final int userId = _requireUserId();

    return database.delete(
      DatabaseHelper.salesTable,
      where: 'id = ? AND user_id = ?',
      whereArgs: [
        id,
        userId,
      ],
    );
  }

  Future<int> countCompletedSales() async {
    final Database database = await _databaseHelper.database;

    final int userId = _requireUserId();

    return Sqflite.firstIntValue(
          await database.rawQuery(
            '''
            SELECT COUNT(*)
            FROM ${DatabaseHelper.salesTable}
            WHERE user_id = ?
              AND status = 'completada'
            ''',
            [userId],
          ),
        ) ??
        0;
  }

  Future<double> getTotalIncome() async {
    final Database database = await _databaseHelper.database;

    final int userId = _requireUserId();

    final List<Map<String, dynamic>> result = await database.rawQuery(
      '''
      SELECT COALESCE(SUM(total), 0) AS total_income
      FROM ${DatabaseHelper.salesTable}
      WHERE user_id = ?
        AND status = 'completada'
      ''',
      [userId],
    );

    return (result.first['total_income'] as num?)?.toDouble() ?? 0;
  }

  Future<List<Sale>> getSalesByDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final Database database = await _databaseHelper.database;

    final int userId = _requireUserId();

    final DateTime normalizedStart = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    );

    final DateTime normalizedEnd = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
      23,
      59,
      59,
      999,
    );

    final List<Map<String, dynamic>> result = await database.query(
      DatabaseHelper.salesTable,
      where: '''
        user_id = ?
        AND sale_date >= ?
        AND sale_date <= ?
      ''',
      whereArgs: [
        userId,
        normalizedStart.toIso8601String(),
        normalizedEnd.toIso8601String(),
      ],
      orderBy: 'sale_date DESC',
    );

    return result.map(Sale.fromMap).toList();
  }
}
