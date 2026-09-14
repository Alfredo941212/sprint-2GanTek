import 'package:sqflite/sqflite.dart';

import '../../../../core/database/database_helper.dart';
import '../../../../core/session/session_manager.dart';
import '../models/cattle.dart';

class CattleRepository {
  final DatabaseHelper _databaseHelper;

  CattleRepository({
    DatabaseHelper? databaseHelper,
  }) : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  // =========================================================
  // OBTENER USUARIO ACTUAL
  // =========================================================

  int _requireUserId() {
    final int? userId = SessionManager.instance.currentUserId;

    if (userId == null) {
      throw StateError(
        'No hay una sesión de usuario activa.',
      );
    }

    return userId;
  }

  // =========================================================
  // REGISTRAR GANADO
  // =========================================================

  Future<int> insertCattle(
    Cattle cattle,
  ) async {
    final int userId = _requireUserId();

    final Database database = await _databaseHelper.database;

    final Map<String, dynamic> data = cattle.toMap();

    data.remove('id');

    // Nunca confiamos en un userId recibido desde la UI.
    data['user_id'] = userId;

    data['created_at'] = DateTime.now().toIso8601String();

    return database.insert(
      DatabaseHelper.cattleTable,
      data,
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  // =========================================================
  // OBTENER TODO EL GANADO DEL USUARIO
  // =========================================================

  Future<List<Cattle>> getAllCattle() async {
    final int? userId = SessionManager.instance.currentUserId;

    if (userId == null) {
      return <Cattle>[];
    }

    final Database database = await _databaseHelper.database;

    final List<Map<String, dynamic>> result = await database.query(
      DatabaseHelper.cattleTable,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );

    return result.map(Cattle.fromMap).toList();
  }

  // =========================================================
  // OBTENER GANADO POR ID
  // =========================================================

  Future<Cattle?> getCattleById(
    int id,
  ) async {
    final int? userId = SessionManager.instance.currentUserId;

    if (userId == null) {
      return null;
    }

    final Database database = await _databaseHelper.database;

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

  // =========================================================
  // VERIFICAR SI EL CÓDIGO / ARETE YA EXISTE
  // =========================================================

  Future<bool> codeExists(
    String code, {
    int? excludeCattleId,
  }) async {
    final int userId = _requireUserId();

    final Database database = await _databaseHelper.database;

    String where = 'user_id = ? AND code = ?';

    final List<Object?> whereArgs = [
      userId,
      code.trim(),
    ];

    // Cuando editamos una vaca, ignoramos su propio ID.
    if (excludeCattleId != null) {
      where += ' AND id != ?';

      whereArgs.add(
        excludeCattleId,
      );
    }

    final List<Map<String, dynamic>> result = await database.query(
      DatabaseHelper.cattleTable,
      columns: ['id'],
      where: where,
      whereArgs: whereArgs,
      limit: 1,
    );

    return result.isNotEmpty;
  }

  // =========================================================
  // ACTUALIZAR GANADO
  // =========================================================

  Future<int> updateCattle(
    Cattle cattle,
  ) async {
    if (cattle.id == null) {
      throw ArgumentError(
        'No se puede actualizar un animal sin identificador.',
      );
    }

    final int userId = _requireUserId();

    final Database database = await _databaseHelper.database;

    final Map<String, dynamic> data = cattle.toMap();

    data.remove('id');

    // Conservamos siempre el propietario real de la sesión.
    data['user_id'] = userId;

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

  // =========================================================
  // ELIMINAR GANADO
  // =========================================================

  Future<int> deleteCattle(
    int id,
  ) async {
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

  // =========================================================
  // OBTENER GANADO ACTIVO
  // =========================================================

  Future<List<Cattle>> getActiveCattle() async {
    final int? userId = SessionManager.instance.currentUserId;

    if (userId == null) {
      return <Cattle>[];
    }

    final Database database = await _databaseHelper.database;

    final List<Map<String, dynamic>> result = await database.query(
      DatabaseHelper.cattleTable,
      where: '''
        user_id = ?
        AND status = ?
      ''',
      whereArgs: [
        userId,
        'Activo',
      ],
      orderBy: 'created_at DESC',
    );

    return result.map(Cattle.fromMap).toList();
  }

  // =========================================================
  // OBTENER VACAS EN PRODUCCIÓN
  // =========================================================

  Future<List<Cattle>> getProductiveCattle() async {
    final int? userId = SessionManager.instance.currentUserId;

    if (userId == null) {
      return <Cattle>[];
    }

    final Database database = await _databaseHelper.database;

    final List<Map<String, dynamic>> result = await database.query(
      DatabaseHelper.cattleTable,
      where: '''
        user_id = ?
        AND status = ?
        AND productive_status = ?
        AND sex = ?
      ''',
      whereArgs: [
        userId,
        'Activo',
        'En producción',
        'Hembra',
      ],
      orderBy: 'code ASC',
    );

    return result.map(Cattle.fromMap).toList();
  }

  // =========================================================
  // OBTENER GANADO POR LOTE
  // =========================================================

  Future<List<Cattle>> getCattleByLot(
    int lotId,
  ) async {
    final int userId = _requireUserId();

    final Database database = await _databaseHelper.database;

    final List<Map<String, dynamic>> result = await database.query(
      DatabaseHelper.cattleTable,
      where: '''
        user_id = ?
        AND lot_id = ?
      ''',
      whereArgs: [
        userId,
        lotId,
      ],
      orderBy: 'code ASC',
    );

    return result.map(Cattle.fromMap).toList();
  }

  // =========================================================
  // CONTAR GANADO
  // =========================================================

  Future<int> countCattle() async {
    final int userId = _requireUserId();

    final Database database = await _databaseHelper.database;

    final List<Map<String, dynamic>> result = await database.rawQuery(
      '''
      SELECT COUNT(*) AS total
      FROM ${DatabaseHelper.cattleTable}
      WHERE user_id = ?
        AND status = 'Activo'
      ''',
      [userId],
    );

    if (result.isEmpty) {
      return 0;
    }

    return (result.first['total'] as num?)?.toInt() ?? 0;
  }

  // =========================================================
  // CONTAR VACAS EN PRODUCCIÓN
  // =========================================================

  Future<int> countProductiveCattle() async {
    final int userId = _requireUserId();

    final Database database = await _databaseHelper.database;

    final List<Map<String, dynamic>> result = await database.rawQuery(
      '''
      SELECT COUNT(*) AS total
      FROM ${DatabaseHelper.cattleTable}
      WHERE user_id = ?
        AND status = 'Activo'
        AND productive_status = 'En producción'
        AND sex = 'Hembra'
      ''',
      [userId],
    );

    if (result.isEmpty) {
      return 0;
    }

    return (result.first['total'] as num?)?.toInt() ?? 0;
  }
}
