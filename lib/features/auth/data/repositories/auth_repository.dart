import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/database/database_helper.dart';
import '../models/user_model.dart';

class AuthRepository {
  final DatabaseHelper _databaseHelper;

  AuthRepository({
    DatabaseHelper? databaseHelper,
  }) : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  String hashPassword(String password) {
    final List<int> bytes = utf8.encode(password);

    return sha256.convert(bytes).toString();
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
      where: 'email = ? AND password_hash = ?',
      whereArgs: [
        email.trim().toLowerCase(),
        hashPassword(password),
      ],
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    return UserModel.fromMap(result.first);
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
