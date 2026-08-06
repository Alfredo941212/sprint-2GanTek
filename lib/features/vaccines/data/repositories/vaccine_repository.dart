import 'package:sqflite/sqflite.dart';

import '../../../../core/database/database_helper.dart';
import '../../../../core/session/session_manager.dart';
import '../models/vaccine_record.dart';

class VaccineRepository {
  VaccineRepository({
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

  Future<int> insertVaccineRecord(
    VaccineRecord vaccine,
  ) async {
    final Database database = await _databaseHelper.database;

    final int userId = _requireUserId();

    if (vaccine.userId != userId) {
      throw StateError(
        'La vacuna no pertenece al usuario activo.',
      );
    }

    final Map<String, dynamic> data = vaccine.toMap();

    data.remove('id');

    return database.insert(
      DatabaseHelper.vaccinesTable,
      data,
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<List<VaccineRecord>> getAllVaccines() async {
    final Database database = await _databaseHelper.database;

    final int userId = _requireUserId();

    final List<Map<String, dynamic>> result = await database.query(
      DatabaseHelper.vaccinesTable,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'application_date DESC',
    );

    return result.map(VaccineRecord.fromMap).toList();
  }

  Future<VaccineRecord?> getVaccineById(
    int id,
  ) async {
    final Database database = await _databaseHelper.database;

    final int userId = _requireUserId();

    final List<Map<String, dynamic>> result = await database.query(
      DatabaseHelper.vaccinesTable,
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

    return VaccineRecord.fromMap(
      result.first,
    );
  }

  Future<List<VaccineRecord>> getVaccinesByCattle(
    int cattleId,
  ) async {
    final Database database = await _databaseHelper.database;

    final int userId = _requireUserId();

    final List<Map<String, dynamic>> result = await database.query(
      DatabaseHelper.vaccinesTable,
      where: 'cattle_id = ? AND user_id = ?',
      whereArgs: [
        cattleId,
        userId,
      ],
      orderBy: 'application_date DESC',
    );

    return result.map(VaccineRecord.fromMap).toList();
  }

  Future<List<VaccineRecord>> getUpcomingVaccines({
    int days = 30,
  }) async {
    final Database database = await _databaseHelper.database;

    final int userId = _requireUserId();

    final DateTime now = DateTime.now();

    final DateTime today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final DateTime limit = today.add(
      Duration(days: days),
    );

    final List<Map<String, dynamic>> result = await database.query(
      DatabaseHelper.vaccinesTable,
      where: '''
        user_id = ?
        AND next_dose_date IS NOT NULL
        AND next_dose_date >= ?
        AND next_dose_date <= ?
      ''',
      whereArgs: [
        userId,
        today.toIso8601String(),
        limit.toIso8601String(),
      ],
      orderBy: 'next_dose_date ASC',
    );

    return result.map(VaccineRecord.fromMap).toList();
  }

  Future<List<VaccineRecord>> getOverdueVaccines() async {
    final Database database = await _databaseHelper.database;

    final int userId = _requireUserId();

    final DateTime now = DateTime.now();

    final DateTime today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final List<Map<String, dynamic>> result = await database.query(
      DatabaseHelper.vaccinesTable,
      where: '''
        user_id = ?
        AND next_dose_date IS NOT NULL
        AND next_dose_date < ?
      ''',
      whereArgs: [
        userId,
        today.toIso8601String(),
      ],
      orderBy: 'next_dose_date ASC',
    );

    return result.map(VaccineRecord.fromMap).toList();
  }

  Future<int> updateVaccineRecord(
    VaccineRecord vaccine,
  ) async {
    if (vaccine.id == null) {
      throw ArgumentError(
        'La vacuna no tiene identificador.',
      );
    }

    final Database database = await _databaseHelper.database;

    final int userId = _requireUserId();

    if (vaccine.userId != userId) {
      throw StateError(
        'La vacuna no pertenece al usuario activo.',
      );
    }

    final Map<String, dynamic> data = vaccine.toMap();

    data.remove('id');

    return database.update(
      DatabaseHelper.vaccinesTable,
      data,
      where: 'id = ? AND user_id = ?',
      whereArgs: [
        vaccine.id,
        userId,
      ],
    );
  }

  Future<int> deleteVaccineRecord(
    int id,
  ) async {
    final Database database = await _databaseHelper.database;

    final int userId = _requireUserId();

    return database.delete(
      DatabaseHelper.vaccinesTable,
      where: 'id = ? AND user_id = ?',
      whereArgs: [
        id,
        userId,
      ],
    );
  }

  Future<int> countVaccines() async {
    final Database database = await _databaseHelper.database;

    final int userId = _requireUserId();

    final int count = Sqflite.firstIntValue(
          await database.rawQuery(
            '''
                SELECT COUNT(*)
                FROM ${DatabaseHelper.vaccinesTable}
                WHERE user_id = ?
                ''',
            [userId],
          ),
        ) ??
        0;

    return count;
  }

  Future<int> countUpcomingVaccines({
    int days = 30,
  }) async {
    final Database database = await _databaseHelper.database;

    final int userId = _requireUserId();

    final DateTime now = DateTime.now();

    final DateTime today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final DateTime limit = today.add(
      Duration(days: days),
    );

    final int count = Sqflite.firstIntValue(
          await database.rawQuery(
            '''
                SELECT COUNT(*)
                FROM ${DatabaseHelper.vaccinesTable}
                WHERE user_id = ?
                  AND next_dose_date IS NOT NULL
                  AND next_dose_date >= ?
                  AND next_dose_date <= ?
                ''',
            [
              userId,
              today.toIso8601String(),
              limit.toIso8601String(),
            ],
          ),
        ) ??
        0;

    return count;
  }

  Future<int> countOverdueVaccines() async {
    final Database database = await _databaseHelper.database;

    final int userId = _requireUserId();

    final DateTime now = DateTime.now();

    final DateTime today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final int count = Sqflite.firstIntValue(
          await database.rawQuery(
            '''
                SELECT COUNT(*)
                FROM ${DatabaseHelper.vaccinesTable}
                WHERE user_id = ?
                  AND next_dose_date IS NOT NULL
                  AND next_dose_date < ?
                ''',
            [
              userId,
              today.toIso8601String(),
            ],
          ),
        ) ??
        0;

    return count;
  }
}
