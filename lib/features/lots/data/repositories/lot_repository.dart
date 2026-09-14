import '../../../../core/database/database_helper.dart';
import '../../../../core/session/session_manager.dart';
import '../models/lot.dart';

class LotRepository {
  LotRepository({
    DatabaseHelper? databaseHelper,
  }) : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;

  // =========================================================
  // OBTENER USUARIO ACTUAL
  // =========================================================

  int _requireUserId() {
    final int? userId = SessionManager.instance.currentUserId;

    if (userId == null) {
      throw Exception(
        'No hay una sesión activa.',
      );
    }

    return userId;
  }

  // =========================================================
  // REGISTRAR LOTE
  // =========================================================

  Future<int> insertLot(Lot lot) async {
    final database = await _databaseHelper.database;

    final int userId = _requireUserId();

    final bool exists = await nameExists(lot.name);

    if (exists) {
      throw Exception(
        'Ya existe un lote con ese nombre.',
      );
    }

    final Lot newLot = lot.copyWith(
      userId: userId,
      createdAt: DateTime.now().toIso8601String(),
    );

    return database.insert(
      DatabaseHelper.lotsTable,
      newLot.toMap(),
    );
  }

  // =========================================================
  // OBTENER TODOS LOS LOTES
  // =========================================================

  Future<List<Lot>> getAllLots() async {
    final database = await _databaseHelper.database;

    final int userId = _requireUserId();

    final List<Map<String, dynamic>> maps = await database.query(
      DatabaseHelper.lotsTable,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'name ASC',
    );

    return maps
        .map(
          (map) => Lot.fromMap(map),
        )
        .toList();
  }

  // =========================================================
  // OBTENER LOTES ACTIVOS
  // =========================================================

  Future<List<Lot>> getActiveLots() async {
    final database = await _databaseHelper.database;

    final int userId = _requireUserId();

    final List<Map<String, dynamic>> maps = await database.query(
      DatabaseHelper.lotsTable,
      where: '''
        user_id = ?
        AND status = ?
      ''',
      whereArgs: [
        userId,
        'Activo',
      ],
      orderBy: 'name ASC',
    );

    return maps
        .map(
          (map) => Lot.fromMap(map),
        )
        .toList();
  }

  // =========================================================
  // OBTENER LOTE POR ID
  // =========================================================

  Future<Lot?> getLotById(
    int lotId,
  ) async {
    final database = await _databaseHelper.database;

    final int userId = _requireUserId();

    final List<Map<String, dynamic>> maps = await database.query(
      DatabaseHelper.lotsTable,
      where: '''
        id = ?
        AND user_id = ?
      ''',
      whereArgs: [
        lotId,
        userId,
      ],
      limit: 1,
    );

    if (maps.isEmpty) {
      return null;
    }

    return Lot.fromMap(
      maps.first,
    );
  }

  // =========================================================
  // VALIDAR NOMBRE REPETIDO
  // =========================================================

  Future<bool> nameExists(
    String name, {
    int? excludeLotId,
  }) async {
    final database = await _databaseHelper.database;

    final int userId = _requireUserId();

    String where = '''
      user_id = ?
      AND LOWER(name) = LOWER(?)
    ''';

    final List<Object?> whereArgs = [
      userId,
      name.trim(),
    ];

    if (excludeLotId != null) {
      where += ' AND id != ?';
      whereArgs.add(excludeLotId);
    }

    final List<Map<String, dynamic>> result = await database.query(
      DatabaseHelper.lotsTable,
      columns: ['id'],
      where: where,
      whereArgs: whereArgs,
      limit: 1,
    );

    return result.isNotEmpty;
  }

  // =========================================================
  // ACTUALIZAR LOTE
  // =========================================================

  Future<int> updateLot(
    Lot lot,
  ) async {
    if (lot.id == null) {
      throw Exception(
        'El lote no tiene un ID válido.',
      );
    }

    final database = await _databaseHelper.database;

    final int userId = _requireUserId();

    final bool exists = await nameExists(
      lot.name,
      excludeLotId: lot.id,
    );

    if (exists) {
      throw Exception(
        'Ya existe otro lote con ese nombre.',
      );
    }

    final Map<String, dynamic> data = lot
        .copyWith(
          userId: userId,
        )
        .toMap();

    data.remove('id');

    return database.update(
      DatabaseHelper.lotsTable,
      data,
      where: '''
        id = ?
        AND user_id = ?
      ''',
      whereArgs: [
        lot.id,
        userId,
      ],
    );
  }

  // =========================================================
  // CONTAR GANADO DEL LOTE
  // =========================================================

  Future<int> countCattleInLot(
    int lotId,
  ) async {
    final database = await _databaseHelper.database;

    final int userId = _requireUserId();

    final List<Map<String, dynamic>> result = await database.rawQuery(
      '''
      SELECT COUNT(*) AS total
      FROM ${DatabaseHelper.cattleTable}
      WHERE user_id = ?
        AND lot_id = ?
        AND status = 'Activo'
      ''',
      [
        userId,
        lotId,
      ],
    );

    if (result.isEmpty) {
      return 0;
    }

    return (result.first['total'] as num?)?.toInt() ?? 0;
  }

  // =========================================================
  // CONTAR VACAS EN PRODUCCIÓN DEL LOTE
  // =========================================================

  Future<int> countProductiveCattleInLot(
    int lotId,
  ) async {
    final database = await _databaseHelper.database;

    final int userId = _requireUserId();

    final List<Map<String, dynamic>> result = await database.rawQuery(
      '''
      SELECT COUNT(*) AS total
      FROM ${DatabaseHelper.cattleTable}
      WHERE user_id = ?
        AND lot_id = ?
        AND status = 'Activo'
        AND sex = 'Hembra'
        AND productive_status = 'En producción'
      ''',
      [
        userId,
        lotId,
      ],
    );

    if (result.isEmpty) {
      return 0;
    }

    return (result.first['total'] as num?)?.toInt() ?? 0;
  }

  // =========================================================
  // ELIMINAR LOTE
  // =========================================================

  Future<int> deleteLot(
    int lotId,
  ) async {
    final database = await _databaseHelper.database;

    final int userId = _requireUserId();

    final int cattleCount = await countCattleInLot(lotId);

    if (cattleCount > 0) {
      throw Exception(
        'No se puede eliminar el lote porque tiene ganado asignado.',
      );
    }

    return database.delete(
      DatabaseHelper.lotsTable,
      where: '''
        id = ?
        AND user_id = ?
      ''',
      whereArgs: [
        lotId,
        userId,
      ],
    );
  }
}
