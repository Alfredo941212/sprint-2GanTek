import 'dart:convert';
import 'package:sqflite/sqflite.dart';

import '../../../../core/database/database_helper.dart';
import '../../../../core/network/api_client.dart';
import '../models/veterinarian.dart';

class VeterinarianRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  Future<void> _saveApiVeterinariansLocally(
    List<Map<String, dynamic>> apiVeterinarians,
  ) async {
    final Database db = await _databaseHelper.database;

    for (final Map<String, dynamic> apiVeterinarian in apiVeterinarians) {
      final Veterinarian serverVeterinarian =
          Veterinarian.fromApi(apiVeterinarian);

      final int? serverId = serverVeterinarian.serverId;

      if (serverId == null) {
        continue;
      }

      final List<Map<String, dynamic>> existing = await db.query(
        DatabaseHelper.veterinariansTable,
        columns: ['id'],
        where: 'server_id = ?',
        whereArgs: [serverId],
        limit: 1,
      );

      final int? localId =
          existing.isEmpty ? null : (existing.first['id'] as num?)?.toInt();

      final Veterinarian veterinarian = serverVeterinarian.copyWith(
        id: localId,
      );

      final Map<String, dynamic> data = veterinarian.toMap();
      data.remove('id');
      // SQLite no permite NULL en observations.
      data['observations'] ??= '';
      // SQLite exige created_at.
      data['created_at'] ??= DateTime.now().toIso8601String();

      if (localId == null) {
        await db.insert(
          DatabaseHelper.veterinariansTable,
          data,
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      } else {
        await db.update(
          DatabaseHelper.veterinariansTable,
          data,
          where: 'id = ?',
          whereArgs: [localId],
        );
      }
    }
  }

  Future<int?> _getVeterinarianServerId(
    int localVeterinarianId,
  ) async {
    final Database db = await _databaseHelper.database;

    final List<Map<String, dynamic>> rows = await db.query(
      DatabaseHelper.veterinariansTable,
      columns: ['server_id'],
      where: 'id = ?',
      whereArgs: [localVeterinarianId],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return (rows.first['server_id'] as num?)?.toInt();
  }

  // =========================================================
  // REGISTRAR
  // =========================================================

  Future<int> insertVeterinarian(
    Veterinarian veterinarian,
  ) async {
    final String name = veterinarian.name.trim();
    final String license = veterinarian.professionalLicense?.trim() ?? '';

    if (name.isEmpty) {
      throw Exception(
        'El nombre del veterinario es obligatorio.',
      );
    }

    if (license.isEmpty) {
      throw Exception(
        'La cédula profesional es obligatoria.',
      );
    }

    final response = await ApiClient.instance.post(
      '/veterinarios',
      body: veterinarian.toApi(),
    );

    if (response.statusCode == 401) {
      throw Exception(
        'Tu sesión ha expirado. Inicia sesión nuevamente.',
      );
    }

    if (response.statusCode == 403) {
      throw Exception(
        'No tienes permiso para registrar veterinarios.',
      );
    }

    if (response.statusCode == 422) {
      throw Exception(
        _extractMessage(
          response.body,
          'Los datos del veterinario no son válidos.',
        ),
      );
    }

    if (response.statusCode != 201) {
      throw Exception(
        'No se pudo registrar el veterinario. '
        'Código ${response.statusCode}.',
      );
    }

    final dynamic decoded = jsonDecode(
      response.body,
    );

    if (decoded is! Map<String, dynamic>) {
      throw Exception(
        'La respuesta del servidor no es válida.',
      );
    }

    final dynamic data = decoded['data'];

    if (data is! Map<String, dynamic>) {
      throw Exception(
        'No se recibió el veterinario registrado.',
      );
    }

    final Veterinarian created = Veterinarian.fromApi(data);

    if (created.serverId == null) {
      throw Exception(
        'El servidor no devolvió el ID del veterinario.',
      );
    }

    await _saveApiVeterinariansLocally([
      data,
    ]);

    final Database db = await _databaseHelper.database;

    final List<Map<String, dynamic>> localRows = await db.query(
      DatabaseHelper.veterinariansTable,
      columns: ['id'],
      where: 'server_id = ?',
      whereArgs: [created.serverId],
      limit: 1,
    );

    if (localRows.isEmpty) {
      throw Exception(
        'No se pudo guardar localmente el veterinario.',
      );
    }

    return (localRows.first['id'] as num).toInt();
  }

  // =========================================================
  // OBTENER TODOS
  // =========================================================

  Future<List<Veterinarian>> getAllVeterinarians() async {
    final Database db = await _databaseHelper.database;

    try {
      final response = await ApiClient.instance.get(
        '/veterinarios',
      );

      if (response.statusCode == 401) {
        throw Exception(
          'Tu sesión ha expirado. Inicia sesión nuevamente.',
        );
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          'No se pudieron obtener los veterinarios. '
          'Código ${response.statusCode}.',
        );
      }

      final dynamic decoded = jsonDecode(
        response.body,
      );

      if (decoded is! Map<String, dynamic>) {
        throw Exception(
          'La respuesta de veterinarios no es válida.',
        );
      }

      final dynamic data = decoded['data'];

      if (data is! List) {
        throw Exception(
          'La lista de veterinarios no es válida.',
        );
      }

      final List<Map<String, dynamic>> apiVeterinarians =
          data.whereType<Map<String, dynamic>>().toList();

      await _saveApiVeterinariansLocally(
        apiVeterinarians,
      );
    } catch (_) {
      // Si Laravel no está disponible, usamos la copia local.
    }

    final List<Map<String, dynamic>> rows = await db.query(
      DatabaseHelper.veterinariansTable,
      orderBy: 'name COLLATE NOCASE ASC',
    );

    return rows
        .map(
          (Map<String, dynamic> row) => Veterinarian.fromMap(row),
        )
        .toList();
  }

  // =========================================================
  // OBTENER ACTIVOS
  // =========================================================

  Future<List<Veterinarian>> getActiveVeterinarians() async {
    final List<Veterinarian> veterinarians = await getAllVeterinarians();

    return veterinarians
        .where(
          (Veterinarian veterinarian) => veterinarian.status == 'Activo',
        )
        .toList();
  }

  // =========================================================
  // OBTENER POR ID
  // =========================================================

  Future<Veterinarian?> getVeterinarianById(
    int id,
  ) async {
    final response = await ApiClient.instance.get(
      '/veterinarios/$id',
    );

    if (response.statusCode == 401) {
      throw Exception(
        'Tu sesión ha expirado. Inicia sesión nuevamente.',
      );
    }

    if (response.statusCode == 404) {
      return null;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'No se pudo obtener el veterinario. '
        'Código ${response.statusCode}.',
      );
    }

    final dynamic decoded = jsonDecode(
      response.body,
    );

    if (decoded is! Map<String, dynamic>) {
      throw Exception(
        'La respuesta del veterinario no es válida.',
      );
    }

    final dynamic data = decoded['data'];

    if (data is! Map<String, dynamic>) {
      return null;
    }

    return Veterinarian.fromApi(data);
  }

  // =========================================================
  // VALIDAR CÉDULA
  // =========================================================

  Future<bool> professionalLicenseExists(
    String professionalLicense, {
    int? excludeVeterinarianId,
  }) async {
    final String license = professionalLicense.trim().toLowerCase();

    if (license.isEmpty) {
      return false;
    }

    final List<Veterinarian> veterinarians = await getAllVeterinarians();

    return veterinarians.any(
      (Veterinarian veterinarian) {
        final String currentLicense =
            veterinarian.professionalLicense?.trim().toLowerCase() ?? '';

        final bool sameLicense = currentLicense == license;

        final bool excluded = excludeVeterinarianId != null &&
            veterinarian.id == excludeVeterinarianId;

        return sameLicense && !excluded;
      },
    );
  }

  // =========================================================
  // ACTUALIZAR
  // =========================================================

  Future<int> updateVeterinarian(
    Veterinarian veterinarian,
  ) async {
    final int? localVeterinarianId = veterinarian.id;

    if (localVeterinarianId == null) {
      throw Exception(
        'No se puede actualizar un veterinario sin ID.',
      );
    }

    if (veterinarian.name.trim().isEmpty) {
      throw Exception(
        'El nombre del veterinario es obligatorio.',
      );
    }

    if (veterinarian.professionalLicense?.trim().isEmpty ?? true) {
      throw Exception(
        'La cédula profesional es obligatoria.',
      );
    }

    final int? serverVeterinarianId =
        await _getVeterinarianServerId(localVeterinarianId);

    if (serverVeterinarianId == null) {
      throw StateError(
        'El veterinario todavía no está sincronizado con el servidor.',
      );
    }

    final response = await ApiClient.instance.put(
      '/veterinarios/$serverVeterinarianId',
      body: veterinarian.toApi(),
    );

    if (response.statusCode == 401) {
      throw Exception(
        'Tu sesión ha expirado. Inicia sesión nuevamente.',
      );
    }

    if (response.statusCode == 403) {
      throw Exception(
        'No tienes permiso para editar veterinarios.',
      );
    }

    if (response.statusCode == 404) {
      throw Exception(
        'El veterinario ya no existe.',
      );
    }

    if (response.statusCode == 422) {
      throw Exception(
        _extractMessage(
          response.body,
          'Los datos del veterinario no son válidos.',
        ),
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'No se pudo actualizar el veterinario. '
        'Código ${response.statusCode}.',
      );
    }

    final Database db = await _databaseHelper.database;

    final Map<String, dynamic> localData = veterinarian.toMap();

    localData.remove('id');
    localData.remove('server_id');

    // SQLite no permite NULL en observations.
    localData['observations'] ??= '';

    await db.update(
      DatabaseHelper.veterinariansTable,
      localData,
      where: 'id = ?',
      whereArgs: [localVeterinarianId],
    );

    return 1;
  }

  // =========================================================
  // DESACTIVAR
  // =========================================================

  Future<int> deleteVeterinarian(
    int veterinarianId,
  ) async {
    // veterinarianId es el ID local de SQLite.
    final int? serverVeterinarianId =
        await _getVeterinarianServerId(veterinarianId);

    if (serverVeterinarianId == null) {
      throw StateError(
        'El veterinario todavía no está sincronizado con el servidor.',
      );
    }

    final response = await ApiClient.instance.delete(
      '/veterinarios/$serverVeterinarianId',
    );

    if (response.statusCode == 401) {
      throw Exception(
        'Tu sesión ha expirado. Inicia sesión nuevamente.',
      );
    }

    if (response.statusCode == 403) {
      throw Exception(
        'No tienes permiso para desactivar veterinarios.',
      );
    }

    if (response.statusCode == 404) {
      throw Exception(
        'El veterinario ya no existe.',
      );
    }

    if (response.statusCode == 422) {
      throw Exception(
        _extractMessage(
          response.body,
          'No se pudo desactivar el veterinario.',
        ),
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'No se pudo desactivar el veterinario. '
        'Código ${response.statusCode}.',
      );
    }

    final Database db = await _databaseHelper.database;

    await db.update(
      DatabaseHelper.veterinariansTable,
      {
        'status': 'Inactivo',
      },
      where: 'id = ?',
      whereArgs: [veterinarianId],
    );

    return 1;
  }

  // =========================================================
  // AUXILIAR
  // =========================================================

  String _extractMessage(
    String body,
    String fallback,
  ) {
    try {
      final dynamic decoded = jsonDecode(body);

      if (decoded is Map<String, dynamic>) {
        final dynamic errors = decoded['errors'];

        if (errors is Map<String, dynamic>) {
          for (final dynamic value in errors.values) {
            if (value is List && value.isNotEmpty) {
              return value.first.toString();
            }
          }
        }

        final dynamic message = decoded['message'];

        if (message != null && message.toString().trim().isNotEmpty) {
          return message.toString();
        }
      }
    } catch (_) {
      // Se utiliza el mensaje predeterminado.
    }

    return fallback;
  }
}
