import 'package:sqflite/sqflite.dart';

import '../../../../core/database/database_helper.dart';
import '../../../../core/session/session_manager.dart';
import '../models/sale.dart';

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

  Future<int> updateSale(Sale sale) async {
    if (sale.id == null) {
      throw ArgumentError(
        'La venta no tiene identificador.',
      );
    }

    final Database database = await _databaseHelper.database;

    final int userId = _requireUserId();

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
}
