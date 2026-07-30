import 'package:sqflite/sqflite.dart';

import '../../../../core/database/database_helper.dart';
import '../models/vaccine_record.dart';

class VaccineRepository {
  final DatabaseHelper _databaseHelper;

  VaccineRepository({
    DatabaseHelper? databaseHelper,
  }) : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  Future<int> insertVaccineRecord(
    VaccineRecord vaccine,
  ) async {
    final Database database = await _databaseHelper.database;

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

    final List<Map<String, dynamic>> result = await database.query(
      DatabaseHelper.vaccinesTable,
      orderBy: 'application_date DESC',
    );

    return result.map(VaccineRecord.fromMap).toList();
  }

  Future<List<VaccineRecord>> getVaccinesByCattle(
    int cattleId,
  ) async {
    final Database database = await _databaseHelper.database;

    final List<Map<String, dynamic>> result = await database.query(
      DatabaseHelper.vaccinesTable,
      where: 'cattle_id = ?',
      whereArgs: [cattleId],
      orderBy: 'application_date DESC',
    );

    return result.map(VaccineRecord.fromMap).toList();
  }

  Future<List<VaccineRecord>> getUpcomingVaccines() async {
    final Database database = await _databaseHelper.database;

    final DateTime today = DateTime.now();

    final DateTime limit = today.add(
      const Duration(days: 30),
    );

    final List<Map<String, dynamic>> result = await database.query(
      DatabaseHelper.vaccinesTable,
      where: '''
        next_dose_date IS NOT NULL
        AND next_dose_date >= ?
        AND next_dose_date <= ?
      ''',
      whereArgs: [
        today.toIso8601String(),
        limit.toIso8601String(),
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
        'El registro no tiene identificador.',
      );
    }

    final Database database = await _databaseHelper.database;

    final Map<String, dynamic> data = vaccine.toMap();
    data.remove('id');

    return database.update(
      DatabaseHelper.vaccinesTable,
      data,
      where: 'id = ?',
      whereArgs: [vaccine.id],
    );
  }

  Future<int> deleteVaccineRecord(int id) async {
    final Database database = await _databaseHelper.database;

    return database.delete(
      DatabaseHelper.vaccinesTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
