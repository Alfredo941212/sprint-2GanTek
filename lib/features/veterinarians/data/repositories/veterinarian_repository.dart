import '../../../../core/database/database_helper.dart';
import '../models/veterinarian.dart';

class VeterinarianRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  // =========================================================
  // REGISTRAR
  // =========================================================

  Future<int> insertVeterinarian(
    Veterinarian veterinarian,
  ) async {
    final database = await _databaseHelper.database;

    final String name = veterinarian.name.trim();

    if (name.isEmpty) {
      throw Exception(
        'El nombre del veterinario es obligatorio.',
      );
    }

    final String? license = _cleanNullable(
      veterinarian.professionalLicense,
    );

    if (license != null) {
      final bool exists = await professionalLicenseExists(
        license,
      );

      if (exists) {
        throw Exception(
          'Ya existe un veterinario con esa cédula profesional.',
        );
      }
    }

    final Veterinarian newVeterinarian = veterinarian.copyWith(
      name: name,
      professionalLicense: license,
      phone: _cleanNullable(
        veterinarian.phone,
      ),
      email: _cleanNullable(
        veterinarian.email,
      ),
      specialty: _cleanNullable(
        veterinarian.specialty,
      ),
      observations: _cleanNullable(
        veterinarian.observations,
      ),
      createdAt: DateTime.now().toIso8601String(),
    );

    return database.insert(
      DatabaseHelper.veterinariansTable,
      newVeterinarian.toMap(),
    );
  }

  // =========================================================
  // OBTENER TODOS
  // =========================================================

  Future<List<Veterinarian>> getAllVeterinarians() async {
    final database = await _databaseHelper.database;

    final List<Map<String, dynamic>> result = await database.query(
      DatabaseHelper.veterinariansTable,
      orderBy: 'name COLLATE NOCASE ASC',
    );

    return result
        .map(
          (Map<String, dynamic> row) => Veterinarian.fromMap(row),
        )
        .toList();
  }

  // =========================================================
  // OBTENER ACTIVOS
  // =========================================================

  Future<List<Veterinarian>> getActiveVeterinarians() async {
    final database = await _databaseHelper.database;

    final List<Map<String, dynamic>> result = await database.query(
      DatabaseHelper.veterinariansTable,
      where: 'status = ?',
      whereArgs: [
        'Activo',
      ],
      orderBy: 'name COLLATE NOCASE ASC',
    );

    return result
        .map(
          (Map<String, dynamic> row) => Veterinarian.fromMap(row),
        )
        .toList();
  }

  // =========================================================
  // OBTENER POR ID
  // =========================================================

  Future<Veterinarian?> getVeterinarianById(
    int id,
  ) async {
    final database = await _databaseHelper.database;

    final List<Map<String, dynamic>> result = await database.query(
      DatabaseHelper.veterinariansTable,
      where: 'id = ?',
      whereArgs: [
        id,
      ],
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    return Veterinarian.fromMap(
      result.first,
    );
  }

  // =========================================================
  // VALIDAR CÉDULA
  // =========================================================

  Future<bool> professionalLicenseExists(
    String professionalLicense, {
    int? excludeVeterinarianId,
  }) async {
    final database = await _databaseHelper.database;

    final String license = professionalLicense.trim();

    if (license.isEmpty) {
      return false;
    }

    String where = 'professional_license = ?';

    final List<Object?> whereArgs = [
      license,
    ];

    if (excludeVeterinarianId != null) {
      where += ' AND id != ?';

      whereArgs.add(
        excludeVeterinarianId,
      );
    }

    final List<Map<String, dynamic>> result = await database.query(
      DatabaseHelper.veterinariansTable,
      columns: [
        'id',
      ],
      where: where,
      whereArgs: whereArgs,
      limit: 1,
    );

    return result.isNotEmpty;
  }

  // =========================================================
  // ACTUALIZAR
  // =========================================================

  Future<int> updateVeterinarian(
    Veterinarian veterinarian,
  ) async {
    final int? veterinarianId = veterinarian.id;

    if (veterinarianId == null) {
      throw Exception(
        'No se puede actualizar un veterinario sin ID.',
      );
    }

    final String name = veterinarian.name.trim();

    if (name.isEmpty) {
      throw Exception(
        'El nombre del veterinario es obligatorio.',
      );
    }

    final String? license = _cleanNullable(
      veterinarian.professionalLicense,
    );

    if (license != null) {
      final bool exists = await professionalLicenseExists(
        license,
        excludeVeterinarianId: veterinarianId,
      );

      if (exists) {
        throw Exception(
          'Ya existe otro veterinario con esa cédula profesional.',
        );
      }
    }

    final database = await _databaseHelper.database;

    final Veterinarian updated = veterinarian.copyWith(
      name: name,
      professionalLicense: license,
      phone: _cleanNullable(
        veterinarian.phone,
      ),
      email: _cleanNullable(
        veterinarian.email,
      ),
      specialty: _cleanNullable(
        veterinarian.specialty,
      ),
      observations: _cleanNullable(
        veterinarian.observations,
      ),
    );

    final Map<String, dynamic> data = updated.toMap();

    data.remove('id');

    return database.update(
      DatabaseHelper.veterinariansTable,
      data,
      where: 'id = ?',
      whereArgs: [
        veterinarianId,
      ],
    );
  }

  // =========================================================
  // ELIMINAR
  // =========================================================

  Future<int> deleteVeterinarian(
    int veterinarianId,
  ) async {
    final database = await _databaseHelper.database;

    final List<Map<String, dynamic>> vaccinations = await database.query(
      DatabaseHelper.vaccinationsTable,
      columns: [
        'id',
      ],
      where: 'veterinarian_id = ?',
      whereArgs: [
        veterinarianId,
      ],
      limit: 1,
    );

    if (vaccinations.isNotEmpty) {
      throw Exception(
        'No se puede eliminar el veterinario porque tiene vacunaciones registradas.',
      );
    }

    return database.delete(
      DatabaseHelper.veterinariansTable,
      where: 'id = ?',
      whereArgs: [
        veterinarianId,
      ],
    );
  }

  // =========================================================
  // AUXILIAR
  // =========================================================

  String? _cleanNullable(
    String? value,
  ) {
    if (value == null) {
      return null;
    }

    final String cleaned = value.trim();

    if (cleaned.isEmpty) {
      return null;
    }

    return cleaned;
  }
}
