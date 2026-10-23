import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/session/session_manager.dart';
import '../../data/models/milking_group.dart';

class MilkingGroupRepository {
  MilkingGroupRepository({
    DatabaseHelper? databaseHelper,
  }) : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;

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
  // OBTENER GRUPOS
  // =========================================================

  Future<List<MilkingGroup>> getGroups() async {
    final database = await _databaseHelper.database;
    final int userId = _requireUserId();

    final rows = await database.query(
      DatabaseHelper.milkingGroupsTable,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'sort_order ASC',
    );

    return rows.map(MilkingGroup.fromMap).toList();
  }

  // =========================================================
  // OBTENER SOLO ACTIVOS
  // =========================================================

  Future<List<MilkingGroup>> getActiveGroups() async {
    final database = await _databaseHelper.database;
    final int userId = _requireUserId();

    final rows = await database.query(
      DatabaseHelper.milkingGroupsTable,
      where: '''
        user_id = ?
        AND status = ?
      ''',
      whereArgs: [
        userId,
        'Activo',
      ],
      orderBy: 'sort_order ASC',
    );

    return rows.map(MilkingGroup.fromMap).toList();
  }

  // =========================================================
  // CREAR GRUPO
  // =========================================================

  Future<int> createGroup({
    required String name,
  }) async {
    final String cleanName = name.trim();

    if (cleanName.isEmpty) {
      throw Exception(
        'El nombre del grupo es obligatorio.',
      );
    }

    final database = await _databaseHelper.database;
    final int userId = _requireUserId();

    // =========================================================
    // 1. GUARDAR PRIMERO EN SQLITE
    // =========================================================

    final int localId = await database.transaction<int>(
      (transaction) async {
        final duplicate = await transaction.query(
          DatabaseHelper.milkingGroupsTable,
          columns: ['id'],
          where: '''
          user_id = ?
          AND LOWER(name) = LOWER(?)
        ''',
          whereArgs: [
            userId,
            cleanName,
          ],
          limit: 1,
        );

        if (duplicate.isNotEmpty) {
          throw Exception(
            'Ya existe un grupo con ese nombre.',
          );
        }

        final orderResult = await transaction.rawQuery(
          '''
        SELECT MAX(sort_order) AS max_order
        FROM ${DatabaseHelper.milkingGroupsTable}
        WHERE user_id = ?
        ''',
          [
            userId,
          ],
        );

        final int maxOrder =
            (orderResult.first['max_order'] as num?)?.toInt() ?? 0;

        final DateTime now = DateTime.now();

        return transaction.insert(
          DatabaseHelper.milkingGroupsTable,
          {
            'user_id': userId,
            'name': cleanName,
            'sort_order': maxOrder + 1,
            'status': 'Activo',
            'sync_status': 'pending',
            'created_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
            'last_sync_error': null,
          },
        );
      },
    );

    // =========================================================
    // 2. INTENTAR SINCRONIZAR CON LARAVEL
    // =========================================================

    try {
      final response = await ApiClient.instance.post(
        '/grupos-ordenio',
        body: {
          'nombre': cleanName,
        },
      );

      debugPrint(
        'GRUPOS API STATUS: ${response.statusCode}',
      );

      debugPrint(
        'GRUPOS API BODY: ${response.body}',
      );

      if (response.statusCode == 201) {
        final dynamic decoded = jsonDecode(
          response.body,
        );

        if (decoded is Map<String, dynamic>) {
          final dynamic data = decoded['data'];

          if (data is Map<String, dynamic>) {
            final dynamic serverIdValue = data['id'];

            final int? serverId = serverIdValue is int
                ? serverIdValue
                : int.tryParse(
                    serverIdValue?.toString() ?? '',
                  );

            if (serverId != null) {
              await database.update(
                DatabaseHelper.milkingGroupsTable,
                {
                  'server_id': serverId,
                  'sync_status': 'synced',
                  'updated_at': DateTime.now().toIso8601String(),
                  'last_sync_error': null,
                },
                where: 'id = ?',
                whereArgs: [
                  localId,
                ],
              );

              final rows = await database.query(
                DatabaseHelper.milkingGroupsTable,
                where: 'id = ?',
                whereArgs: [
                  localId,
                ],
                limit: 1,
              );

              debugPrint(
                'GRUPO LOCAL DESPUÉS DE SYNC: ${rows.first}',
              );
            }
          }
        }

        return localId;
      }

      String message =
          'No se pudo sincronizar el grupo. Código ${response.statusCode}.';

      try {
        final dynamic decoded = jsonDecode(
          response.body,
        );

        if (decoded is Map<String, dynamic>) {
          final dynamic serverMessage = decoded['message'];

          if (serverMessage != null &&
              serverMessage.toString().trim().isNotEmpty) {
            message = serverMessage.toString();
          }
        }
      } catch (_) {
        // Conservamos el mensaje predeterminado.
      }

      await database.update(
        DatabaseHelper.milkingGroupsTable,
        {
          'sync_status': 'error',
          'last_sync_error': message,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [
          localId,
        ],
      );

      return localId;
    } catch (error) {
      debugPrint(
        'ERROR SINCRONIZANDO GRUPO: $error',
      );
      await database.update(
        DatabaseHelper.milkingGroupsTable,
        {
          'sync_status': 'pending',
          'last_sync_error': error.toString(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [
          localId,
        ],
      );

      return localId;
    }
  }
// =========================================================
// ELIMINAR GRUPO
// =========================================================

  Future<void> deleteGroup({
    required int groupId,
  }) async {
    final database = await _databaseHelper.database;
    final int userId = _requireUserId();

    // 1. Buscar el grupo local
    final groupRows = await database.query(
      DatabaseHelper.milkingGroupsTable,
      columns: [
        'id',
        'server_id',
        'name',
      ],
      where: '''
      id = ?
      AND user_id = ?
    ''',
      whereArgs: [
        groupId,
        userId,
      ],
      limit: 1,
    );

    if (groupRows.isEmpty) {
      throw Exception('El grupo seleccionado no existe.');
    }

    // 2. Verificar que no tenga ganado asignado
    final cattleCount = await getCattleCount(groupId);

    if (cattleCount > 0) {
      throw Exception(
        'No se puede eliminar el grupo porque tiene ganado asignado.',
      );
    }

    final int? serverId = (groupRows.first['server_id'] as num?)?.toInt();

    // =========================================================
    // 3. SI YA EXISTE EN LARAVEL, ELIMINAR PRIMERO EN SERVIDOR
    // =========================================================

    if (serverId != null) {
      final response = await ApiClient.instance.delete(
        '/grupos-ordenio/$serverId',
      );

      debugPrint(
        'ELIMINAR GRUPO API STATUS: ${response.statusCode}',
      );

      debugPrint(
        'ELIMINAR GRUPO API BODY: ${response.body}',
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception(
          'No se pudo eliminar el grupo. ${response.body}',
        );
      }
    }

    // =========================================================
    // 4. ELIMINAR LOCALMENTE
    // =========================================================

    // Si el grupo estaba sincronizado con Laravel,
// lo dejamos como inactivo localmente para conservar historial.
    if (serverId != null) {
      await database.update(
        DatabaseHelper.milkingGroupsTable,
        {
          'status': 'Inactivo',
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: '''
      id = ?
      AND user_id = ?
    ''',
        whereArgs: [
          groupId,
          userId,
        ],
      );

      debugPrint(
        'GRUPO LOCAL $groupId MARCADO COMO INACTIVO',
      );
    } else {
      // Si nunca llegó al servidor y está vacío,
      // se puede eliminar completamente.
      await database.delete(
        DatabaseHelper.milkingGroupsTable,
        where: '''
      id = ?
      AND user_id = ?
    ''',
        whereArgs: [
          groupId,
          userId,
        ],
      );

      debugPrint(
        'GRUPO LOCAL $groupId ELIMINADO COMPLETAMENTE',
      );
    }
  }

  Future<int?> _getGroupServerId(
    int localGroupId,
  ) async {
    final database = await _databaseHelper.database;

    final rows = await database.query(
      DatabaseHelper.milkingGroupsTable,
      columns: ['server_id'],
      where: 'id = ?',
      whereArgs: [
        localGroupId,
      ],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return (rows.first['server_id'] as num?)?.toInt();
  }

  Future<int?> _getCattleServerId(
    int localCattleId,
  ) async {
    final database = await _databaseHelper.database;

    final rows = await database.query(
      DatabaseHelper.cattleTable,
      columns: ['server_id'],
      where: 'id = ?',
      whereArgs: [
        localCattleId,
      ],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return (rows.first['server_id'] as num?)?.toInt();
  }

  // =========================================================
  // ASIGNAR VACA A GRUPO
  // =========================================================

  Future<void> assignCattle({
    required int groupId,
    required int cattleId,
  }) async {
    debugPrint(
      'ENTRÓ A assignCattle -> groupId: $groupId, cattleId: $cattleId',
    );
    final database = await _databaseHelper.database;
    final int userId = _requireUserId();

    // =========================================================
    // 1. VALIDAR E INSERTAR LOCALMENTE
    // =========================================================

    await database.transaction(
      (transaction) async {
        final groupRows = await transaction.query(
          DatabaseHelper.milkingGroupsTable,
          columns: ['id'],
          where: '''
          id = ?
          AND user_id = ?
          AND status = ?
        ''',
          whereArgs: [
            groupId,
            userId,
            'Activo',
          ],
          limit: 1,
        );

        if (groupRows.isEmpty) {
          throw Exception(
            'El grupo seleccionado no existe o está inactivo.',
          );
        }

        final cattleRows = await transaction.query(
          DatabaseHelper.cattleTable,
          columns: [
            'id',
            'sex',
            'status',
            'productive_status',
          ],
          where: '''
          id = ?
          AND user_id = ?
        ''',
          whereArgs: [
            cattleId,
            userId,
          ],
          limit: 1,
        );

        if (cattleRows.isEmpty) {
          throw Exception(
            'No se encontró el ganado seleccionado.',
          );
        }

        final animal = cattleRows.first;

        if (animal['sex']?.toString() != 'Hembra') {
          throw Exception(
            'Solo se pueden agregar hembras a un grupo de ordeña.',
          );
        }

        if (animal['status']?.toString() != 'Activo') {
          throw Exception(
            'Solo se puede agregar ganado activo.',
          );
        }

        if (animal['productive_status']?.toString() != 'En producción') {
          throw Exception(
            'La vaca no se encuentra en producción.',
          );
        }

        final existingGroup = await transaction.rawQuery(
          '''
        SELECT
          mgc.group_id,
          mg.name
        FROM ${DatabaseHelper.milkingGroupCattleTable} mgc
        INNER JOIN ${DatabaseHelper.milkingGroupsTable} mg
          ON mg.id = mgc.group_id
        WHERE mgc.cattle_id = ?
          AND mg.user_id = ?
          AND mg.status = ?
        LIMIT 1
        ''',
          [
            cattleId,
            userId,
            'Activo',
          ],
        );

        if (existingGroup.isNotEmpty) {
          final int? existingGroupId =
              (existingGroup.first['group_id'] as num?)?.toInt();

          if (existingGroupId == groupId) {
            throw Exception(
              'La vaca ya pertenece a este grupo.',
            );
          }

          throw Exception(
            'La vaca ya pertenece a otro grupo de ordeña activo.',
          );
        }

        await transaction.insert(
          DatabaseHelper.milkingGroupCattleTable,
          {
            'group_id': groupId,
            'cattle_id': cattleId,
            'created_at': DateTime.now().toIso8601String(),
          },
        );
      },
    );

    // =========================================================
    // 2. INTENTAR SINCRONIZAR CON LARAVEL
    // =========================================================

    try {
      final int? groupServerId = await _getGroupServerId(groupId);

      final int? cattleServerId = await _getCattleServerId(cattleId);

      if (groupServerId == null) {
        debugPrint(
          'ASIGNACIÓN PENDIENTE: grupo sin server_id.',
        );

        return;
      }

      if (cattleServerId == null) {
        debugPrint(
          'ASIGNACIÓN PENDIENTE: vaca sin server_id.',
        );

        return;
      }

      final response = await ApiClient.instance.post(
        '/grupos-ordenio/$groupServerId/ganado',
        body: {
          'ganado_id': cattleServerId,
        },
      );

      debugPrint(
        'ASIGNAR VACA API STATUS: ${response.statusCode}',
      );

      debugPrint(
        'ASIGNAR VACA API BODY: ${response.body}',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return;
      }

      if (response.statusCode == 422) {
        throw Exception(
          _extractMessage(
            response.body,
            'No se pudo asignar la vaca al grupo.',
          ),
        );
      }

      if (response.statusCode == 401) {
        throw Exception(
          'Tu sesión ha expirado. Inicia sesión nuevamente.',
        );
      }

      if (response.statusCode == 403) {
        throw Exception(
          'No tienes permiso para modificar este grupo.',
        );
      }

      throw Exception(
        'No se pudo sincronizar la asignación. '
        'Código ${response.statusCode}.',
      );
    } catch (error) {
      debugPrint(
        'ERROR SINCRONIZANDO ASIGNACIÓN: $error',
      );

      // La relación local se conserva para mantener
      // el funcionamiento offline.
    }
  }

  // =========================================================
  // QUITAR VACA DEL GRUPO
  // =========================================================

  Future<void> removeCattle({
    required int groupId,
    required int cattleId,
  }) async {
    final database = await _databaseHelper.database;
    final int userId = _requireUserId();

    final groupRows = await database.query(
      DatabaseHelper.milkingGroupsTable,
      columns: [
        'id',
        'server_id',
      ],
      where: '''
      id = ?
      AND user_id = ?
    ''',
      whereArgs: [
        groupId,
        userId,
      ],
      limit: 1,
    );

    if (groupRows.isEmpty) {
      throw Exception(
        'El grupo seleccionado no existe.',
      );
    }

    final cattleRows = await database.query(
      DatabaseHelper.cattleTable,
      columns: [
        'id',
        'server_id',
      ],
      where: '''
      id = ?
      AND user_id = ?
    ''',
      whereArgs: [
        cattleId,
        userId,
      ],
      limit: 1,
    );

    if (cattleRows.isEmpty) {
      throw Exception(
        'No se encontró el ganado seleccionado.',
      );
    }

    final int? groupServerId = (groupRows.first['server_id'] as num?)?.toInt();

    final int? cattleServerId =
        (cattleRows.first['server_id'] as num?)?.toInt();

    // =========================================================
    // 1. ELIMINAR LOCALMENTE
    // =========================================================

    await database.delete(
      DatabaseHelper.milkingGroupCattleTable,
      where: '''
      group_id = ?
      AND cattle_id = ?
    ''',
      whereArgs: [
        groupId,
        cattleId,
      ],
    );

    // =========================================================
    // 2. INTENTAR SINCRONIZAR CON LARAVEL
    // =========================================================

    try {
      if (groupServerId == null) {
        debugPrint(
          'ELIMINACIÓN PENDIENTE: grupo sin server_id.',
        );
        return;
      }

      if (cattleServerId == null) {
        debugPrint(
          'ELIMINACIÓN PENDIENTE: vaca sin server_id.',
        );
        return;
      }

      final response = await ApiClient.instance.delete(
        '/grupos-ordenio/$groupServerId/ganado/$cattleServerId',
      );
      debugPrint(
        'QUITAR VACA IDS -> '
        'groupLocalId: $groupId, '
        'groupServerId: $groupServerId, '
        'cattleLocalId: $cattleId, '
        'cattleServerId: $cattleServerId',
      );

      debugPrint(
        'QUITAR VACA ENDPOINT: '
        '/grupos-ordenio/$groupServerId/ganado/$cattleServerId',
      );

      debugPrint(
        'QUITAR VACA API STATUS: ${response.statusCode}',
      );

      debugPrint(
        'QUITAR VACA API BODY: ${response.body}',
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        return;
      }

      if (response.statusCode == 401) {
        throw Exception(
          'Tu sesión ha expirado. Inicia sesión nuevamente.',
        );
      }

      if (response.statusCode == 403) {
        throw Exception(
          'No tienes permiso para modificar este grupo.',
        );
      }

      if (response.statusCode == 404) {
        throw Exception(
          'La relación entre el grupo y la vaca ya no existe en el servidor.',
        );
      }

      throw Exception(
        'No se pudo sincronizar la eliminación. '
        'Código ${response.statusCode}.',
      );
    } catch (error) {
      debugPrint(
        'ERROR SINCRONIZANDO ELIMINACIÓN: $error',
      );

      // La eliminación local se conserva para mantener
      // funcionamiento offline.
    }
  }

  // =========================================================
  // CONTAR VACAS DEL GRUPO
  // =========================================================
  Future<int> getCattleCount(
    int groupId,
  ) async {
    final database = await _databaseHelper.database;
    final int userId = _requireUserId();

    final result = await database.rawQuery(
      '''
      SELECT COUNT(*) AS total
      FROM ${DatabaseHelper.milkingGroupCattleTable} mgc
      INNER JOIN ${DatabaseHelper.milkingGroupsTable} mg
        ON mg.id = mgc.group_id
      WHERE mgc.group_id = ?
        AND mg.user_id = ?
      ''',
      [
        groupId,
        userId,
      ],
    );

    return (result.first['total'] as num?)?.toInt() ?? 0;
  }

// =========================================================
// OBTENER IDS DE VACAS DEL GRUPO
// =========================================================

  Future<List<int>> getCattleIdsByGroup(
    int groupId,
  ) async {
    final database = await _databaseHelper.database;
    final int userId = _requireUserId();

    final rows = await database.rawQuery(
      '''
      SELECT mgc.cattle_id
      FROM ${DatabaseHelper.milkingGroupCattleTable} mgc
      INNER JOIN ${DatabaseHelper.milkingGroupsTable} mg
        ON mg.id = mgc.group_id
      WHERE mgc.group_id = ?
        AND mg.user_id = ?
      ORDER BY mgc.id ASC
      ''',
      [
        groupId,
        userId,
      ],
    );

    return rows
        .map(
          (row) => (row['cattle_id'] as num).toInt(),
        )
        .toList();
  }

  Future<List<int>> getAllAssignedCattleIds() async {
    final database = await _databaseHelper.database;
    final int userId = _requireUserId();

    final rows = await database.rawQuery(
      '''
    SELECT DISTINCT mgc.cattle_id
    FROM ${DatabaseHelper.milkingGroupCattleTable} mgc

    INNER JOIN ${DatabaseHelper.milkingGroupsTable} mg
      ON mg.id = mgc.group_id

    WHERE mg.user_id = ?
      AND mg.status = 'Activo'
    ''',
      [
        userId,
      ],
    );

    return rows
        .map(
          (row) => (row['cattle_id'] as num).toInt(),
        )
        .toList();
  }

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
      // Se usa el mensaje por defecto.
    }

    return fallback;
  }

  Future<int> syncPendingGroups() async {
    final database = await _databaseHelper.database;
    final int userId = _requireUserId();

    final pendingGroups = await database.query(
      DatabaseHelper.milkingGroupsTable,
      where: '''
      user_id = ?
      AND server_id IS NULL
    ''',
      whereArgs: [userId],
      orderBy: 'sort_order ASC',
    );

    if (pendingGroups.isEmpty) {
      debugPrint('NO HAY GRUPOS PENDIENTES POR SINCRONIZAR');
      return 0;
    }

    debugPrint(
      'GRUPOS PENDIENTES: ${pendingGroups.length}',
    );

    int synchronized = 0;

    for (final group in pendingGroups) {
      final int localId = (group['id'] as num).toInt();

      final String name = group['name'].toString();

      try {
        final response = await ApiClient.instance.post(
          '/grupos-ordenio',
          body: {
            'nombre': name,
          },
        );

        debugPrint(
          'SYNC GRUPO $localId STATUS: ${response.statusCode}',
        );

        debugPrint(
          'SYNC GRUPO $localId BODY: ${response.body}',
        );

        if (response.statusCode == 201) {
          final dynamic decoded = jsonDecode(response.body);

          if (decoded is Map<String, dynamic>) {
            final dynamic data = decoded['data'];

            if (data is Map<String, dynamic>) {
              final int? serverId = (data['id'] as num?)?.toInt();

              if (serverId != null) {
                await database.update(
                  DatabaseHelper.milkingGroupsTable,
                  {
                    'server_id': serverId,
                    'sync_status': 'synced',
                    'last_sync_error': null,
                    'updated_at': DateTime.now().toIso8601String(),
                  },
                  where: 'id = ? AND user_id = ?',
                  whereArgs: [
                    localId,
                    userId,
                  ],
                );

                synchronized++;

                debugPrint(
                  'GRUPO LOCAL $localId → SERVER $serverId',
                );
              }
            }
          }
        } else {
          await database.update(
            DatabaseHelper.milkingGroupsTable,
            {
              'sync_status': 'error',
              'last_sync_error':
                  'HTTP ${response.statusCode}: ${response.body}',
              'updated_at': DateTime.now().toIso8601String(),
            },
            where: 'id = ? AND user_id = ?',
            whereArgs: [
              localId,
              userId,
            ],
          );
        }
      } catch (error) {
        debugPrint(
          'ERROR SINCRONIZANDO GRUPO LOCAL $localId: $error',
        );

        await database.update(
          DatabaseHelper.milkingGroupsTable,
          {
            'sync_status': 'pending',
            'last_sync_error': error.toString(),
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ? AND user_id = ?',
          whereArgs: [
            localId,
            userId,
          ],
        );
      }
    }

    debugPrint(
      'GRUPOS SINCRONIZADOS: $synchronized/${pendingGroups.length}',
    );

    return synchronized;
  }

  Future<int> syncPendingGroupCattle() async {
    final database = await _databaseHelper.database;
    final int userId = _requireUserId();

    final groups = await database.query(
      DatabaseHelper.milkingGroupsTable,
      where: '''
      user_id = ?
      AND server_id IS NOT NULL
    ''',
      whereArgs: [userId],
      orderBy: 'sort_order ASC',
    );

    if (groups.isEmpty) {
      debugPrint(
        'NO HAY GRUPOS SINCRONIZADOS PARA REVISAR VACAS',
      );
      return 0;
    }

    int synchronized = 0;

    for (final group in groups) {
      final int localGroupId = (group['id'] as num).toInt();

      final int serverGroupId = (group['server_id'] as num).toInt();

      final cattleRelations = await database.query(
        DatabaseHelper.milkingGroupCattleTable,
        where: 'group_id = ?',
        whereArgs: [localGroupId],
      );

      if (cattleRelations.isEmpty) {
        continue;
      }

      debugPrint(
        'GRUPO LOCAL $localGroupId TIENE '
        '${cattleRelations.length} VACA(S)',
      );

      for (final relation in cattleRelations) {
        final int localCattleId = (relation['cattle_id'] as num).toInt();

        final cattleRows = await database.query(
          DatabaseHelper.cattleTable,
          columns: [
            'id',
            'server_id',
          ],
          where: '''
          id = ?
          AND user_id = ?
        ''',
          whereArgs: [
            localCattleId,
            userId,
          ],
          limit: 1,
        );

        if (cattleRows.isEmpty) {
          debugPrint(
            'VACA LOCAL $localCattleId NO ENCONTRADA',
          );
          continue;
        }

        final int? serverCattleId =
            (cattleRows.first['server_id'] as num?)?.toInt();

        if (serverCattleId == null) {
          debugPrint(
            'VACA LOCAL $localCattleId SIN server_id',
          );
          continue;
        }

        try {
          final response = await ApiClient.instance.post(
            '/grupos-ordenio/$serverGroupId/ganado',
            body: {
              'ganado_id': serverCattleId,
            },
          );

          debugPrint(
            'SYNC VACA LOCAL $localCattleId '
            '→ GRUPO SERVER $serverGroupId '
            'STATUS: ${response.statusCode}',
          );

          debugPrint(
            'SYNC VACA BODY: ${response.body}',
          );

          if (response.statusCode == 200 || response.statusCode == 201) {
            synchronized++;
          } else if (response.statusCode == 422) {
            // Puede ocurrir si la vaca ya está asignada.
            debugPrint(
              'VACA $localCattleId NO SINCRONIZADA: '
              'VALIDACIÓN 422',
            );
          }
        } catch (error) {
          debugPrint(
            'ERROR SINCRONIZANDO VACA '
            '$localCattleId DEL GRUPO $localGroupId: $error',
          );
        }
      }
    }

    debugPrint(
      'RELACIONES DE VACAS SINCRONIZADAS: $synchronized',
    );

    return synchronized;
  }
}
