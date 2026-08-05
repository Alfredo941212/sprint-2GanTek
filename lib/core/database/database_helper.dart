import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  DatabaseHelper._internal();

  static final DatabaseHelper instance = DatabaseHelper._internal();

  static Database? _database;

  static const String databaseName = 'gantek.db';

  // Se aumenta para ejecutar la nueva migración.
  static const int databaseVersion = 7;

  static const String usersTable = 'users';
  static const String cattleTable = 'cattle';
  static const String salesTable = 'sales';
  static const String vaccinesTable = 'vaccine_records';

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initializeDatabase();
    return _database!;
  }

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

  Future<void> _createDatabase(
    Database database,
    int version,
  ) async {
    await _createUsersTable(database);
    await _createCattleTable(database);
    await _createSalesTable(database);
    await _createVaccinesTable(database);
  }

  // =========================================================
  // USUARIOS
  // =========================================================

  Future<void> _createUsersTable(
    Database database,
  ) async {
    await database.execute('''
      CREATE TABLE $usersTable (
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
  // GANADO
  // =========================================================

  Future<void> _createCattleTable(
    Database database,
  ) async {
    await database.execute('''
      CREATE TABLE $cattleTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        code TEXT NOT NULL,
        entry_date TEXT NOT NULL,
        initial_weight REAL NOT NULL,
        vaccines TEXT NOT NULL DEFAULT '',
        observations TEXT NOT NULL DEFAULT '',
        image_path TEXT,
        lot TEXT NOT NULL DEFAULT '',
        corral TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,

        FOREIGN KEY (user_id)
          REFERENCES $usersTable(id)
          ON DELETE CASCADE,

        UNIQUE(user_id, code)
      )
    ''');
  }

  // =========================================================
  // VENTAS
  // =========================================================

  Future<void> _createSalesTable(
    Database database,
  ) async {
    await database.execute('''
      CREATE TABLE $salesTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        cattle_id INTEGER NOT NULL,
        cattle_code TEXT NOT NULL,
        buyer_name TEXT NOT NULL,
        buyer_phone TEXT NOT NULL DEFAULT '',
        sale_date TEXT NOT NULL,
        sale_weight REAL NOT NULL,
        price_per_kg REAL NOT NULL,
        total REAL NOT NULL,
        payment_method TEXT NOT NULL,
        observations TEXT NOT NULL DEFAULT '',
        status TEXT NOT NULL DEFAULT 'completada',
        created_at TEXT NOT NULL,

        FOREIGN KEY (user_id)
          REFERENCES $usersTable(id)
          ON DELETE CASCADE,

        FOREIGN KEY (cattle_id)
          REFERENCES $cattleTable(id)
          ON DELETE RESTRICT
      )
    ''');
  }

  // =========================================================
  // VACUNAS
  // =========================================================

  Future<void> _createVaccinesTable(
    Database database,
  ) async {
    await database.execute('''
      CREATE TABLE $vaccinesTable (
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
  // MIGRACIONES
  // =========================================================

  Future<void> _upgradeDatabase(
    Database database,
    int oldVersion,
    int newVersion,
  ) async {
    /*
     * En lugar de confiar únicamente en oldVersion,
     * verificamos si las tablas y columnas existen.
     *
     * Esto evita errores cuando una versión anterior
     * quedó instalada con una estructura incompleta.
     */

    if (!await _tableExists(
      database,
      usersTable,
    )) {
      await _createUsersTable(database);
    }

    if (!await _tableExists(
      database,
      cattleTable,
    )) {
      await _createCattleTable(database);
    }

    if (!await _tableExists(
      database,
      salesTable,
    )) {
      await _createSalesTable(database);
    }

    if (!await _tableExists(
      database,
      vaccinesTable,
    )) {
      await _createVaccinesTable(database);
    }

    // Agregar user_id a cattle si todavía no existe.
    await _addColumnIfMissing(
      database: database,
      table: cattleTable,
      column: 'user_id',
      definition: 'INTEGER',
    );

    // Agregar user_id a sales si todavía no existe.
    await _addColumnIfMissing(
      database: database,
      table: salesTable,
      column: 'user_id',
      definition: 'INTEGER',
    );

    // Agregar user_id a vacunas si todavía no existe.
    await _addColumnIfMissing(
      database: database,
      table: vaccinesTable,
      column: 'user_id',
      definition: 'INTEGER',
    );
  }

  Future<bool> _tableExists(
    Database database,
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
    required Database database,
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
    required Database database,
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
  // CERRAR BASE
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
