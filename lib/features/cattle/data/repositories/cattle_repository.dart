import 'package:sqflite/sqflite.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/database/database_helper.dart';
import '../models/cattle.dart';

class CattleRepository {
  final DatabaseHelper _databaseHelper;

  CattleRepository({
    DatabaseHelper? databaseHelper,
  }) : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  Future<int> insertCattle(Cattle cattle) async {
    final Database database = await _databaseHelper.database;

    final Map<String, dynamic> data = cattle.toMap();

    data.remove('id');
    data['created_at'] = DateTime.now().toIso8601String();

    return database.insert(
      DatabaseHelper.cattleTable,
      data,
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<List<Cattle>> getAllCattle() async {
    final Database database = await _databaseHelper.database;

    final int? userId = SessionManager.instance.currentUserId;

    if (userId == null) {
      return <Cattle>[];
    }

    final List<Map<String, dynamic>> result = await database.query(
      DatabaseHelper.cattleTable,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );

    return result.map(Cattle.fromMap).toList();
  }

  Future<List<Cattle>> getAvailableCattle() async {
    final Database database = await _databaseHelper.database;

    final int? userId = SessionManager.instance.currentUserId;

    if (userId == null) {
      return <Cattle>[];
    }

    final List<Map<String, dynamic>> result = await database.rawQuery(
      '''
      SELECT *
      FROM ${DatabaseHelper.cattleTable}
      WHERE user_id== ? AND id NOT IN (
        SELECT cattle_id
        FROM ${DatabaseHelper.salesTable}
        WHERE status = 'completada'
      )
      ORDER BY created_at DESC
    ''',
      [userId],
    );

    return result.map(Cattle.fromMap).toList();
  }

  Future<Cattle?> getCattleById(int id) async {
    final Database database = await _databaseHelper.database;

    final List<Map<String, dynamic>> result = await database.query(
      DatabaseHelper.cattleTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    return Cattle.fromMap(result.first);
  }

  Future<int> updateCattle(Cattle cattle) async {
    if (cattle.id == null) {
      throw ArgumentError(
        'No se puede actualizar un animal sin identificador.',
      );
    }

    final Database database = await _databaseHelper.database;

    final Map<String, dynamic> data = cattle.toMap();
    data.remove('id');

    return database.update(
      DatabaseHelper.cattleTable,
      data,
      where: 'id = ?',
      whereArgs: [cattle.id],
    );
  }

  Future<int> deleteCattle(int id) async {
    final Database database = await _databaseHelper.database;

    return database.delete(
      DatabaseHelper.cattleTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<bool> codeExists(String code) async {
    final Database database = await _databaseHelper.database;

    final int? userId = SessionManager.instance.currentUserId;

    if (userId == null) {
      return false;
    }

    final List<Map<String, dynamic>> result = await database.query(
      DatabaseHelper.cattleTable,
      columns: ['id'],
      where: 'code = ? ? AND code = ?',
      whereArgs: [
        userId,
        code.trim(),
      ],
      limit: 1,
    );

    return result.isNotEmpty;
  }
}
