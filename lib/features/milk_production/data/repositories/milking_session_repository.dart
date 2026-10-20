import 'package:uuid/uuid.dart';
import 'dart:convert';
import '../../../../core/network/api_client.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/session/session_manager.dart';
import '../models/milking_session.dart';

class MilkingSessionRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  int _requireUserId() {
    final int? userId = SessionManager.instance.currentUserId;

    if (userId == null) {
      throw Exception(
        'No hay una sesión activa.',
      );
    }

    return userId;
  }

  String _today() {
    final now = DateTime.now();

    final year = now.year.toString();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  Future<int> syncPendingSessions() async {
    final database = await _databaseHelper.database;
    final int userId = _requireUserId();

    final sessions = await database.query(
      DatabaseHelper.milkingSessionsTable,
      where: '''
      user_id = ?
      AND server_id IS NULL
      AND status = 'finalizado'
    ''',
      whereArgs: [userId],
      orderBy: 'date ASC, id ASC',
    );

    if (sessions.isEmpty) {
      debugPrint(
        'NO HAY SESIONES FINALIZADAS PENDIENTES',
      );
      return 0;
    }

    debugPrint(
      'SESIONES PENDIENTES: ${sessions.length}',
    );

    int synchronized = 0;

    for (final session in sessions) {
      final int localSessionId = (session['id'] as num).toInt();

      final int localGroupId = (session['group_id'] as num).toInt();

      final groupRows = await database.query(
        DatabaseHelper.milkingGroupsTable,
        columns: [
          'server_id',
        ],
        where: 'id = ? AND user_id = ?',
        whereArgs: [
          localGroupId,
          userId,
        ],
        limit: 1,
      );

      if (groupRows.isEmpty) {
        continue;
      }

      final int? serverGroupId =
          (groupRows.first['server_id'] as num?)?.toInt();

      if (serverGroupId == null) {
        debugPrint(
          'SESIÓN $localSessionId SIN GRUPO SINCRONIZADO',
        );
        continue;
      }

      try {
        final response = await ApiClient.instance.post(
          '/sesiones-ordenio/importar',
          body: {
            'grupo_ordenio_id': serverGroupId,
            'fecha': session['date']?.toString(),
            'hora_inicio': session['start_time']?.toString(),
            'hora_fin': session['end_time']?.toString(),
            'duracion_minutos': session['duration_minutes'],
            'cantidad_vacas': session['cattle_count'],
            'litros_totales': session['total_liters'],
            'estado': session['status'],
            'observaciones': session['observations']?.toString(),
          },
        );

        debugPrint(
          'SYNC SESIÓN $localSessionId STATUS: '
          '${response.statusCode}',
        );

        debugPrint(
          'SYNC SESIÓN BODY: ${response.body}',
        );

        if (response.statusCode == 201) {
          final dynamic decoded = jsonDecode(response.body);

          if (decoded is Map<String, dynamic>) {
            final dynamic data = decoded['data'];

            if (data is Map<String, dynamic>) {
              final int? serverSessionId = int.tryParse(
                data['id']?.toString() ?? '',
              );

              if (serverSessionId != null) {
                await database.update(
                  DatabaseHelper.milkingSessionsTable,
                  {
                    'server_id': serverSessionId,
                    'sync_status': 'synced',
                    'last_sync_error': null,
                    'updated_at': DateTime.now().toIso8601String(),
                  },
                  where: 'id = ?',
                  whereArgs: [
                    localSessionId,
                  ],
                );

                synchronized++;
              }
            }
          }
        }
      } catch (error) {
        debugPrint(
          'ERROR SINCRONIZANDO SESIÓN '
          '$localSessionId: $error',
        );
      }
    }

    debugPrint(
      'SESIONES SINCRONIZADAS: $synchronized',
    );

    return synchronized;
  }

  Future<List<MilkingSession>> startJourney() async {
    final database = await _databaseHelper.database;
    final int userId = _requireUserId();

    final String date = _today();
    final DateTime now = DateTime.now();

    // =========================================================
    // 1. CREAR JORNADA LOCALMENTE
    // =========================================================

    await database.transaction<List<MilkingSession>>(
      (transaction) async {
        final existingSessions = await transaction.query(
          DatabaseHelper.milkingSessionsTable,
          where: '''
          user_id = ?
          AND date = ?
        ''',
          whereArgs: [
            userId,
            date,
          ],
          limit: 1,
        );

        if (existingSessions.isNotEmpty) {
          throw Exception(
            'Ya existe una jornada de ordeña para hoy.',
          );
        }

        final groups = await transaction.query(
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

        if (groups.isEmpty) {
          throw Exception(
            'No hay grupos de ordeña activos.',
          );
        }

        final List<MilkingSession> sessions = [];

        for (int index = 0; index < groups.length; index++) {
          final group = groups[index];

          final int groupId = (group['id'] as num).toInt();

          final cattleRows = await transaction.query(
            DatabaseHelper.milkingGroupCattleTable,
            columns: [
              'cattle_id',
            ],
            where: 'group_id = ?',
            whereArgs: [
              groupId,
            ],
            orderBy: 'id ASC',
          );

          if (cattleRows.isEmpty) {
            throw Exception(
              'El grupo "${group['name']}" no tiene vacas asignadas.',
            );
          }

          final bool isFirstGroup = index == 0;

          final String status = isFirstGroup ? 'en_produccion' : 'en_espera';

          final String? startTime = isFirstGroup ? now.toIso8601String() : null;

          final String uuid = const Uuid().v4();

          final int sessionId = await transaction.insert(
            DatabaseHelper.milkingSessionsTable,
            {
              'uuid': uuid,
              'user_id': userId,
              'group_id': groupId,
              'date': date,
              'start_time': startTime,
              'end_time': null,
              'duration_minutes': null,
              'cattle_count': cattleRows.length,
              'total_liters': null,
              'status': status,
              'observations': '',
              'sync_status': 'pending',
              'created_at': now.toIso8601String(),
              'updated_at': null,
              'last_sync_error': null,
            },
          );

          for (final cattle in cattleRows) {
            await transaction.insert(
              DatabaseHelper.milkingSessionCattleTable,
              {
                'session_id': sessionId,
                'cattle_id': cattle['cattle_id'],
                'created_at': now.toIso8601String(),
              },
            );
          }

          final sessionRows = await transaction.query(
            DatabaseHelper.milkingSessionsTable,
            where: 'id = ?',
            whereArgs: [
              sessionId,
            ],
            limit: 1,
          );

          sessions.add(
            MilkingSession.fromMap(
              sessionRows.first,
            ),
          );
        }

        return sessions;
      },
    );

    // =========================================================
    // 2. INTENTAR SINCRONIZAR LA JORNADA CON LARAVEL
    // =========================================================

    try {
      final response = await ApiClient.instance.post(
        '/sesiones-ordenio/iniciar',
      );

      debugPrint(
        'INICIAR JORNADA API STATUS: ${response.statusCode}',
      );

      debugPrint(
        'INICIAR JORNADA API BODY: ${response.body}',
      );

      if (response.statusCode == 201) {
        final dynamic decoded = jsonDecode(
          response.body,
        );

        if (decoded is Map<String, dynamic>) {
          final dynamic data = decoded['data'];

          if (data is List) {
            for (final dynamic item in data) {
              if (item is! Map<String, dynamic>) {
                continue;
              }

              final int? serverSessionId = (item['id'] as num?)?.toInt();

              final int? serverGroupId =
                  (item['grupo_ordenio_id'] as num?)?.toInt();

              if (serverSessionId == null || serverGroupId == null) {
                continue;
              }

              final groupRows = await database.query(
                DatabaseHelper.milkingGroupsTable,
                columns: [
                  'id',
                ],
                where: 'server_id = ?',
                whereArgs: [
                  serverGroupId,
                ],
                limit: 1,
              );

              if (groupRows.isEmpty) {
                continue;
              }

              final int localGroupId = (groupRows.first['id'] as num).toInt();

              await database.update(
                DatabaseHelper.milkingSessionsTable,
                {
                  'server_id': serverSessionId,
                  'sync_status': 'synced',
                  'updated_at': DateTime.now().toIso8601String(),
                  'last_sync_error': null,
                },
                where: '''
                user_id = ?
                AND group_id = ?
                AND date = ?
              ''',
                whereArgs: [
                  userId,
                  localGroupId,
                  date,
                ],
              );
            }
          }
        }
      } else {
        await database.update(
          DatabaseHelper.milkingSessionsTable,
          {
            'sync_status': 'error',
            'last_sync_error':
                'Laravel respondió con código ${response.statusCode}.',
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: '''
          user_id = ?
          AND date = ?
        ''',
          whereArgs: [
            userId,
            date,
          ],
        );
      }
    } catch (error) {
      debugPrint(
        'ERROR SINCRONIZANDO JORNADA: $error',
      );

      await database.update(
        DatabaseHelper.milkingSessionsTable,
        {
          'sync_status': 'pending',
          'last_sync_error': error.toString(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: '''
        user_id = ?
        AND date = ?
      ''',
        whereArgs: [
          userId,
          date,
        ],
      );
    }

    // =========================================================
    // 3. DEVOLVER LAS SESIONES ACTUALIZADAS
    // =========================================================

    return getTodaySessions();
  }

  Future<List<MilkingSession>> getTodaySessions() async {
    final database = await _databaseHelper.database;
    final int userId = _requireUserId();
    final String date = _today();

    final rows = await database.query(
      DatabaseHelper.milkingSessionsTable,
      where: '''
      user_id = ?
      AND date = ?
    ''',
      whereArgs: [
        userId,
        date,
      ],
      orderBy: 'id ASC',
    );

    return rows
        .map(
          (row) => MilkingSession.fromMap(row),
        )
        .toList();
  }

  Future<int?> _getSessionServerId(
    int localSessionId,
  ) async {
    final database = await _databaseHelper.database;

    final rows = await database.query(
      DatabaseHelper.milkingSessionsTable,
      columns: ['server_id'],
      where: 'id = ?',
      whereArgs: [
        localSessionId,
      ],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return (rows.first['server_id'] as num?)?.toInt();
  }

  Future<void> finishSession({
    required int sessionId,
    required double totalLiters,
    String observations = '',
  }) async {
    if (totalLiters <= 0) {
      throw Exception(
        'Los litros producidos deben ser mayores a 0.',
      );
    }

    final database = await _databaseHelper.database;
    final int userId = _requireUserId();
    final DateTime now = DateTime.now();

    await database.transaction(
      (transaction) async {
        // 1. Obtener la sesión actual.
        final sessionRows = await transaction.query(
          DatabaseHelper.milkingSessionsTable,
          where: '''
          id = ?
          AND user_id = ?
        ''',
          whereArgs: [
            sessionId,
            userId,
          ],
          limit: 1,
        );

        if (sessionRows.isEmpty) {
          throw Exception(
            'No se encontró la sesión de ordeña.',
          );
        }

        final session = sessionRows.first;

        final String status = session['status']?.toString() ?? '';

        if (status != 'en_produccion') {
          throw Exception(
            'Solo se puede finalizar el grupo que está en producción.',
          );
        }

        final String? startTime = session['start_time']?.toString();

        if (startTime == null || startTime.isEmpty) {
          throw Exception(
            'La sesión no tiene hora de inicio.',
          );
        }

        final DateTime start = DateTime.parse(startTime);

        int durationMinutes = now.difference(start).inMinutes;

        if (durationMinutes < 1) {
          durationMinutes = 1;
        }

        // 2. Finalizar grupo actual.
        await transaction.update(
          DatabaseHelper.milkingSessionsTable,
          {
            'end_time': now.toIso8601String(),
            'duration_minutes': durationMinutes,
            'total_liters': totalLiters,
            'status': 'finalizado',
            'observations': observations.trim(),
            'sync_status': 'pending',
            'updated_at': now.toIso8601String(),
            'last_sync_error': null,
          },
          where: '''
          id = ?
          AND user_id = ?
        ''',
          whereArgs: [
            sessionId,
            userId,
          ],
        );

        final String date = session['date'].toString();

        // 3. Buscar el siguiente grupo en espera.
        final nextRows = await transaction.rawQuery(
          '''
        SELECT ms.id
        FROM ${DatabaseHelper.milkingSessionsTable} ms

        INNER JOIN ${DatabaseHelper.milkingGroupsTable} mg
          ON mg.id = ms.group_id

        WHERE ms.user_id = ?
          AND ms.date = ?
          AND ms.status = 'en_espera'

        ORDER BY mg.sort_order ASC

        LIMIT 1
        ''',
          [
            userId,
            date,
          ],
        );

        // 4. Si existe otro grupo, iniciar automáticamente.
        if (nextRows.isNotEmpty) {
          final int nextSessionId = (nextRows.first['id'] as num).toInt();

          await transaction.update(
            DatabaseHelper.milkingSessionsTable,
            {
              'status': 'en_produccion',
              'start_time': now.toIso8601String(),
              'sync_status': 'pending',
              'updated_at': now.toIso8601String(),
              'last_sync_error': null,
            },
            where: '''
            id = ?
            AND user_id = ?
          ''',
            whereArgs: [
              nextSessionId,
              userId,
            ],
          );
        }
      },
    );

    // =========================================================
// 5. INTENTAR SINCRONIZAR FINALIZACIÓN CON LARAVEL
// =========================================================

    try {
      final int? serverSessionId = await _getSessionServerId(sessionId);

      if (serverSessionId == null) {
        debugPrint(
          'FINALIZACIÓN PENDIENTE: sesión sin server_id.',
        );

        return;
      }

      final response = await ApiClient.instance.patch(
        '/sesiones-ordenio/$serverSessionId/finalizar',
        body: {
          'litros_totales': totalLiters,
          'observaciones': observations.trim(),
        },
      );

      debugPrint(
        'FINALIZAR SESIÓN API STATUS: ${response.statusCode}',
      );

      debugPrint(
        'FINALIZAR SESIÓN API BODY: ${response.body}',
      );

      if (response.statusCode == 200) {
        await database.update(
          DatabaseHelper.milkingSessionsTable,
          {
            'sync_status': 'synced',
            'last_sync_error': null,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [
            sessionId,
          ],
        );

        return;
      }

      String message = 'No se pudo sincronizar la finalización. '
          'Código ${response.statusCode}.';

      try {
        final dynamic decoded = jsonDecode(response.body);

        if (decoded is Map<String, dynamic>) {
          final dynamic serverMessage = decoded['message'];

          if (serverMessage != null &&
              serverMessage.toString().trim().isNotEmpty) {
            message = serverMessage.toString();
          }
        }
      } catch (_) {
        // Se conserva el mensaje predeterminado.
      }

      await database.update(
        DatabaseHelper.milkingSessionsTable,
        {
          'sync_status': 'error',
          'last_sync_error': message,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [
          sessionId,
        ],
      );
    } catch (error) {
      debugPrint(
        'ERROR SINCRONIZANDO FINALIZACIÓN: $error',
      );

      await database.update(
        DatabaseHelper.milkingSessionsTable,
        {
          'sync_status': 'pending',
          'last_sync_error': error.toString(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [
          sessionId,
        ],
      );
    }
  }

  Future<List<Map<String, dynamic>>> getHistorySessions() async {
    debugPrint(
      'ENTRÓ A getHistorySessions',
    );
    final database = await _databaseHelper.database;
    final int userId = _requireUserId();

    // =========================================================
    // 1. INTENTAR OBTENER HISTORIAL DESDE LARAVEL
    // =========================================================

    try {
      final response = await ApiClient.instance.get(
        '/sesiones-ordenio/historial',
      );

      debugPrint(
        'HISTORIAL API STATUS: ${response.statusCode}',
      );

      debugPrint(
        'HISTORIAL API BODY: ${response.body}',
      );

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(
          response.body,
        );

        if (decoded is Map<String, dynamic>) {
          final dynamic data = decoded['data'];

          if (data is List) {
            for (final dynamic item in data) {
              if (item is! Map<String, dynamic>) {
                continue;
              }

              final int? serverSessionId = (item['id'] as num?)?.toInt();

              final int? serverGroupId =
                  (item['grupo_ordenio_id'] as num?)?.toInt();

              if (serverSessionId == null || serverGroupId == null) {
                continue;
              }

              final groupRows = await database.query(
                DatabaseHelper.milkingGroupsTable,
                columns: [
                  'id',
                ],
                where: 'server_id = ?',
                whereArgs: [
                  serverGroupId,
                ],
                limit: 1,
              );

              if (groupRows.isEmpty) {
                continue;
              }

              final int localGroupId = (groupRows.first['id'] as num).toInt();

              final existing = await database.query(
                DatabaseHelper.milkingSessionsTable,
                columns: [
                  'id',
                ],
                where: 'server_id = ?',
                whereArgs: [
                  serverSessionId,
                ],
                limit: 1,
              );

              final Map<String, dynamic> localData = {
                'server_id': serverSessionId,
                'user_id': userId,
                'group_id': localGroupId,
                'date': item['fecha']?.toString(),
                'start_time': item['hora_inicio']?.toString(),
                'end_time': item['hora_fin']?.toString(),
                'duration_minutes': int.tryParse(
                  item['duracion_minutos']?.toString() ?? '',
                ),
                'cattle_count': int.tryParse(
                      item['cantidad_vacas']?.toString() ?? '',
                    ) ??
                    0,
                'total_liters': double.tryParse(
                  item['litros_totales']?.toString() ?? '',
                ),
                'status': item['estado']?.toString() ?? 'finalizado',
                'observations': item['observaciones']?.toString() ?? '',
                'sync_status': 'synced',
                'updated_at': DateTime.now().toIso8601String(),
                'last_sync_error': null,
              };

              if (existing.isEmpty) {
                localData['uuid'] =
                    item['uuid']?.toString() ?? const Uuid().v4();

                localData['created_at'] = item['created_at']?.toString() ??
                    DateTime.now().toIso8601String();

                await database.insert(
                  DatabaseHelper.milkingSessionsTable,
                  localData,
                );
              } else {
                final int localSessionId =
                    (existing.first['id'] as num).toInt();

                await database.update(
                  DatabaseHelper.milkingSessionsTable,
                  localData,
                  where: 'id = ?',
                  whereArgs: [
                    localSessionId,
                  ],
                );
              }
            }
          }
        }
      }
    } catch (error) {
      debugPrint(
        'ERROR CARGANDO HISTORIAL DESDE API: $error',
      );

      // Si Laravel no está disponible,
      // se utiliza el historial local.
    }

    // =========================================================
    // 2. DEVOLVER HISTORIAL DESDE SQLITE
    // =========================================================

    final rows = await database.rawQuery(
      '''
    SELECT
      ms.*,
      mg.name AS group_name,
      mg.sort_order AS group_sort_order
    FROM ${DatabaseHelper.milkingSessionsTable} ms

    INNER JOIN ${DatabaseHelper.milkingGroupsTable} mg
      ON mg.id = ms.group_id

    WHERE ms.user_id = ?
      AND ms.status = 'finalizado'

    ORDER BY
      ms.date DESC,
      mg.sort_order ASC
    ''',
      [
        userId,
      ],
    );

    return rows;
  }
}
