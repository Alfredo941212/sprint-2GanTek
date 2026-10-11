import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../../core/database/database_helper.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/session/session_manager.dart';
import '../../../cattle/data/repositories/cattle_repository.dart';
import '../models/lot.dart';

class LotRepository {
  LotRepository();

  final CattleRepository _cattleRepository = CattleRepository();
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  int? _toInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString());
  }

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

  // =========================================================
  // REGISTRAR LOTE
  // =========================================================

  Future<int> insertLot(Lot lot) async {
    final int? farmId = lot.farmId;

    if (farmId == null) {
      throw Exception(
        'Debes seleccionar una finca para registrar el lote.',
      );
    }

    final Map<String, dynamic> body = {
      'finca_id': farmId,
      'nombre': lot.name.trim(),
      'descripcion': lot.description?.trim().isEmpty == true
          ? null
          : lot.description?.trim(),
      'produccion_minima_por_vaca': lot.minimumProductionPerCow,
      'estado': lot.status,
    };

    final response = await ApiClient.instance.post(
      '/lotes',
      body: body,
    );

    if (response.statusCode == 401) {
      throw Exception(
        'La sesión ha expirado. Inicia sesión nuevamente.',
      );
    }

    if (response.statusCode == 422) {
      final dynamic decoded = jsonDecode(response.body);

      String message = 'Los datos del lote no son válidos.';

      if (decoded is Map<String, dynamic>) {
        final dynamic serverMessage = decoded['message'];

        if (serverMessage != null) {
          message = serverMessage.toString();
        }
      }

      throw Exception(message);
    }

    if (response.statusCode != 201) {
      throw Exception(
        'No fue posible registrar el lote (${response.statusCode}).',
      );
    }

    final dynamic decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw Exception(
        'La respuesta del servidor no tiene el formato esperado.',
      );
    }

    final dynamic data = decoded['data'];

    if (data is! Map<String, dynamic>) {
      throw Exception(
        'El servidor no devolvió los datos del lote registrado.',
      );
    }

    final Map<String, dynamic> apiLot = Map<String, dynamic>.from(data);

    // Guardar inmediatamente la respuesta de Laravel en SQLite.
    await _saveApiLotsLocally(
      [apiLot],
    );

    final int? serverId = _toInt(apiLot['id']);

    if (serverId == null) {
      throw Exception(
        'El servidor no devolvió un identificador válido para el lote.',
      );
    }

    // Recuperar el ID LOCAL de SQLite.
    final Database database = await _databaseHelper.database;
    final int userId = await _getCurrentLocalUserId();

    final List<Map<String, dynamic>> localRows = await database.query(
      DatabaseHelper.lotsTable,
      columns: ['id'],
      where: 'user_id = ? AND server_id = ?',
      whereArgs: [userId, serverId],
      limit: 1,
    );

    if (localRows.isEmpty) {
      throw Exception(
        'El lote se registró en el servidor, '
        'pero no pudo guardarse localmente.',
      );
    }

    return localRows.first['id'] as int;
  }

  Future<List<Lot>> _getLocalLots() async {
    final Database database = await _databaseHelper.database;
    final int userId = await _getCurrentLocalUserId();

    final List<Map<String, dynamic>> rows = await database.query(
      DatabaseHelper.lotsTable,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'name COLLATE NOCASE ASC',
    );

    return rows.map(Lot.fromMap).toList();
  }

  Future<void> _saveApiLotsLocally(
    List<Map<String, dynamic>> apiLots,
  ) async {
    final Database database = await _databaseHelper.database;
    final int userId = await _getCurrentLocalUserId();

    await database.transaction((Transaction transaction) async {
      for (final Map<String, dynamic> apiLot in apiLots) {
        final Lot serverLot = Lot.fromApi(
          apiLot,
          userId: userId,
        );

        final int? serverId = serverLot.serverId;

        if (serverId == null) {
          continue;
        }

        final List<Map<String, dynamic>> existing = await transaction.query(
          DatabaseHelper.lotsTable,
          columns: ['id'],
          where: 'user_id = ? AND server_id = ?',
          whereArgs: [userId, serverId],
          limit: 1,
        );

        final Map<String, dynamic> data = serverLot.toMap();
        data.remove('id');
        data['description'] ??= '';

        if (existing.isEmpty) {
          await transaction.insert(
            DatabaseHelper.lotsTable,
            data,
            conflictAlgorithm: ConflictAlgorithm.abort,
          );
        } else {
          final int localId = existing.first['id'] as int;

          await transaction.update(
            DatabaseHelper.lotsTable,
            data,
            where: 'id = ?',
            whereArgs: [localId],
          );
        }
      }
    });
  }

  // =========================================================
  // OBTENER TODOS LOS LOTES
  // =========================================================

  Future<List<Lot>> getAllLots() async {
    // =========================================================
    // 1. INTENTAR ACTUALIZAR DESDE LARAVEL
    // =========================================================

    try {
      final response = await ApiClient.instance.get(
        '/lotes',
      );

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(
          response.body,
        );

        if (decoded is Map<String, dynamic>) {
          final dynamic data = decoded['data'];

          if (data is List) {
            final List<Map<String, dynamic>> apiLots =
                data.whereType<Map<String, dynamic>>().toList();

            // Guardamos/actualizamos la copia local.
            await _saveApiLotsLocally(
              apiLots,
            );
          }
        }
      } else if (response.statusCode == 401) {
        // Si existe información local, todavía puede utilizarse
        // para el funcionamiento offline.
        final List<Lot> localLots = await _getLocalLots();

        if (localLots.isNotEmpty) {
          return localLots;
        }

        throw Exception(
          'La sesión ha expirado. Inicia sesión nuevamente.',
        );
      }
    } catch (e, stackTrace) {
      print('=== ERROR SINCRONIZANDO LOTES ===');
      print('Error: $e');
      print('StackTrace: $stackTrace');
      print('=================================');
    }

    // =========================================================
    // 2. SQLITE ES LA FUENTE QUE UTILIZA LA APP
    // =========================================================

    return _getLocalLots();
  }

  // =========================================================
  // OBTENER LOTES ACTIVOS
  // =========================================================

  Future<List<Lot>> getActiveLots() async {
    final List<Lot> lots = await getAllLots();

    final List<Lot> activeLots = lots.where(
      (Lot lot) {
        return lot.status.trim().toLowerCase() == 'activo';
      },
    ).toList();

    activeLots.sort(
      (Lot a, Lot b) => a.name.toLowerCase().compareTo(
            b.name.toLowerCase(),
          ),
    );

    return activeLots;
  }

  // =========================================================
  // OBTENER LOTE POR ID
  // =========================================================

  Future<Lot?> getLotById(
    int lotId,
  ) async {
    final response = await ApiClient.instance.get(
      '/lotes/$lotId',
    );

    if (response.statusCode == 401) {
      throw Exception(
        'La sesión ha expirado. Inicia sesión nuevamente.',
      );
    }

    if (response.statusCode == 403) {
      throw Exception(
        'No tienes permiso para consultar este lote.',
      );
    }

    if (response.statusCode == 404) {
      return null;
    }

    if (response.statusCode != 200) {
      throw Exception(
        'No fue posible cargar el lote (${response.statusCode}).',
      );
    }

    final dynamic decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw Exception(
        'La respuesta del servidor no tiene el formato esperado.',
      );
    }

    final dynamic data = decoded['data'];

    if (data is! Map<String, dynamic>) {
      throw Exception(
        'No fue posible interpretar los datos del lote.',
      );
    }

    return Lot.fromApi(
      data,
      localId: lotId,
    );
  }

  // =========================================================
  // VALIDAR NOMBRE REPETIDO
  // =========================================================

  Future<bool> nameExists(
    String name, {
    int? excludeLotId,
  }) async {
    final String normalizedName = name.trim().toLowerCase();

    if (normalizedName.isEmpty) {
      return false;
    }

    final List<Lot> lots = await getAllLots();

    return lots.any((Lot lot) {
      final bool sameName = lot.name.trim().toLowerCase() == normalizedName;

      final bool isExcluded = excludeLotId != null && lot.id == excludeLotId;

      return sameName && !isExcluded;
    });
  }

  // =========================================================
  // ACTUALIZAR LOTE
  // =========================================================

  Future<int> updateLot(
    Lot lot,
  ) async {
    final int? lotId = lot.id;

    if (lotId == null) {
      throw Exception(
        'El lote no tiene un ID válido.',
      );
    }

    final Map<String, dynamic> body = {
      'nombre': lot.name.trim(),
      'descripcion': lot.description?.trim().isEmpty == true
          ? null
          : lot.description?.trim(),
      'produccion_minima_por_vaca': lot.minimumProductionPerCow,
      'estado': lot.status,
    };

    final response = await ApiClient.instance.put(
      '/lotes/$lotId',
      body: body,
    );

    if (response.statusCode == 401) {
      throw Exception(
        'La sesión ha expirado. Inicia sesión nuevamente.',
      );
    }

    if (response.statusCode == 403) {
      throw Exception(
        'No tienes permiso para modificar este lote.',
      );
    }

    if (response.statusCode == 404) {
      throw Exception(
        'El lote ya no existe o no está disponible.',
      );
    }

    if (response.statusCode == 422) {
      final dynamic decoded = jsonDecode(response.body);

      String message = 'Los datos del lote no son válidos.';

      if (decoded is Map<String, dynamic>) {
        final dynamic serverMessage = decoded['message'];

        if (serverMessage != null) {
          message = serverMessage.toString();
        }
      }

      throw Exception(message);
    }

    if (response.statusCode != 200) {
      throw Exception(
        'No fue posible actualizar el lote (${response.statusCode}).',
      );
    }

    return 1;
  }

// =========================================================
// CONTAR GANADO ACTIVO DEL LOTE
// =========================================================

  Future<int> countCattleInLot(
    int lotId,
  ) async {
    final cattle = await _cattleRepository.getCattleByLot(lotId);

    return cattle.where((animal) {
      return animal.status == 'Activo';
    }).length;
  }

// =========================================================
// CONTAR VACAS EN PRODUCCIÓN DEL LOTE
// =========================================================

  Future<int> countProductiveCattleInLot(
    int lotId,
  ) async {
    final cattle = await _cattleRepository.getCattleByLot(lotId);

    return cattle.where((animal) {
      return animal.status == 'Activo' &&
          animal.sex == 'Hembra' &&
          animal.productiveStatus == 'En producción';
    }).length;
  }

  // =========================================================
  // ELIMINAR LOTE
  // =========================================================

  Future<int> deleteLot(
    int lotId,
  ) async {
    final response = await ApiClient.instance.delete(
      '/lotes/$lotId',
    );

    if (response.statusCode == 401) {
      throw Exception(
        'Tu sesión ha expirado. Inicia sesión nuevamente.',
      );
    }

    if (response.statusCode == 403) {
      throw Exception(
        'No tienes permiso para eliminar este lote.',
      );
    }

    if (response.statusCode == 404) {
      throw Exception(
        'El lote ya no existe.',
      );
    }

    if (response.statusCode == 409 || response.statusCode == 422) {
      String message =
          'No se puede eliminar el lote porque tiene información relacionada.';

      try {
        final dynamic decoded = jsonDecode(response.body);

        if (decoded is Map<String, dynamic>) {
          final dynamic apiMessage = decoded['message'];

          if (apiMessage != null && apiMessage.toString().trim().isNotEmpty) {
            message = apiMessage.toString();
          }
        }
      } catch (_) {
        // Se conserva el mensaje predeterminado.
      }

      throw Exception(message);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'No se pudo eliminar el lote. '
        'Código ${response.statusCode}.',
      );
    }

    return 1;
  }
}
