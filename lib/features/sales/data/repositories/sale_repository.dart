import 'package:sqflite/sqflite.dart';

import '../../../../core/database/database_helper.dart';
import '../models/sale.dart';

class SaleRepository {
  final DatabaseHelper _databaseHelper;

  SaleRepository({
    DatabaseHelper? databaseHelper,
  }) : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  Future<int> insertSale(Sale sale) async {
    final Database database = await _databaseHelper.database;

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

    final List<Map<String, dynamic>> result = await database.query(
      DatabaseHelper.salesTable,
      orderBy: 'sale_date DESC',
    );

    return result.map(Sale.fromMap).toList();
  }

  Future<Sale?> getSaleById(int id) async {
    final Database database = await _databaseHelper.database;

    final List<Map<String, dynamic>> result = await database.query(
      DatabaseHelper.salesTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    return Sale.fromMap(result.first);
  }

  Future<int> cancelSale(int id) async {
    final Database database = await _databaseHelper.database;

    return database.update(
      DatabaseHelper.salesTable,
      {
        'status': 'cancelada',
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteSale(int id) async {
    final Database database = await _databaseHelper.database;

    return database.delete(
      DatabaseHelper.salesTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
