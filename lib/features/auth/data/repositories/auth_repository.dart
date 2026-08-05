import 'package:bcrypt/bcrypt.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/database/database_helper.dart';
import '../models/user_model.dart';

class AuthRepository {
  final DatabaseHelper _databaseHelper;

  AuthRepository({
    DatabaseHelper? databaseHelper,
  }) : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  String hashPassword(String password) {
    return BCrypt.hashpw(
      password,
      BCrypt.gensalt(),
    );
  }

  Future<int> registerUser({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    final Database database = await _databaseHelper.database;

    final UserModel user = UserModel(
      fullName: fullName.trim(),
      email: email.trim().toLowerCase(),
      phone: phone.trim(),
      passwordHash: hashPassword(password),
      role: 'ganadero',
      createdAt: DateTime.now(),
    );

    final Map<String, dynamic> data = user.toMap();
    data.remove('id');

    return database.insert(
      DatabaseHelper.usersTable,
      data,
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<bool> emailExists(String email) async {
    final Database database = await _databaseHelper.database;

    final List<Map<String, dynamic>> result = await database.query(
      DatabaseHelper.usersTable,
      columns: ['id'],
      where: 'email = ?',
      whereArgs: [email.trim().toLowerCase()],
      limit: 1,
    );

    return result.isNotEmpty;
  }

  Future<UserModel?> login({
    required String email,
    required String password,
  }) async {
    final Database database = await _databaseHelper.database;

    final List<Map<String, dynamic>> result = await database.query(
      DatabaseHelper.usersTable,
      where: 'email = ?',
      whereArgs: [
        email.trim().toLowerCase(),
      ],
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    final UserModel user = UserModel.fromMap(result.first);

    final String storedHash = user.passwordHash.trim();

    // Un hash bcrypt válido normalmente empieza con:
    // $2a$, $2b$ o $2y$
    final bool isBcryptHash = storedHash.startsWith(r'$2a$') ||
        storedHash.startsWith(r'$2b$') ||
        storedHash.startsWith(r'$2y$');

    if (!isBcryptHash) {
      // Usuario antiguo almacenado con SHA-256.
      // No se envía a BCrypt.checkpw porque produciría
      // "Invalid salt version".
      return null;
    }

    try {
      final bool passwordIsValid = BCrypt.checkpw(
        password,
        storedHash,
      );

      return passwordIsValid ? user : null;
    } on ArgumentError {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> resetPassword({
    required String email,
    required String newPassword,
  }) async {
    final Database database = await _databaseHelper.database;

    final int affectedRows = await database.update(
      DatabaseHelper.usersTable,
      {
        'password_hash': hashPassword(newPassword),
      },
      where: 'email = ?',
      whereArgs: [email.trim().toLowerCase()],
    );

    return affectedRows > 0;
  }

  Future<UserModel?> getUserByEmail(
    String email,
  ) async {
    final Database database = await _databaseHelper.database;

    final List<Map<String, dynamic>> result = await database.query(
      DatabaseHelper.usersTable,
      where: 'email = ?',
      whereArgs: [email.trim().toLowerCase()],
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    return UserModel.fromMap(result.first);
  }
}
