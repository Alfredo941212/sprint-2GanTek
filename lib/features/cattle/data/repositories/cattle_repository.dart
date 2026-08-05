import 'package:sqflite/sqflite.dart';

import '../../../../core/database/database_helper.dart';
import '../../../../core/session/session_manager.dart';
import '../models/cattle.dart';

class CattleRepository {
  final DatabaseHelper _databaseHelper;

  CattleRepository({
    DatabaseHelper? databaseHelper,
  }) : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  Future<int> insertCattle(
    Cattle cattle,
  ) async {
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

  Future<Cattle?> getCattleById(
    int id,
  ) async {
    final Database database = await _databaseHelper.database;

    final int? userId = SessionManager.instance.currentUserId;

    if (userId == null) {
      return null;
    }

    final List<Map<String, dynamic>> result = await database.query(
      DatabaseHelper.cattleTable,
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

    return Cattle.fromMap(
      result.first,
    );
  }

  Future<bool> codeExists(
    String code,
  ) async {
    final Database database = await _databaseHelper.database;

    final int? userId = SessionManager.instance.currentUserId;

    if (userId == null) {
      throw StateError(
        'No hay una sesión de usuario activa.',
      );
    }

    final List<Map<String, dynamic>> result = await database.query(
      DatabaseHelper.cattleTable,
      columns: ['id'],
      where: 'user_id = ? AND code = ?',
      whereArgs: [
        userId,
        code.trim(),
      ],
      limit: 1,
    );

    return result.isNotEmpty;
  }

  Future<int> updateCattle(
    Cattle cattle,
  ) async {
    if (cattle.id == null) {
      throw ArgumentError(
        'No se puede actualizar un animal sin identificador.',
      );
    }

    final int? userId = SessionManager.instance.currentUserId;

    if (userId == null) {
      throw StateError(
        'No hay una sesión de usuario activa.',
      );
    }

    final Database database = await _databaseHelper.database;

    final Map<String, dynamic> data = cattle.toMap();

    data.remove('id');

    return database.update(
      DatabaseHelper.cattleTable,
      data,
      where: 'id = ? AND user_id = ?',
      whereArgs: [
        cattle.id,
        userId,
      ],
    );
  }

  Future<int> deleteCattle(int id) async {
    final int userId = _requireUserId();

    final Database database = await _databaseHelper.database;

    return database.delete(
      DatabaseHelper.cattleTable,
      where: 'id = ? AND user_id = ?',
      whereArgs: [
        id,
        userId,
      ],
    );
  }

  int _requireUserId() {
    final int? userId = SessionManager.instance.currentUserId;

    if (userId == null) {
      throw StateError(
        'No hay una sesión activa.',
      );
    }

    return userId;
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
      WHERE user_id = ?
        AND id NOT IN (
          SELECT cattle_id
          FROM ${DatabaseHelper.salesTable}
          WHERE user_id = ?
            AND status = 'completada'
        )
      ORDER BY created_at DESC
      ''',
      [
        userId,
        userId,
      ],
    );

    return result.map(Cattle.fromMap).toList();
  }
}
