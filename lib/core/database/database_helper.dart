import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';

class DatabaseHelper {
  DatabaseHelper._internal();

  static final DatabaseHelper instance = DatabaseHelper._internal();

  static Database? _database;

  static const String databaseName = 'gantek.db';
  static const int databaseVersion = 5;

  static const String usersTable = "users";
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

  Future<void> _createUsersTable(Database database) async {
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

  Future<void> _createSalesTable(
    Database database,
  ) async {
    await database.execute('''
      CREATE TABLE $salesTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
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
        FOREIGN KEY (cattle_id) REFERENCES $cattleTable(id)
      )
    ''');
  }

  Future<void> _createVaccinesTable(
    Database database,
  ) async {
    await database.execute('''
      CREATE TABLE $vaccinesTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cattle_id INTEGER NOT NULL,
        cattle_code TEXT NOT NULL,
        vaccine_name TEXT NOT NULL,
        application_date TEXT NOT NULL,
        next_dose_date TEXT,
        dose_number INTEGER NOT NULL DEFAULT 1,
        responsible TEXT NOT NULL DEFAULT '',
        observations TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        FOREIGN KEY (cattle_id)
          REFERENCES $cattleTable(id)
          ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _upgradeDatabase(
    Database database,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await _createUsersTable(database);
    }

    if (oldVersion < 3) {
      await _createSalesTable(database);
    }
    if (oldVersion < 4) {
      await _createVaccinesTable(database);
    }
    if (oldVersion < 5) {
      await database.execute(
        'ALTER TABLE $cattleTable '
        'ADD COLUMN user_id INTEGER',
      );
    }
  }

  Future<void> closeDatabase() async {
    final Database? currentDatabase = _database;

    if (currentDatabase != null) {
      await currentDatabase.close();
      _database = null;
    }
  }
}
