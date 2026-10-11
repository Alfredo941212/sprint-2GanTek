import '../models/cattle.dart';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/session/session_manager.dart';

class CattleRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  int? _toInt(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
      value.toString(),
    );
  }

  Future<int?> _getCattleServerId(int localCattleId) async {
    final database = await _databaseHelper.database;
    final int userId = await _getCurrentLocalUserId();

    final rows = await database.query(
      DatabaseHelper.cattleTable,
      columns: ['server_id'],
      where: 'id = ? AND user_id = ?',
      whereArgs: [
        localCattleId,
        userId,
      ],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return _toInt(
      rows.first['server_id'],
    );
  }

  Future<int?> _getLotServerId(int localLotId) async {
    final database = await _databaseHelper.database;
    final int userId = await _getCurrentLocalUserId();

    final rows = await database.query(
      DatabaseHelper.lotsTable,
      columns: ['server_id'],
      where: 'id = ? AND user_id = ?',
      whereArgs: [
        localLotId,
        userId,
      ],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return _toInt(
      rows.first['server_id'],
    );
  }

  // =========================================================
  // OBTENER USUARIO ACTUAL
  // =========================================================
  Future<int> _getCurrentLocalUserId() async {
    final currentUser = SessionManager.instance.currentUser;

    if (currentUser?.id != null) {
      return currentUser!.id!;
    }

    final int? storedUserId = await SessionManager.instance.getStoredUserId();

    if (storedUserId == null) {
      throw Exception(
        'No se encontró una sesión local activa.',
      );
    }

    return storedUserId;
  }

  Future<List<Cattle>> _getLocalCattle() async {
    final Database database = await _databaseHelper.database;

    final int userId = await _getCurrentLocalUserId();

    final List<Map<String, dynamic>> rows = await database.query(
      DatabaseHelper.cattleTable,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'code COLLATE NOCASE ASC',
    );

    return rows.map(Cattle.fromMap).toList();
  }

  Future<void> _saveApiCattleLocally(
    List<Map<String, dynamic>> apiCattle,
  ) async {
    final Database database = await _databaseHelper.database;
    final int userId = await _getCurrentLocalUserId();

    await database.transaction((Transaction transaction) async {
      for (final Map<String, dynamic> apiAnimal in apiCattle) {
        final int? serverId = _toInt(
          apiAnimal['id'],
        );

        final int? serverLotId = _toInt(
          apiAnimal['lote_id'],
        );

        if (serverId == null || serverLotId == null) {
          continue;
        }

        // -----------------------------------------------------
        // TRADUCIR ID DEL LOTE:
        // MySQL lotes.id -> SQLite lots.server_id -> SQLite lots.id
        // -----------------------------------------------------

        final List<Map<String, dynamic>> localLots = await transaction.query(
          DatabaseHelper.lotsTable,
          columns: ['id'],
          where: 'user_id = ? AND server_id = ?',
          whereArgs: [
            userId,
            serverLotId,
          ],
          limit: 1,
        );

        // No guardamos el animal si todavía no existe
        // su lote correspondiente en SQLite.
        if (localLots.isEmpty) {
          continue;
        }

        final int localLotId = _toInt(
              localLots.first['id'],
            ) ??
            0;

        if (localLotId <= 0) {
          continue;
        }

        // -----------------------------------------------------
        // BUSCAR SI EL GANADO YA EXISTE LOCALMENTE
        // -----------------------------------------------------

        final List<Map<String, dynamic>> existing = await transaction.query(
          DatabaseHelper.cattleTable,
          columns: ['id'],
          where: 'user_id = ? AND server_id = ?',
          whereArgs: [
            userId,
            serverId,
          ],
          limit: 1,
        );

        final int? localId = existing.isEmpty
            ? null
            : _toInt(
                existing.first['id'],
              );

        final Cattle animal = Cattle.fromApi(
          apiAnimal,
          userId: userId,
          localLotId: localLotId,
          localId: localId,
        );

        final Map<String, dynamic> data = animal.toMap();

        // SQLite asignará el ID si se trata de un registro nuevo.
        data.remove('id');
        // SQLite exige created_at.
        // Conservamos la fecha de Laravel cuando esté disponible.
        if (data['created_at'] == null) {
          data['created_at'] = DateTime.now().toIso8601String();
        }
        if (existing.isEmpty) {
          await transaction.insert(
            DatabaseHelper.cattleTable,
            data,
            conflictAlgorithm: ConflictAlgorithm.abort,
          );
        } else if (localId != null) {
          await transaction.update(
            DatabaseHelper.cattleTable,
            data,
            where: 'id = ?',
            whereArgs: [localId],
          );
        }
      }
    });
  }
  // =========================================================
  // REGISTRAR GANADO
  // =========================================================

  Future<int> insertCattle(
    Cattle cattle,
  ) async {
    // 1. Obtener el ID LOCAL del lote.
    final int? lotId = cattle.lotId;

    if (lotId == null) {
      throw Exception(
        'Debes seleccionar un lote.',
      );
    }

    // 2. Convertir ID local del lote -> ID de Laravel.
    final int? lotServerId = await _getLotServerId(lotId);

    if (lotServerId == null) {
      throw Exception(
        'El lote seleccionado todavía no está sincronizado con el servidor.',
      );
    }

    // 3. Ahora sí construir los datos para Laravel.
    final Map<String, dynamic> body = {
      'lote_id': lotServerId,
      'arete_siniiga': cattle.code.trim(),
      'nombre': cattle.name.trim().isEmpty ? null : cattle.name.trim(),
      'sexo': cattle.sex,
      'raza': cattle.breed.trim().isEmpty ? null : cattle.breed.trim(),
      'fecha_nacimiento': cattle.birthDate == null
          ? null
          : _formatApiDate(
              cattle.birthDate!,
            ),
      'fecha_ingreso': _formatApiDate(
        cattle.entryDate,
      ),
      'peso_inicial': cattle.initialWeight,
      'estado_productivo': cattle.productiveStatus,
      'produccion_minima_diaria': cattle.minimumDailyProduction,
      'estado': cattle.status,
      'observaciones': cattle.observations.trim().isEmpty
          ? null
          : cattle.observations.trim(),
    };

    final response = await ApiClient.instance.post(
      '/ganado',
      body: body,
    );

    if (response.statusCode == 201) {
      final dynamic decoded = jsonDecode(
        response.body,
      );

      if (decoded is Map<String, dynamic>) {
        final dynamic data = decoded['data'];

        if (data is Map<String, dynamic>) {
          final dynamic id = data['id'];

          if (id is int) {
            return id;
          }

          return int.tryParse(
                id?.toString() ?? '',
              ) ??
              0;
        }
      }

      return 0;
    }

    if (response.statusCode == 401) {
      throw Exception(
        'La sesión ha expirado. Inicia sesión nuevamente.',
      );
    }

    if (response.statusCode == 403) {
      throw Exception(
        'No tienes permiso para registrar ganado.',
      );
    }

    if (response.statusCode == 422) {
      throw Exception(
        _extractApiError(
          response.body,
          'Los datos del ganado no son válidos.',
        ),
      );
    }

    throw Exception(
      'No fue posible registrar el ganado '
      '(${response.statusCode}).',
    );
  }

  // =========================================================
  // OBTENER TODO EL GANADO DEL USUARIO
  // =========================================================

  Future<List<Cattle>> getAllCattle() async {
    // Primero intentamos actualizar la copia local desde Laravel.
    try {
      final response = await ApiClient.instance.get(
        '/ganado',
      );

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(
          response.body,
        );

        if (decoded is Map<String, dynamic>) {
          final dynamic data = decoded['data'];

          if (data is List) {
            final List<Map<String, dynamic>> apiCattle =
                data.whereType<Map<String, dynamic>>().toList();

            await _saveApiCattleLocally(
              apiCattle,
            );
          }
        }
      } else if (response.statusCode == 401) {
        final List<Cattle> localCattle = await _getLocalCattle();

        if (localCattle.isNotEmpty) {
          return localCattle;
        }

        throw Exception(
          'La sesión ha expirado. Inicia sesión nuevamente.',
        );
      }
    } catch (e, stackTrace) {
      print('=== ERROR SINCRONIZANDO GANADO ===');
      print('Error: $e');
      print('StackTrace: $stackTrace');
      print('===================================');
    }

    return _getLocalCattle();
  }

  // =========================================================
  // OBTENER GANADO POR ID
  // =========================================================

  Future<Cattle?> getCattleById(
    int id,
  ) async {
    final response = await ApiClient.instance.get(
      '/ganado/$id',
    );

    if (response.statusCode == 404) {
      return null;
    }

    if (response.statusCode == 401) {
      throw Exception(
        'La sesión ha expirado. Inicia sesión nuevamente.',
      );
    }

    if (response.statusCode == 403) {
      throw Exception(
        'No tienes permiso para consultar este animal.',
      );
    }

    if (response.statusCode != 200) {
      throw Exception(
        'No fue posible cargar el ganado '
        '(${response.statusCode}).',
      );
    }

    final dynamic decoded = jsonDecode(
      response.body,
    );

    if (decoded is! Map<String, dynamic>) {
      throw Exception(
        'El servidor devolvió una respuesta inválida.',
      );
    }

    final dynamic data = decoded['data'];

    if (data is! Map<String, dynamic>) {
      throw Exception(
        'El servidor no devolvió la información del animal.',
      );
    }

    return Cattle.fromApi(data);
  }

  // =========================================================
  // VERIFICAR SI EL CÓDIGO / ARETE YA EXISTE
  // =========================================================

  Future<bool> codeExists(
    String code, {
    int? excludeCattleId,
  }) async {
    final List<Cattle> cattle = await getAllCattle();

    final String normalizedCode = code.trim().toLowerCase();

    return cattle.any(
      (Cattle animal) {
        if (excludeCattleId != null && animal.id == excludeCattleId) {
          return false;
        }

        return animal.code.trim().toLowerCase() == normalizedCode;
      },
    );
  }

  // =========================================================
  // ACTUALIZAR GANADO
  // =========================================================

  Future<int> updateCattle(
    Cattle cattle,
  ) async {
    // 1. ID LOCAL del ganado.
    final int? localCattleId = cattle.id;

    if (localCattleId == null) {
      throw Exception(
        'El ganado no tiene un identificador local válido.',
      );
    }

    // 2. Obtener el ID que tiene este animal en Laravel.
    final int? serverId = cattle.serverId ??
        await _getCattleServerId(
          localCattleId,
        );

    if (serverId == null) {
      throw Exception(
        'El ganado todavía no está sincronizado con el servidor.',
      );
    }

    // 3. ID LOCAL del lote seleccionado.
    final int? lotId = cattle.lotId;

    if (lotId == null) {
      throw Exception(
        'Debes seleccionar un lote.',
      );
    }

    // 4. Convertir lote local -> lote Laravel.
    final int? lotServerId = await _getLotServerId(
      lotId,
    );

    if (lotServerId == null) {
      throw Exception(
        'El lote seleccionado todavía no está sincronizado con el servidor.',
      );
    }

    // 5. Construir los datos usando IDs DEL SERVIDOR.
    final Map<String, dynamic> body = {
      'lote_id': lotServerId,
      'arete_siniiga': cattle.code.trim(),
      'nombre': cattle.name.trim().isEmpty ? null : cattle.name.trim(),
      'sexo': cattle.sex,
      'raza': cattle.breed.trim().isEmpty ? null : cattle.breed.trim(),
      'fecha_nacimiento': cattle.birthDate == null
          ? null
          : _formatApiDate(
              cattle.birthDate!,
            ),
      'fecha_ingreso': _formatApiDate(
        cattle.entryDate,
      ),
      'peso_inicial': cattle.initialWeight,
      'estado_productivo': cattle.productiveStatus,
      'produccion_minima_diaria': cattle.minimumDailyProduction,
      'estado': cattle.status,
      'observaciones': cattle.observations.trim().isEmpty
          ? null
          : cattle.observations.trim(),
    };

    // 6. La URL también utiliza el ID DEL SERVIDOR.
    final response = await ApiClient.instance.put(
      '/ganado/$serverId',
      body: body,
    );

    if (response.statusCode == 200) {
      return 1;
    }

    if (response.statusCode == 401) {
      throw Exception(
        'La sesión ha expirado. Inicia sesión nuevamente.',
      );
    }

    if (response.statusCode == 403) {
      throw Exception(
        'No tienes permiso para actualizar este animal.',
      );
    }

    if (response.statusCode == 404) {
      throw Exception(
        'El animal no existe o ya no está disponible.',
      );
    }

    if (response.statusCode == 422) {
      throw Exception(
        _extractApiError(
          response.body,
          'Los datos del ganado no son válidos.',
        ),
      );
    }

    throw Exception(
      'No fue posible actualizar el ganado '
      '(${response.statusCode}).',
    );
  }

  // =========================================================
  // ELIMINAR GANADO
  // =========================================================

  Future<int> deleteCattle(int id) async {
    final int? serverId = await _getCattleServerId(id);

    if (serverId == null) {
      throw Exception(
        'El ganado todavía no está sincronizado con el servidor.',
      );
    }

    final response = await ApiClient.instance.delete(
      '/ganado/$serverId',
    );

    if (response.statusCode == 200 || response.statusCode == 204) {
      return 1;
    }

    if (response.statusCode == 401) {
      throw Exception(
        'La sesión ha expirado. Inicia sesión nuevamente.',
      );
    }

    if (response.statusCode == 403) {
      throw Exception(
        'No tienes permiso para dar de baja este animal.',
      );
    }

    if (response.statusCode == 404) {
      throw Exception(
        'El animal no existe o ya no está disponible.',
      );
    }

    throw Exception(
      'No fue posible dar de baja el animal (${response.statusCode}).',
    );
  }

  // =========================================================
  // OBTENER GANADO ACTIVO
  // =========================================================

  Future<List<Cattle>> getActiveCattle() async {
    final List<Cattle> cattle = await getAllCattle();

    return cattle
        .where(
          (Cattle animal) => animal.status == 'Activo',
        )
        .toList();
  }

  // =========================================================
  // OBTENER VACAS EN PRODUCCIÓN
  // =========================================================

  Future<List<Cattle>> getProductiveCattle() async {
    final List<Cattle> cattle = await getAllCattle();

    final List<Cattle> productiveCattle = cattle.where((Cattle animal) {
      return animal.status == 'Activo' &&
          animal.productiveStatus == 'En producción' &&
          animal.sex == 'Hembra';
    }).toList();

    productiveCattle.sort(
      (Cattle a, Cattle b) => a.code.compareTo(b.code),
    );

    return productiveCattle;
  }

  // =========================================================
  // OBTENER GANADO POR LOTE
  // =========================================================

  Future<List<Cattle>> getCattleByLot(
    int lotId,
  ) async {
    final List<Cattle> cattle = await getAllCattle();

    final List<Cattle> cattleByLot = cattle.where((Cattle animal) {
      return animal.lotId == lotId;
    }).toList();

    cattleByLot.sort(
      (Cattle a, Cattle b) => a.code.compareTo(b.code),
    );

    return cattleByLot;
  }

  // =========================================================
  // CONTAR GANADO
  // =========================================================

  Future<int> countCattle() async {
    final List<Cattle> cattle = await getActiveCattle();

    return cattle.length;
  }

  // =========================================================
  // CONTAR VACAS EN PRODUCCIÓN
  // =========================================================

  Future<int> countProductiveCattle() async {
    final List<Cattle> cattle = await getProductiveCattle();

    return cattle.length;
  }

  String _formatApiDate(
    DateTime date,
  ) {
    final String year = date.year.toString().padLeft(4, '0');
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  String _extractApiError(
    String responseBody,
    String fallback,
  ) {
    try {
      final dynamic decoded = jsonDecode(
        responseBody,
      );

      if (decoded is! Map<String, dynamic>) {
        return fallback;
      }

      final dynamic errors = decoded['errors'];

      if (errors is Map) {
        for (final dynamic value in errors.values) {
          if (value is List && value.isNotEmpty) {
            return value.first.toString();
          }

          if (value != null) {
            return value.toString();
          }
        }
      }

      final dynamic message = decoded['message'];

      if (message != null && message.toString().trim().isNotEmpty) {
        return message.toString();
      }
    } catch (_) {
      // Se utiliza el mensaje genérico.
    }

    return fallback;
  }
}
