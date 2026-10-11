import '../../../../core/database/database_helper.dart';
import '../../../../core/session/session_manager.dart';
import '../models/milking_record.dart';
import 'dart:convert';
import 'dart:math';
import '../../../../core/network/api_client.dart';

class MilkingRepository {
  MilkingRepository({
    DatabaseHelper? databaseHelper,
  }) : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;

  // =========================================================
  // USUARIO ACTUAL
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

  String _generateUuid() {
    final Random random = Random.secure();

    final List<int> bytes = List<int>.generate(
      16,
      (_) => random.nextInt(256),
    );

    // UUID versión 4.
    bytes[6] = (bytes[6] & 0x0F) | 0x40;

    // Variante RFC 4122.
    bytes[8] = (bytes[8] & 0x3F) | 0x80;

    String hex(int value) {
      return value.toRadixString(16).padLeft(2, '0');
    }

    return '${hex(bytes[0])}${hex(bytes[1])}${hex(bytes[2])}${hex(bytes[3])}-'
        '${hex(bytes[4])}${hex(bytes[5])}-'
        '${hex(bytes[6])}${hex(bytes[7])}-'
        '${hex(bytes[8])}${hex(bytes[9])}-'
        '${hex(bytes[10])}${hex(bytes[11])}${hex(bytes[12])}'
        '${hex(bytes[13])}${hex(bytes[14])}${hex(bytes[15])}';
  }

  Future<bool> _syncMilkingByLocalId(
    int localMilkingId,
  ) async {
    final database = await _databaseHelper.database;
    final int userId = await _requireUserId();

    final List<Map<String, dynamic>> rows = await database.rawQuery(
      '''
    SELECT
      m.*,
      c.server_id AS cattle_server_id,
      l.server_id AS lot_server_id
    FROM ${DatabaseHelper.milkingRecordsTable} m
    INNER JOIN ${DatabaseHelper.cattleTable} c
      ON c.id = m.cattle_id
    LEFT JOIN ${DatabaseHelper.lotsTable} l
      ON l.id = m.historical_lot_id
    WHERE m.id = ?
      AND m.user_id = ?
    LIMIT 1
    ''',
      [
        localMilkingId,
        userId,
      ],
    );

    if (rows.isEmpty) {
      return false;
    }

    final Map<String, dynamic> row = rows.first;

    final String? uuid = row['uuid']?.toString();

    // Los registros antiguos sin UUID no se suben automáticamente,
    // para evitar duplicarlos en Laravel.
    if (uuid == null || uuid.trim().isEmpty) {
      return false;
    }

    final int? cattleServerId = (row['cattle_server_id'] as num?)?.toInt();

    final int? lotServerId = (row['lot_server_id'] as num?)?.toInt();

    // Primero deben estar sincronizados el animal y su lote.
    if (cattleServerId == null || lotServerId == null) {
      return false;
    }

    final Map<String, dynamic> body = {
      'uuid': uuid,
      'ganado_id': cattleServerId,
      'lote_historico_id': lotServerId,
      'fecha': row['date'].toString(),
      'litros': (row['liters'] as num).toDouble(),
    };

    final String? shift = row['shift']?.toString();

    if (shift != null && shift.trim().isNotEmpty) {
      body['turno'] = shift;
    }

    final String observations = row['observations']?.toString() ?? '';

    if (observations.trim().isNotEmpty) {
      body['observaciones'] = observations;
    }

    try {
      final response = await ApiClient.instance.post(
        '/ordenios',
        body: body,
      );

      // 201 = creado.
      // 200 = UUID ya existía y Laravel devolvió el mismo registro.
      if (response.statusCode == 200 || response.statusCode == 201) {
        final dynamic decoded = jsonDecode(
          response.body,
        );

        if (decoded is Map<String, dynamic>) {
          final dynamic apiData = decoded['data'];

          if (apiData is Map<String, dynamic>) {
            final int? serverId = int.tryParse(
              apiData['id']?.toString() ?? '',
            );

            final int? serverMilkingNumber = int.tryParse(
              apiData['numero_ordenio']?.toString() ?? '',
            );

            final Map<String, dynamic> updateData = {
              'server_id': serverId,
              'sync_status': 'synced',
              'updated_at': DateTime.now().toIso8601String(),
              'last_sync_error': null,
            };

            // Laravel es quien tiene el número definitivo.
            if (serverMilkingNumber != null) {
              updateData['milking_number'] = serverMilkingNumber;
            }

            await database.update(
              DatabaseHelper.milkingRecordsTable,
              updateData,
              where: 'id = ? AND user_id = ?',
              whereArgs: [
                localMilkingId,
                userId,
              ],
            );

            return true;
          }
        }

        return false;
      }

      // Errores de validación/permisos:
      // guardamos el error para poder identificarlo.
      if (response.statusCode == 403 ||
          response.statusCode == 404 ||
          response.statusCode == 422) {
        await database.update(
          DatabaseHelper.milkingRecordsTable,
          {
            'sync_status': 'error',
            'updated_at': DateTime.now().toIso8601String(),
            'last_sync_error': _extractApiError(
              response.body,
              'No fue posible sincronizar el ordeño.',
            ),
          },
          where: 'id = ? AND user_id = ?',
          whereArgs: [
            localMilkingId,
            userId,
          ],
        );
      }

      // 401, 500, etc.:
      // conservamos el registro local.
      return false;
    } catch (_) {
      // Sin Internet, timeout o servidor apagado.
      // El registro permanece pending.
      return false;
    }
  }

  Future<void> syncPendingMilkings() async {
    final database = await _databaseHelper.database;
    final int userId = await _requireUserId();

    final List<Map<String, dynamic>> pending = await database.query(
      DatabaseHelper.milkingRecordsTable,
      columns: [
        'id',
      ],
      where: '''
      user_id = ?
      AND sync_status = ?
      AND uuid IS NOT NULL
    ''',
      whereArgs: [
        userId,
        'pending',
      ],
      orderBy: 'date ASC, milking_number ASC, id ASC',
    );

    for (final Map<String, dynamic> row in pending) {
      final int? id = (row['id'] as num?)?.toInt();

      if (id == null) {
        continue;
      }

      await _syncMilkingByLocalId(
        id,
      );
    }
  }

  Future<void> syncMilkings() async {
    try {
      await syncPendingMilkings();
    } catch (_) {
      // Si no hay conexión o Laravel está apagado,
      // la aplicación continúa trabajando con SQLite.
    }
  }

  Future<List<Map<String, dynamic>>> _getApiMilkings() async {
    final database = await _databaseHelper.database;
    final int userId = await _requireUserId();
    // Intenta enviar los ordeños pendientes.
    // Si no hay servidor, continúa usando SQLite.
    await syncMilkings();

    final List<Map<String, dynamic>> rows = await database.query(
      DatabaseHelper.milkingRecordsTable,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'date DESC, milking_number DESC',
    );

    // Conservamos los nombres que ya utilizan los métodos
    // existentes del repositorio para no tener que reescribir
    // todos los cálculos de producción.
    return rows.map((row) {
      return <String, dynamic>{
        'id': row['id'],
        'uuid': row['uuid'],

        // IMPORTANTE:
        // estos son IDs LOCALES porque los cálculos de Flutter
        // trabajan contra SQLite.
        'ganado_id': row['cattle_id'],
        'lote_historico_id': row['historical_lot_id'],

        'fecha': row['date'],
        'numero_ordenio': row['milking_number'],
        'turno': row['shift'],
        'litros': row['liters'],
        'observaciones': row['observations'],
        'created_at': row['created_at'],

        'server_id': row['server_id'],
        'sync_status': row['sync_status'],
        'updated_at': row['updated_at'],
        'last_sync_error': row['last_sync_error'],
      };
    }).toList();
  }

  Future<List<MilkingRecord>> getRecentMilkingsByCattle({
    required int cattleId,
    int limit = 10,
  }) async {
    final List<Map<String, dynamic>> milkings = await _getApiMilkings();

    final List<MilkingRecord> result = [];
    final int userId = await _requireUserId();

    for (final Map<String, dynamic> milking in milkings) {
      final int? milkingCattleId = _toInt(
        milking['ganado_id'],
      );

      if (milkingCattleId != cattleId) {
        continue;
      }

      result.add(
        MilkingRecord.fromMap(
          {
            'id': milking['id'],
            'uuid': milking['uuid'],
            'server_id': milking['server_id'],
            'user_id': userId,
            'cattle_id': milking['ganado_id'],
            'historical_lot_id': milking['lote_historico_id'],
            'date': milking['fecha'],
            'milking_number': milking['numero_ordenio'],
            'shift': milking['turno'],
            'liters': milking['litros'],
            'observations': milking['observaciones'],
            'created_at': milking['created_at'],
            'sync_status': milking['sync_status'] ?? 'pending',
            'updated_at': milking['updated_at'],
            'last_sync_error': milking['last_sync_error'],
          },
        ),
      );
    }

    result.sort(
      (MilkingRecord a, MilkingRecord b) {
        final int dateComparison = b.date.compareTo(a.date);

        if (dateComparison != 0) {
          return dateComparison;
        }

        return b.milkingNumber.compareTo(
          a.milkingNumber,
        );
      },
    );

    if (result.length > limit) {
      return result.take(limit).toList();
    }

    return result;
  }
  // =========================================================
  // REGISTRAR ORDEÑA
  // =========================================================

  // =========================================================
  // REGISTRAR ORDEÑA EN API REST
  // =========================================================

  Future<int> insertMilking({
    required int cattleId,
    required DateTime date,
    required double liters,
    String? shift,
    String? observations,
  }) async {
    if (liters <= 0) {
      throw Exception(
        'La cantidad de litros debe ser mayor a 0.',
      );
    }

    final database = await _databaseHelper.database;
    final int userId = await _requireUserId();

    final String formattedDate = _formatDate(
      date,
    );

    final int localId = await database.transaction<int>(
      (transaction) async {
        // -------------------------------------------------------
        // BUSCAR EL ANIMAL LOCAL
        // -------------------------------------------------------

        final List<Map<String, dynamic>> cattleRows = await transaction.query(
          DatabaseHelper.cattleTable,
          columns: [
            'id',
            'lot_id',
            'sex',
            'status',
          ],
          where: 'id = ? AND user_id = ?',
          whereArgs: [
            cattleId,
            userId,
          ],
          limit: 1,
        );

        if (cattleRows.isEmpty) {
          throw Exception(
            'No se encontró el animal seleccionado.',
          );
        }

        final Map<String, dynamic> animal = cattleRows.first;

        final int? historicalLotId = (animal['lot_id'] as num?)?.toInt();

        if (historicalLotId == null) {
          throw Exception(
            'El animal no tiene un lote asignado.',
          );
        }

        if (animal['status']?.toString() != 'Activo') {
          throw Exception(
            'Solo puedes registrar ordeños de ganado activo.',
          );
        }

        if (animal['sex']?.toString() != 'Hembra') {
          throw Exception(
            'Solo puedes registrar ordeños de hembras.',
          );
        }

        // -------------------------------------------------------
        // NÚMERO LOCAL DEL ORDEÑO
        // -------------------------------------------------------

        final List<Map<String, dynamic>> result = await transaction.rawQuery(
          '''
        SELECT MAX(milking_number) AS max_number
        FROM ${DatabaseHelper.milkingRecordsTable}
        WHERE user_id = ?
          AND cattle_id = ?
          AND date = ?
        ''',
          [
            userId,
            cattleId,
            formattedDate,
          ],
        );

        final int currentMax =
            (result.first['max_number'] as num?)?.toInt() ?? 0;

        final int milkingNumber = currentMax + 1;

        if (milkingNumber > 20) {
          throw Exception(
            'No se pueden registrar más de 20 ordeños '
            'para este animal en la misma fecha.',
          );
        }

        final DateTime now = DateTime.now();

        final String uuid = _generateUuid();

        // -------------------------------------------------------
        // GUARDAR PRIMERO EN SQLITE
        // -------------------------------------------------------

        return transaction.insert(
          DatabaseHelper.milkingRecordsTable,
          {
            'uuid': uuid,
            'user_id': userId,
            'cattle_id': cattleId,
            'historical_lot_id': historicalLotId,
            'date': formattedDate,
            'milking_number': milkingNumber,
            'shift': shift,
            'liters': liters,
            'observations': observations?.trim() ?? '',
            'created_at': now.toIso8601String(),
            'server_id': null,
            'sync_status': 'pending',
            'updated_at': now.toIso8601String(),
            'last_sync_error': null,
          },
        );
      },
    );

    // ---------------------------------------------------------
    // INTENTAR SINCRONIZAR.
    //
    // Si no hay conexión, NO eliminamos el registro.
    // Ya quedó guardado correctamente en SQLite.
    // ---------------------------------------------------------

    await _syncMilkingByLocalId(
      localId,
    );

    return localId;
  }

  // =========================================================
  // OBTENER ORDEÑAS DE UNA FECHA
  // =========================================================

  Future<List<MilkingRecord>> getMilkingsByDate(
    DateTime date,
  ) async {
    final List<Map<String, dynamic>> milkings = await _getApiMilkings();

    final List<MilkingRecord> result = [];
    final int userId = await _requireUserId();

    for (final Map<String, dynamic> milking in milkings) {
      final DateTime? milkingDate = DateTime.tryParse(
        milking['fecha']?.toString() ?? '',
      );

      if (milkingDate == null) {
        continue;
      }

      final bool sameDate = milkingDate.year == date.year &&
          milkingDate.month == date.month &&
          milkingDate.day == date.day;

      if (!sameDate) {
        continue;
      }

      result.add(
        MilkingRecord.fromMap(
          {
            'id': milking['id'],
            'uuid': milking['uuid'],
            'server_id': milking['server_id'],
            'user_id': userId,
            'cattle_id': milking['ganado_id'],
            'historical_lot_id': milking['lote_historico_id'],
            'date': milking['fecha'],
            'milking_number': milking['numero_ordenio'],
            'shift': milking['turno'],
            'liters': milking['litros'],
            'observations': milking['observaciones'],
            'created_at': milking['created_at'],
            'sync_status': milking['sync_status'] ?? 'pending',
            'updated_at': milking['updated_at'],
            'last_sync_error': milking['last_sync_error'],
          },
        ),
      );
    }

    result.sort(
      (MilkingRecord a, MilkingRecord b) {
        final int cattleComparison = a.cattleId.compareTo(b.cattleId);

        if (cattleComparison != 0) {
          return cattleComparison;
        }

        return a.milkingNumber.compareTo(
          b.milkingNumber,
        );
      },
    );

    return result;
  }

  // =========================================================
  // ORDEÑAS DE UNA VACA EN UNA FECHA
  // =========================================================

  Future<List<MilkingRecord>> getMilkingsByCattleAndDate({
    required int cattleId,
    required DateTime date,
  }) async {
    final List<Map<String, dynamic>> milkings = await _getApiMilkings();

    final List<MilkingRecord> result = [];
    final int userId = await _requireUserId();

    for (final Map<String, dynamic> milking in milkings) {
      final int? milkingCattleId = _toInt(
        milking['ganado_id'],
      );

      if (milkingCattleId != cattleId) {
        continue;
      }

      final DateTime? milkingDate = DateTime.tryParse(
        milking['fecha']?.toString() ?? '',
      );

      if (milkingDate == null) {
        continue;
      }

      final bool sameDate = milkingDate.year == date.year &&
          milkingDate.month == date.month &&
          milkingDate.day == date.day;

      if (!sameDate) {
        continue;
      }

      result.add(
        MilkingRecord.fromMap(
          {
            'id': milking['id'],
            'uuid': milking['uuid'],
            'server_id': milking['server_id'],
            'user_id': userId,
            'cattle_id': milking['ganado_id'],
            'historical_lot_id': milking['lote_historico_id'],
            'date': milking['fecha'],
            'milking_number': milking['numero_ordenio'],
            'shift': milking['turno'],
            'liters': milking['litros'],
            'observations': milking['observaciones'],
            'created_at': milking['created_at'],
            'sync_status': milking['sync_status'] ?? 'pending',
            'updated_at': milking['updated_at'],
            'last_sync_error': milking['last_sync_error'],
          },
        ),
      );
    }

    result.sort(
      (MilkingRecord a, MilkingRecord b) {
        return a.milkingNumber.compareTo(
          b.milkingNumber,
        );
      },
    );

    return result;
  }

  // =========================================================
  // PRODUCCIÓN TOTAL DE UN DÍA
  // =========================================================

  Future<double> getDailyProduction(
    DateTime date,
  ) async {
    final List<Map<String, dynamic>> milkings = await _getApiMilkings();

    double total = 0.0;

    for (final Map<String, dynamic> milking in milkings) {
      final DateTime? milkingDate = DateTime.tryParse(
        milking['fecha']?.toString() ?? '',
      );

      if (milkingDate == null) {
        continue;
      }

      final bool sameDate = milkingDate.year == date.year &&
          milkingDate.month == date.month &&
          milkingDate.day == date.day;

      if (!sameDate) {
        continue;
      }

      total += _toDouble(
        milking['litros'],
      );
    }

    return total;
  }

  // =========================================================
  // PRODUCCIÓN DE UNA VACA EN UN DÍA
  // =========================================================

  Future<double> getDailyProductionByCattle({
    required int cattleId,
    required DateTime date,
  }) async {
    final List<Map<String, dynamic>> milkings = await _getApiMilkings();

    double total = 0.0;

    for (final Map<String, dynamic> milking in milkings) {
      final int? milkingCattleId = _toInt(
        milking['ganado_id'],
      );

      if (milkingCattleId != cattleId) {
        continue;
      }

      final DateTime? milkingDate = DateTime.tryParse(
        milking['fecha']?.toString() ?? '',
      );

      if (milkingDate == null) {
        continue;
      }

      final bool sameDate = milkingDate.year == date.year &&
          milkingDate.month == date.month &&
          milkingDate.day == date.day;

      if (!sameDate) {
        continue;
      }

      total += _toDouble(
        milking['litros'],
      );
    }

    return total;
  }

  // =========================================================
  // PRODUCCIÓN DE UN LOTE EN UN DÍA
  // =========================================================

  Future<double> getDailyProductionByLot({
    required int lotId,
    required DateTime date,
  }) async {
    final List<Map<String, dynamic>> milkings = await _getApiMilkings();

    double total = 0.0;

    for (final Map<String, dynamic> milking in milkings) {
      final int? historicalLotId = _toInt(milking['lote_historico_id']);

      if (historicalLotId != lotId) {
        continue;
      }

      final DateTime? milkingDate = DateTime.tryParse(
        milking['fecha']?.toString() ?? '',
      );

      if (milkingDate == null) {
        continue;
      }

      final bool sameDate = milkingDate.year == date.year &&
          milkingDate.month == date.month &&
          milkingDate.day == date.day;

      if (!sameDate) {
        continue;
      }

      total += _toDouble(
        milking['litros'],
      );
    }

    return total;
  }

  // =========================================================
  // PRODUCCIÓN TOTAL DEL MES
  // =========================================================

  Future<double> getMonthlyProduction(
    DateTime month,
  ) async {
    final List<Map<String, dynamic>> milkings = await _getApiMilkings();

    double total = 0.0;

    for (final Map<String, dynamic> milking in milkings) {
      final DateTime? date = DateTime.tryParse(
        milking['fecha']?.toString() ?? '',
      );

      if (date == null) {
        continue;
      }

      if (date.year != month.year || date.month != month.month) {
        continue;
      }

      total += _toDouble(
        milking['litros'],
      );
    }

    return total;
  }

  // =========================================================
  // PRODUCCIÓN MENSUAL POR VACA
  // =========================================================

  Future<double> getMonthlyProductionByCattle({
    required int cattleId,
    required DateTime month,
  }) async {
    final List<Map<String, dynamic>> milkings = await _getApiMilkings();

    double total = 0.0;

    for (final Map<String, dynamic> milking in milkings) {
      final int? milkingCattleId = _toInt(
        milking['ganado_id'],
      );

      if (milkingCattleId != cattleId) {
        continue;
      }

      final DateTime? date = DateTime.tryParse(
        milking['fecha']?.toString() ?? '',
      );

      if (date == null) {
        continue;
      }

      if (date.year != month.year || date.month != month.month) {
        continue;
      }

      total += _toDouble(
        milking['litros'],
      );
    }

    return total;
  }

  // =========================================================
  // PRODUCCIÓN MENSUAL POR LOTE
  // =========================================================

  Future<double> getMonthlyProductionByLot({
    required int lotId,
    required DateTime month,
  }) async {
    final List<Map<String, dynamic>> milkings = await _getApiMilkings();

    double total = 0.0;

    for (final Map<String, dynamic> milking in milkings) {
      final int? historicalLotId = _toInt(milking['lote_historico_id']);

      if (historicalLotId != lotId) {
        continue;
      }

      final DateTime? milkingDate = DateTime.tryParse(
        milking['fecha']?.toString() ?? '',
      );

      if (milkingDate == null) {
        continue;
      }

      if (milkingDate.year != month.year || milkingDate.month != month.month) {
        continue;
      }

      total += _toDouble(
        milking['litros'],
      );
    }

    return total;
  }

  Future<Map<int, double>> getDailyProductionForCattleInMonth({
    required int cattleId,
    required DateTime month,
  }) async {
    final List<Map<String, dynamic>> milkings = await _getApiMilkings();

    final Map<int, double> productionByDay = {};

    for (final Map<String, dynamic> milking in milkings) {
      final int? milkingCattleId = _toInt(
        milking['ganado_id'],
      );

      if (milkingCattleId != cattleId) {
        continue;
      }

      final DateTime? date = DateTime.tryParse(
        milking['fecha']?.toString() ?? '',
      );

      if (date == null) {
        continue;
      }

      if (date.year != month.year || date.month != month.month) {
        continue;
      }

      final double liters = _toDouble(
        milking['litros'],
      );

      productionByDay[date.day] = (productionByDay[date.day] ?? 0.0) + liters;
    }

    return productionByDay;
  }
  // =========================================================
  // ELIMINAR ORDEÑA
  // =========================================================

  Future<int> deleteMilking(
    int milkingId,
  ) async {
    final response = await ApiClient.instance.delete(
      '/ordenios/$milkingId',
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
        'No tienes permiso para eliminar esta ordeña.',
      );
    }

    if (response.statusCode == 404) {
      throw Exception(
        'La ordeña ya no existe o no fue encontrada.',
      );
    }

    String message =
        'No fue posible eliminar la ordeña (${response.statusCode}).';

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
      // Conserva el mensaje predeterminado.
    }

    throw Exception(message);
  }

  Future<Map<int, double>> getDailyProductionForMonth(
    DateTime month,
  ) async {
    final List<Map<String, dynamic>> milkings = await _getApiMilkings();

    final Map<int, double> productionByDay = {};

    for (final Map<String, dynamic> milking in milkings) {
      final DateTime? date = DateTime.tryParse(
        milking['fecha']?.toString() ?? '',
      );

      if (date == null) {
        continue;
      }

      if (date.year != month.year || date.month != month.month) {
        continue;
      }

      final double liters = _toDouble(
        milking['litros'],
      );

      productionByDay[date.day] = (productionByDay[date.day] ?? 0.0) + liters;
    }

    return productionByDay;
  }

  // =========================================================
  // FORMATO DE FECHA PARA SQLITE
  // =========================================================
  Future<Map<String, double>> getMonthlyProductionByLots(
    DateTime month,
  ) async {
    final List<Map<String, dynamic>> milkings = await _getApiMilkings();

    final Map<String, double> productionByLot = {};

    for (final Map<String, dynamic> milking in milkings) {
      final DateTime? date = DateTime.tryParse(
        milking['fecha']?.toString() ?? '',
      );

      if (date == null) {
        continue;
      }

      if (date.year != month.year || date.month != month.month) {
        continue;
      }

      final dynamic lotData = milking['lote_historico'];

      String lotName = 'Sin lote';

      if (lotData is Map<String, dynamic>) {
        final String name = lotData['nombre']?.toString().trim() ?? '';

        if (name.isNotEmpty) {
          lotName = name;
        }
      }

      final double liters = _toDouble(
        milking['litros'],
      );

      productionByLot[lotName] = (productionByLot[lotName] ?? 0.0) + liters;
    }

    return productionByLot;
  }

  String _formatDate(
    DateTime date,
  ) {
    final String year = date.year.toString();

    final String month = date.month.toString().padLeft(2, '0');

    final String day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

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

  double _toDouble(
    dynamic value,
  ) {
    if (value == null) {
      return 0.0;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value.toString(),
        ) ??
        0.0;
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
      // Si Laravel no devuelve JSON válido,
      // se utiliza el mensaje predeterminado.
    }

    return fallback;
  }
}
