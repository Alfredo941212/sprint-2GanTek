import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  DatabaseHelper._internal();

  static final DatabaseHelper instance = DatabaseHelper._internal();

  static Database? _database;

  static const String databaseName = 'gantek.db';

  // =========================================================
  // VERSIÓN DE BASE DE DATOS
  // =========================================================

  // Versión 8:
  // Inicio de migración de GanTek hacia producción lechera.
  static const int databaseVersion = 14;

  // =========================================================
  // TABLAS
  // =========================================================

  static const String usersTable = 'users';

  // Nueva tabla.
  static const String lotsTable = 'lots';

  static const String cattleTable = 'cattle';

  // Tablas antiguas. Se mantienen temporalmente.

  static const String vaccinesTable = 'vaccine_records';

  // Nuevas tablas para sanidad.
  static const String vaccineCatalogTable = 'vaccines';
  static const String veterinariansTable = 'veterinarians';
  static const String vaccinationsTable = 'vaccinations';

  // Nueva tabla para producción lechera.
  static const String milkingRecordsTable = 'milking_records';
// Nueva estructura de ordeña por grupos.
static const String milkingGroupsTable = 'milking_groups';
static const String milkingGroupCattleTable = 'milking_group_cattle';
static const String milkingSessionsTable = 'milking_sessions';
static const String milkingSessionCattleTable = 'milking_session_cattle';
  // =========================================================
  // OBTENER BASE DE DATOS
  // =========================================================

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initializeDatabase();

    return _database!;
  }

  // =========================================================
  // INICIALIZAR BASE
  // =========================================================

  Future<Database> _initializeDatabase() async {
    late final String databasePath;

    if (kIsWeb) {
      databasePath = databaseName;
    } else {
      final String directory = await getDatabasesPath();

      databasePath = join(
        directory,
        databaseName,
      );
    }

    return openDatabase(
      databasePath,
      version: databaseVersion,
      onConfigure: (Database database) async {
        await database.execute(
          'PRAGMA foreign_keys = ON',
        );
      },
      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
    );
  }

  // =========================================================
  // CREAR BASE COMPLETA
  // =========================================================

  Future<void> _createDatabase(
    Database database,
    int version,
  ) async {
    await _createUsersTable(database);

    await _createLotsTable(database);

    await _createCattleTable(database);

    await _createLegacyVaccineRecordsTable(database);

    // ---------------------------------------------------------
    // NUEVA ESTRUCTURA
    // ---------------------------------------------------------

    await _createVeterinariansTable(database);

    await _createVaccineCatalogTable(database);

    await _createVaccinationsTable(database);

    await _createMilkingRecordsTable(database);

    await _createMilkingGroupsTable(database);

    await _createMilkingGroupCattleTable(database);

    await _createMilkingSessionsTable(database);

    await _createMilkingSessionCattleTable(database);
  }

  // =========================================================
  // USUARIOS
  // =========================================================

  Future<void> _createUsersTable(
    DatabaseExecutor database,
  ) async {
    await database.execute('''
      CREATE TABLE IF NOT EXISTS $usersTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,

        full_name TEXT NOT NULL,

        email TEXT NOT NULL UNIQUE,

        phone TEXT NOT NULL DEFAULT '',

        password_hash TEXT NOT NULL,

        role TEXT NOT NULL DEFAULT 'ganadero',

        created_at TEXT NOT NULL
      )
    ''');
  }

  // =========================================================
  // LOTES
  // =========================================================

  Future<void> _createLotsTable(
    DatabaseExecutor database,
  ) async {
    await database.execute('''
      CREATE TABLE IF NOT EXISTS $lotsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,

        server_id INTEGER UNIQUE,

        sync_status TEXT NOT NULL DEFAULT 'pending'
          CHECK (
            sync_status IN (
              'pending',
              'synced',
              'error'
            )
          ),

        updated_at TEXT,

        last_sync_error TEXT,

        user_id INTEGER NOT NULL,

        farm_id INTEGER,

        name TEXT NOT NULL,

        description TEXT NOT NULL DEFAULT '',

        minimum_production_per_cow REAL
          NOT NULL DEFAULT 4.0
          CHECK (minimum_production_per_cow >= 0),

        status TEXT NOT NULL DEFAULT 'Activo'
          CHECK (status IN ('Activo', 'Inactivo')),

        created_at TEXT NOT NULL,

        FOREIGN KEY (user_id)
          REFERENCES $usersTable(id)
          ON DELETE CASCADE,

        UNIQUE(user_id, name)
      )
    ''');
  }

  // =========================================================
  // GANADO
  // =========================================================

  Future<void> _createCattleTable(
    DatabaseExecutor database,
  ) async {
    await database.execute('''
      CREATE TABLE IF NOT EXISTS $cattleTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,

        server_id INTEGER UNIQUE,

        sync_status TEXT NOT NULL DEFAULT 'pending'
          CHECK (
            sync_status IN (
              'pending',
              'synced',
              'error'
            )
          ),

        updated_at TEXT,

        last_sync_error TEXT,

        user_id INTEGER NOT NULL,

        lot_id INTEGER,

        code TEXT NOT NULL,

        name TEXT NOT NULL DEFAULT '',

        sex TEXT NOT NULL DEFAULT 'Hembra'
          CHECK (sex IN ('Hembra', 'Macho')),

        breed TEXT NOT NULL DEFAULT '',

        birth_date TEXT,

        entry_date TEXT NOT NULL,

        initial_weight REAL,

        productive_status TEXT
          NOT NULL DEFAULT 'En producción'
          CHECK (
            productive_status IN (
              'En producción',
              'Seca',
              'Gestante',
              'No aplica'
            )
          ),

        minimum_daily_production REAL
          NOT NULL DEFAULT 4.0
          CHECK (minimum_daily_production >= 0),

        status TEXT
          NOT NULL DEFAULT 'Activo'
          CHECK (
            status IN (
              'Activo',
              'Inactivo',
              'Fallecido',
              'Baja'
            )
          ),

        observations TEXT NOT NULL DEFAULT '',

        image_path TEXT,

        created_at TEXT NOT NULL,

        FOREIGN KEY (user_id)
          REFERENCES $usersTable(id)
          ON DELETE CASCADE,

        FOREIGN KEY (lot_id)
          REFERENCES $lotsTable(id)
          ON DELETE RESTRICT,

        UNIQUE(user_id, code)
      )
    ''');
  }

  // =========================================================
  // VENTAS - TABLA ANTIGUA
  // =========================================================

  // =========================================================
  // VACUNAS ANTIGUAS
  // vaccine_records
  // =========================================================

  Future<void> _createLegacyVaccineRecordsTable(
    DatabaseExecutor database,
  ) async {
    await database.execute('''
      CREATE TABLE IF NOT EXISTS $vaccinesTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,

        user_id INTEGER NOT NULL,

        cattle_id INTEGER NOT NULL,

        cattle_code TEXT NOT NULL,

        vaccine_name TEXT NOT NULL,

        application_date TEXT NOT NULL,

        next_dose_date TEXT,

        dose_number INTEGER NOT NULL DEFAULT 1,

        responsible TEXT NOT NULL DEFAULT '',

        observations TEXT NOT NULL DEFAULT '',

        created_at TEXT NOT NULL,

        FOREIGN KEY (user_id)
          REFERENCES $usersTable(id)
          ON DELETE CASCADE,

        FOREIGN KEY (cattle_id)
          REFERENCES $cattleTable(id)
          ON DELETE CASCADE
      )
    ''');
  }

  // =========================================================
  // VETERINARIOS
  // =========================================================

  Future<void> _createVeterinariansTable(
    DatabaseExecutor database,
  ) async {
    await database.execute('''
      CREATE TABLE IF NOT EXISTS $veterinariansTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,

        server_id INTEGER UNIQUE,

        name TEXT NOT NULL,

        professional_license TEXT UNIQUE,

        phone TEXT NOT NULL DEFAULT '',

        email TEXT NOT NULL DEFAULT '',

        specialty TEXT NOT NULL DEFAULT '',

        status TEXT NOT NULL DEFAULT 'Activo'
          CHECK (status IN ('Activo', 'Inactivo')),

        observations TEXT NOT NULL DEFAULT '',

        created_at TEXT NOT NULL
      )
    ''');
  }

  // =========================================================
  // CATÁLOGO DE VACUNAS
  // =========================================================

  Future<void> _createVaccineCatalogTable(
    DatabaseExecutor database,
  ) async {
    await database.execute('''
      CREATE TABLE IF NOT EXISTS $vaccineCatalogTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,

        server_id INTEGER UNIQUE,

        name TEXT NOT NULL UNIQUE,

        description TEXT NOT NULL DEFAULT '',

        recommended_dose TEXT NOT NULL DEFAULT '',

        frequency_days INTEGER,

        status TEXT NOT NULL DEFAULT 'Activo'
          CHECK (status IN ('Activo', 'Inactivo')),

        created_at TEXT NOT NULL
      )
    ''');
  }

  // =========================================================
  // VACUNACIONES NUEVAS
  // =========================================================

  Future<void> _createVaccinationsTable(
    DatabaseExecutor database,
  ) async {
    await database.execute('''
      CREATE TABLE IF NOT EXISTS $vaccinationsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,

        user_id INTEGER NOT NULL,

        cattle_id INTEGER NOT NULL,

        vaccine_id INTEGER NOT NULL,

        veterinarian_id INTEGER,

        application_date TEXT NOT NULL,

        next_dose_date TEXT,

        dose_number INTEGER NOT NULL DEFAULT 1,

        dose TEXT NOT NULL DEFAULT '',

        observations TEXT NOT NULL DEFAULT '',

        created_at TEXT NOT NULL,

        FOREIGN KEY (user_id)
          REFERENCES $usersTable(id)
          ON DELETE CASCADE,

        FOREIGN KEY (cattle_id)
          REFERENCES $cattleTable(id)
          ON DELETE CASCADE,

        FOREIGN KEY (vaccine_id)
          REFERENCES $vaccineCatalogTable(id)
          ON DELETE RESTRICT,

        FOREIGN KEY (veterinarian_id)
          REFERENCES $veterinariansTable(id)
          ON DELETE RESTRICT
      )
    ''');
  }

  // =========================================================
  // REGISTROS DE ORDEÑO
  // =========================================================

  Future<void> _createMilkingGroupsTable(
    DatabaseExecutor database,
  ) async {
    await database.execute('''
      CREATE TABLE IF NOT EXISTS $milkingGroupsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,

        server_id INTEGER UNIQUE,

        user_id INTEGER NOT NULL,

        name TEXT NOT NULL,

        sort_order INTEGER NOT NULL,

        status TEXT NOT NULL DEFAULT 'Activo'
          CHECK (
            status IN (
              'Activo',
              'Inactivo'
            )
          ),

        sync_status TEXT NOT NULL DEFAULT 'pending'
          CHECK (
            sync_status IN (
              'pending',
              'synced',
              'error'
            )
          ),

        created_at TEXT NOT NULL,

        updated_at TEXT,

        last_sync_error TEXT,

        FOREIGN KEY (user_id)
          REFERENCES $usersTable(id)
          ON DELETE CASCADE,

        UNIQUE(user_id, name),

        UNIQUE(user_id, sort_order)
      )
    ''');
  }


  Future<void> _createMilkingGroupCattleTable(
    DatabaseExecutor database,
  ) async {
    await database.execute('''
      CREATE TABLE IF NOT EXISTS $milkingGroupCattleTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,

        group_id INTEGER NOT NULL,

        cattle_id INTEGER NOT NULL,

        created_at TEXT NOT NULL,

        FOREIGN KEY (group_id)
          REFERENCES $milkingGroupsTable(id)
          ON DELETE CASCADE,

        FOREIGN KEY (cattle_id)
          REFERENCES $cattleTable(id)
          ON DELETE CASCADE,

        UNIQUE(group_id, cattle_id)
      )
    ''');
  }

  Future<void> _createMilkingSessionsTable(
    DatabaseExecutor database,
  ) async {
    await database.execute('''
      CREATE TABLE IF NOT EXISTS $milkingSessionsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,

        uuid TEXT NOT NULL UNIQUE,

        server_id INTEGER UNIQUE,

        user_id INTEGER NOT NULL,

        group_id INTEGER NOT NULL,

        date TEXT NOT NULL,

        start_time TEXT,

        end_time TEXT,

        duration_minutes INTEGER,

        cattle_count INTEGER NOT NULL DEFAULT 0
          CHECK (cattle_count >= 0),

        total_liters REAL
          CHECK (
            total_liters IS NULL
            OR total_liters > 0
          ),

        status TEXT NOT NULL DEFAULT 'en_espera'
          CHECK (
            status IN (
              'en_espera',
              'en_produccion',
              'finalizado'
            )
          ),

        observations TEXT NOT NULL DEFAULT '',

        sync_status TEXT NOT NULL DEFAULT 'pending'
          CHECK (
            sync_status IN (
              'pending',
              'synced',
              'error'
            )
          ),

        created_at TEXT NOT NULL,

        updated_at TEXT,

        last_sync_error TEXT,

        FOREIGN KEY (user_id)
          REFERENCES $usersTable(id)
          ON DELETE CASCADE,

        FOREIGN KEY (group_id)
          REFERENCES $milkingGroupsTable(id)
          ON DELETE RESTRICT,

        UNIQUE(group_id, date)
      )
    ''');
  }

  Future<void> _createMilkingSessionCattleTable(
    DatabaseExecutor database,
    ) async {
      await database.execute('''
        CREATE TABLE IF NOT EXISTS $milkingSessionCattleTable (
          id INTEGER PRIMARY KEY AUTOINCREMENT,

          session_id INTEGER NOT NULL,

          cattle_id INTEGER NOT NULL,

          created_at TEXT NOT NULL,

          FOREIGN KEY (session_id)
            REFERENCES $milkingSessionsTable(id)
            ON DELETE CASCADE,

          FOREIGN KEY (cattle_id)
            REFERENCES $cattleTable(id)
            ON DELETE RESTRICT,

          UNIQUE(session_id, cattle_id)
        )
    ''');
  }
  // =========================================================
  // MIGRACIÓN
  // =========================================================
  Future<void> _createMilkingRecordsTable(
    DatabaseExecutor database,
  ) async {
    await database.execute('''
      CREATE TABLE IF NOT EXISTS $milkingRecordsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        user_id INTEGER NOT NULL,

        cattle_id INTEGER NOT NULL,

        historical_lot_id INTEGER,

        date TEXT NOT NULL,

        milking_number INTEGER NOT NULL
          CHECK (milking_number > 0),

        shift TEXT,

        liters REAL NOT NULL
          CHECK (liters > 0),

        observations TEXT NOT NULL DEFAULT '',

        created_at TEXT NOT NULL,

        server_id INTEGER,

        sync_status TEXT NOT NULL DEFAULT 'pending'
          CHECK (
            sync_status IN (
              'pending',
              'synced',
              'error'
            )
          ),

        updated_at TEXT,

        last_sync_error TEXT,

        FOREIGN KEY (user_id)
          REFERENCES $usersTable(id)
          ON DELETE CASCADE,

        FOREIGN KEY (cattle_id)
          REFERENCES $cattleTable(id)
          ON DELETE CASCADE,

        FOREIGN KEY (historical_lot_id)
          REFERENCES $lotsTable(id)
          ON DELETE RESTRICT,

        UNIQUE(
          cattle_id,
          date,
          milking_number
        )
      )
    ''');
  }

  Future<void> _upgradeDatabase(
    Database database,
    int oldVersion,
    int newVersion,
  ) async {
    await database.transaction(
      (Transaction transaction) async {
        // =====================================================
        // VERSIÓN 9 - ELIMINAR VENTAS
        // =====================================================

        if (oldVersion < 9) {
          await transaction.execute(
            'DROP TABLE IF EXISTS sales',
          );
        }

        // =====================================================
        // VERSIÓN 10 - SOPORTE OFFLINE / SINCRONIZACIÓN
        // =====================================================

        if (oldVersion < 10) {
          await _addColumnIfMissing(
            database: transaction,
            table: milkingRecordsTable,
            column: 'server_id',
            definition: 'INTEGER',
          );

          await _addColumnIfMissing(
            database: transaction,
            table: milkingRecordsTable,
            column: 'sync_status',
            definition: "TEXT NOT NULL DEFAULT 'pending'",
          );

          await _addColumnIfMissing(
            database: transaction,
            table: milkingRecordsTable,
            column: 'updated_at',
            definition: 'TEXT',
          );

          await _addColumnIfMissing(
            database: transaction,
            table: milkingRecordsTable,
            column: 'last_sync_error',
            definition: 'TEXT',
          );

          // Ganado
          await _addColumnIfMissing(
            database: transaction,
            table: cattleTable,
            column: 'server_id',
            definition: 'INTEGER',
          );

          await _addColumnIfMissing(
            database: transaction,
            table: cattleTable,
            column: 'sync_status',
            definition: "TEXT NOT NULL DEFAULT 'pending'",
          );

          await _addColumnIfMissing(
            database: transaction,
            table: cattleTable,
            column: 'updated_at',
            definition: 'TEXT',
          );

          await _addColumnIfMissing(
            database: transaction,
            table: cattleTable,
            column: 'last_sync_error',
            definition: 'TEXT',
          );

          // Lotes
          await _addColumnIfMissing(
            database: transaction,
            table: lotsTable,
            column: 'server_id',
            definition: 'INTEGER',
          );

          await _addColumnIfMissing(
            database: transaction,
            table: lotsTable,
            column: 'sync_status',
            definition: "TEXT NOT NULL DEFAULT 'pending'",
          );

          await _addColumnIfMissing(
            database: transaction,
            table: lotsTable,
            column: 'updated_at',
            definition: 'TEXT',
          );

          await _addColumnIfMissing(
            database: transaction,
            table: lotsTable,
            column: 'last_sync_error',
            definition: 'TEXT',
          );
        }

        if (oldVersion < 11) {
          await _addColumnIfMissing(
            database: transaction,
            table: lotsTable,
            column: 'farm_id',
            definition: 'INTEGER',
          );
        }
        // =====================================================
        // ASEGURAR TABLAS EXISTENTES
        // =====================================================

        if (!await _tableExists(
          transaction,
          usersTable,
        )) {
          await _createUsersTable(transaction);
        }

        if (!await _tableExists(
          transaction,
          cattleTable,
        )) {
          await _createCattleTable(transaction);
        }

        if (!await _tableExists(
          transaction,
          vaccinesTable,
        )) {
          await _createLegacyVaccineRecordsTable(
            transaction,
          );
        }

        // =====================================================
        // CREAR NUEVAS TABLAS
        // =====================================================

        if (!await _tableExists(
          transaction,
          lotsTable,
        )) {
          await _createLotsTable(transaction);
        }

        if (!await _tableExists(
          transaction,
          veterinariansTable,
        )) {
          await _createVeterinariansTable(
            transaction,
          );
        }

        if (!await _tableExists(
          transaction,
          vaccineCatalogTable,
        )) {
          await _createVaccineCatalogTable(
            transaction,
          );
        }

        if (!await _tableExists(
          transaction,
          vaccinationsTable,
        )) {
          await _createVaccinationsTable(
            transaction,
          );
        }

        if (!await _tableExists(
          transaction,
          milkingRecordsTable,
        )) {
          await _createMilkingRecordsTable(
            transaction,
          );
        }

        // =====================================================
        // MIGRAR GANADO SIN RECONSTRUIR TABLA
        // =====================================================
        //
        // Es importante NO renombrar cattle en esta etapa.
        //
        // sales y vaccine_records tienen claves foráneas
        // apuntando a cattle.
        //
        // Reconstruir la tabla ahora podría romper esas
        // relaciones.
        // =====================================================

        await _addColumnIfMissing(
          database: transaction,
          table: cattleTable,
          column: 'name',
          definition: "TEXT NOT NULL DEFAULT ''",
        );

        await _addColumnIfMissing(
          database: transaction,
          table: cattleTable,
          column: 'sex',
          definition: "TEXT NOT NULL DEFAULT 'Hembra'",
        );

        await _addColumnIfMissing(
          database: transaction,
          table: cattleTable,
          column: 'breed',
          definition: "TEXT NOT NULL DEFAULT ''",
        );

        await _addColumnIfMissing(
          database: transaction,
          table: cattleTable,
          column: 'birth_date',
          definition: 'TEXT',
        );

        await _addColumnIfMissing(
          database: transaction,
          table: cattleTable,
          column: 'productive_status',
          definition: "TEXT NOT NULL DEFAULT 'En producción'",
        );

        await _addColumnIfMissing(
          database: transaction,
          table: cattleTable,
          column: 'minimum_daily_production',
          definition: 'REAL NOT NULL DEFAULT 4.0',
        );

        await _addColumnIfMissing(
          database: transaction,
          table: cattleTable,
          column: 'status',
          definition: "TEXT NOT NULL DEFAULT 'Activo'",
        );

        // =====================================================
        // ASEGURAR user_id DE VERSIONES ANTERIORES
        // =====================================================

        await _addColumnIfMissing(
          database: transaction,
          table: cattleTable,
          column: 'user_id',
          definition: 'INTEGER',
        );

        await _addColumnIfMissing(
          database: transaction,
          table: vaccinesTable,
          column: 'user_id',
          definition: 'INTEGER',
        );

        // =====================================================
        // MIGRAR LOTES ANTIGUOS
        // =====================================================

        await _migrateLegacyLots(
          transaction,
        );

        // =====================================================
        // MIGRAR CATÁLOGO DE VACUNAS ANTIGUAS
        // =====================================================

        await _migrateLegacyVaccines(
          transaction,
        );

        // =====================================================
        // VERSIÓN 12 - UUID PARA SINCRONIZACIÓN DE ORDEÑOS
        // =====================================================

        if (oldVersion < 12) {
          await _addColumnIfMissing(
            database: transaction,
            table: milkingRecordsTable,
            column: 'uuid',
            definition: 'TEXT',
          );

          await transaction.execute('''
              CREATE UNIQUE INDEX IF NOT EXISTS
              idx_milking_records_uuid
              ON $milkingRecordsTable(uuid)
            ''');
        }

        // =====================================================
        // VERSIÓN 13 - IDS DEL SERVIDOR PARA SANIDAD
        // =====================================================

        if (oldVersion < 13) {
          await _addColumnIfMissing(
            database: transaction,
            table: veterinariansTable,
            column: 'server_id',
            definition: 'INTEGER',
          );

          await _addColumnIfMissing(
            database: transaction,
            table: vaccineCatalogTable,
            column: 'server_id',
            definition: 'INTEGER',
          );

          await transaction.execute('''
          CREATE UNIQUE INDEX IF NOT EXISTS
          idx_veterinarians_server_id
          ON $veterinariansTable(server_id)
        ''');

          await transaction.execute('''
          CREATE UNIQUE INDEX IF NOT EXISTS
          idx_vaccines_server_id
          ON $vaccineCatalogTable(server_id)
        ''');
        }

        if (oldVersion < 14) {
          await _createMilkingGroupsTable(transaction);

          await _createMilkingGroupCattleTable(transaction);

          await _createMilkingSessionsTable(transaction);

          await _createMilkingSessionCattleTable(transaction);
        }

      },
    );
  }

  // =========================================================
  // MIGRAR LOTES ANTIGUOS
  // =========================================================

  Future<void> _migrateLegacyLots(
    DatabaseExecutor database,
  ) async {
    final bool hasLotColumn = await _columnExists(
      database: database,
      table: cattleTable,
      column: 'lot',
    );

    final bool hasCorralColumn = await _columnExists(
      database: database,
      table: cattleTable,
      column: 'corral',
    );

    if (!hasLotColumn && !hasCorralColumn) {
      return;
    }

    final List<Map<String, dynamic>> cattle = await database.query(
      cattleTable,
    );

    for (final Map<String, dynamic> animal in cattle) {
      final int? animalId = (animal['id'] as num?)?.toInt();

      final int? userId = (animal['user_id'] as num?)?.toInt();

      if (animalId == null || userId == null) {
        continue;
      }

      final String oldLot = animal['lot']?.toString().trim() ?? '';

      final String oldCorral = animal['corral']?.toString().trim() ?? '';

      /*
       * Por ahora usamos:
       *
       * lot si existe,
       * de lo contrario corral.
       *
       * No eliminamos ninguno de los campos antiguos.
       */
      final String lotName = oldLot.isNotEmpty ? oldLot : oldCorral;

      if (lotName.isEmpty) {
        continue;
      }

      await database.insert(
        lotsTable,
        {
          'user_id': userId,
          'name': lotName,
          'description': oldCorral.isNotEmpty && oldCorral != lotName
              ? 'Corral anterior: $oldCorral'
              : '',
          'minimum_production_per_cow': 4.0,
          'status': 'Activo',
          'created_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      final List<Map<String, dynamic>> lotResult = await database.query(
        lotsTable,
        columns: ['id'],
        where: 'user_id = ? AND name = ?',
        whereArgs: [
          userId,
          lotName,
        ],
        limit: 1,
      );

      if (lotResult.isEmpty) {
        continue;
      }

      final int lotId = (lotResult.first['id'] as num).toInt();

      await database.update(
        cattleTable,
        {
          'lot_id': lotId,
        },
        where: 'id = ? AND user_id = ?',
        whereArgs: [
          animalId,
          userId,
        ],
      );
    }
  }

  // =========================================================
  // MIGRAR VACUNAS ANTIGUAS
  // =========================================================

  Future<void> _migrateLegacyVaccines(
    DatabaseExecutor database,
  ) async {
    if (!await _tableExists(
      database,
      vaccinesTable,
    )) {
      return;
    }

    final List<Map<String, dynamic>> records = await database.query(
      vaccinesTable,
    );

    for (final Map<String, dynamic> record in records) {
      final String vaccineName =
          record['vaccine_name']?.toString().trim() ?? '';

      if (vaccineName.isEmpty) {
        continue;
      }

      await database.insert(
        vaccineCatalogTable,
        {
          'name': vaccineName,
          'description': '',
          'recommended_dose': '',
          'frequency_days': null,
          'status': 'Activo',
          'created_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  // =========================================================
  // UTILIDADES
  // =========================================================

  Future<bool> _tableExists(
    DatabaseExecutor database,
    String tableName,
  ) async {
    final List<Map<String, dynamic>> result = await database.rawQuery(
      '''
      SELECT name
      FROM sqlite_master
      WHERE type = 'table'
        AND name = ?
      LIMIT 1
      ''',
      [tableName],
    );

    return result.isNotEmpty;
  }

  Future<bool> _columnExists({
    required DatabaseExecutor database,
    required String table,
    required String column,
  }) async {
    final List<Map<String, dynamic>> columns = await database.rawQuery(
      'PRAGMA table_info($table)',
    );

    return columns.any(
      (Map<String, dynamic> item) => item['name'] == column,
    );
  }

  Future<void> _addColumnIfMissing({
    required DatabaseExecutor database,
    required String table,
    required String column,
    required String definition,
  }) async {
    final bool exists = await _columnExists(
      database: database,
      table: table,
      column: column,
    );

    if (exists) {
      return;
    }

    await database.execute(
      'ALTER TABLE $table '
      'ADD COLUMN $column $definition',
    );
  }

  // =========================================================
  // CERRAR BASE DE DATOS
  // =========================================================

  Future<void> closeDatabase() async {
    final Database? currentDatabase = _database;

    if (currentDatabase == null) {
      return;
    }

    await currentDatabase.close();

    _database = null;
  }
}
