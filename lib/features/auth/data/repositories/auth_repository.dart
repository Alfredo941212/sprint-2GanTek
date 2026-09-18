import 'package:bcrypt/bcrypt.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
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

  String _firebaseAuthMessage(
    FirebaseAuthException error,
  ) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'Este correo ya está registrado.';

      case 'invalid-email':
        return 'El correo electrónico no es válido.';

      case 'weak-password':
        return 'La contraseña es demasiado débil.';

      case 'user-not-found':
        return 'No existe una cuenta con ese correo.';

      case 'wrong-password':
      case 'invalid-credential':
        return 'Correo o contraseña incorrectos.';

      case 'too-many-requests':
        return 'Demasiados intentos. Intenta nuevamente más tarde.';

      case 'network-request-failed':
        return 'No hay conexión a Internet.';

      default:
        return error.message ??
            'Ocurrió un problema con Firebase Authentication.';
    }
  }

  Future<int> registerUser({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    try {
      final String normalizedEmail = email.trim().toLowerCase();

      final UserCredential credential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );

      final User? firebaseUser = credential.user;

      if (firebaseUser == null) {
        throw Exception(
          'Firebase no pudo crear el usuario.',
        );
      }

      await firebaseUser.updateDisplayName(
        fullName.trim(),
      );

      await firebaseUser.sendEmailVerification();

      final Database database = await _databaseHelper.database;

      final UserModel user = UserModel(
        fullName: fullName.trim(),
        email: normalizedEmail,
        phone: phone.trim(),
        passwordHash: hashPassword(
          'firebase:${firebaseUser.uid}',
        ),
        role: 'ganadero',
        createdAt: DateTime.now(),
      );

      final Map<String, dynamic> data = user.toMap();

      data.remove('id');

      return await database.insert(
        DatabaseHelper.usersTable,
        data,
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    } on FirebaseAuthException catch (error) {
      throw Exception(
        _firebaseAuthMessage(error),
      );
    }
  }

  Future<UserModel> createLocalUser({
    required String fullName,
    required String email,
    required String phone,
  }) async {
    final String normalizedEmail = email.trim().toLowerCase();

    final Database database = await _databaseHelper.database;

    final List<Map<String, dynamic>> existingUsers = await database.query(
      DatabaseHelper.usersTable,
      where: 'email = ?',
      whereArgs: [normalizedEmail],
      limit: 1,
    );

    if (existingUsers.isNotEmpty) {
      return UserModel.fromMap(
        existingUsers.first,
      );
    }

    final UserModel user = UserModel(
      fullName: fullName.trim(),
      email: normalizedEmail,
      phone: phone.trim(),
      passwordHash: hashPassword(
        'api:$normalizedEmail',
      ),
      role: 'ganadero',
      createdAt: DateTime.now(),
    );

    final Map<String, dynamic> data = user.toMap();

    data.remove('id');

    final int id = await database.insert(
      DatabaseHelper.usersTable,
      data,
      conflictAlgorithm: ConflictAlgorithm.abort,
    );

    return user.copyWith(
      id: id,
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
    try {
      final String normalizedEmail = email.trim().toLowerCase();

      final UserCredential credential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );

      final User? firebaseUser = credential.user;

      if (firebaseUser == null) {
        return null;
      }

      final Database database = await _databaseHelper.database;

      final List<Map<String, dynamic>> result = await database.query(
        DatabaseHelper.usersTable,
        where: 'email = ?',
        whereArgs: [normalizedEmail],
        limit: 1,
      );

      if (result.isNotEmpty) {
        return UserModel.fromMap(
          result.first,
        );
      }

      final UserModel newUser = UserModel(
        fullName: firebaseUser.displayName?.trim().isNotEmpty == true
            ? firebaseUser.displayName!.trim()
            : 'Usuario GanTek',
        email: normalizedEmail,
        phone: '',
        passwordHash: hashPassword(
          'firebase:${firebaseUser.uid}',
        ),
        role: 'ganadero',
        createdAt: DateTime.now(),
      );

      final Map<String, dynamic> data = newUser.toMap();

      data.remove('id');

      final int id = await database.insert(
        DatabaseHelper.usersTable,
        data,
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      return newUser.copyWith(
        id: id,
      );
    } on FirebaseAuthException {
      return null;
    }
  }

  Future<void> sendPasswordResetEmail({
    required String email,
  }) async {
    final String normalizedEmail = email.trim().toLowerCase();

    try {
      print('==============================');
      print('SOLICITANDO RECUPERACIÓN');
      print('Correo: $normalizedEmail');

      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: normalizedEmail,
      );

      print('FIREBASE CONFIRMÓ LA SOLICITUD');
      print('==============================');
    } on FirebaseAuthException catch (error) {
      print('==============================');
      print('ERROR FIREBASE');
      print('Código: ${error.code}');
      print('Mensaje: ${error.message}');
      print('==============================');

      throw Exception(
        _firebaseAuthMessage(error),
      );
    }
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

  // ============================================================
  // GOOGLE
  // ============================================================

  Future<UserModel?> signInWithGoogle() async {
    final GoogleSignIn googleSignIn = GoogleSignIn.instance;

    try {
      if (!googleSignIn.supportsAuthenticate()) {
        throw Exception(
          'Google Sign-In no está disponible en esta plataforma.',
        );
      }

      final GoogleSignInAccount googleUser = await googleSignIn.authenticate();

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception(
          'Google no devolvió el token de autenticación.',
        );
      }

      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: idToken,
      );

      final UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(
        credential,
      );

      final User? firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        throw Exception(
          'Firebase no pudo obtener el usuario.',
        );
      }

      final String email =
          (firebaseUser.email ?? googleUser.email).trim().toLowerCase();

      final String fullName = (firebaseUser.displayName ??
              googleUser.displayName ??
              'Usuario Google')
          .trim();

      final Database database = await _databaseHelper.database;

      // ----------------------------------------------------------
      // 1. Buscar si el usuario ya existe en SQLite
      // ----------------------------------------------------------

      final List<Map<String, dynamic>> existingUsers = await database.query(
        DatabaseHelper.usersTable,
        where: 'email = ?',
        whereArgs: [email],
        limit: 1,
      );

      if (existingUsers.isNotEmpty) {
        return UserModel.fromMap(
          existingUsers.first,
        );
      }

      // ----------------------------------------------------------
      // 2. Si no existe, crear usuario local
      // ----------------------------------------------------------

      final UserModel newUser = UserModel(
        fullName: fullName.isEmpty ? 'Usuario Google' : fullName,
        email: email,
        phone: '',
        passwordHash: hashPassword(
          'google:${firebaseUser.uid}',
        ),
        role: 'ganadero',
        createdAt: DateTime.now(),
      );

      final Map<String, dynamic> data = newUser.toMap();

      data.remove('id');

      final int userId = await database.insert(
        DatabaseHelper.usersTable,
        data,
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      return newUser.copyWith(
        id: userId,
      );
    } on GoogleSignInException catch (error) {
      throw Exception(
        'Error de Google: ${error.description ?? error.code.name}',
      );
    } on FirebaseAuthException catch (error) {
      throw Exception(
        'Error de Firebase: ${error.message ?? error.code}',
      );
    } catch (error) {
      throw Exception(
        'No fue posible iniciar sesión con Google: $error',
      );
    }
  }

  Future<UserModel?> signInWithFacebook() async {
    try {
      final LoginResult result = await FacebookAuth.instance.login(
        permissions: ['email', 'public_profile'],
      );

      if (result.status != LoginStatus.success) {
        if (result.status == LoginStatus.cancelled) {
          return null;
        }

        throw Exception(
          result.message ?? 'No fue posible iniciar sesión con Facebook.',
        );
      }

      final AccessToken? accessToken = result.accessToken;

      if (accessToken == null) {
        throw Exception(
          'Facebook no devolvió un token de acceso.',
        );
      }

      final OAuthCredential credential = FacebookAuthProvider.credential(
        accessToken.tokenString,
      );

      final UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(
        credential,
      );

      final User? firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        throw Exception(
          'Firebase no pudo obtener el usuario de Facebook.',
        );
      }

      final Map<String, dynamic> facebookData =
          await FacebookAuth.instance.getUserData(
        fields: 'name,email',
      );

      final String email =
          (firebaseUser.email ?? facebookData['email']?.toString() ?? '')
              .trim()
              .toLowerCase();

      if (email.isEmpty) {
        throw Exception(
          'Facebook no proporcionó un correo electrónico.',
        );
      }

      final String fullName = (firebaseUser.displayName ??
              facebookData['name']?.toString() ??
              'Usuario Facebook')
          .trim();

      final Database database = await _databaseHelper.database;

      final List<Map<String, dynamic>> existingUsers = await database.query(
        DatabaseHelper.usersTable,
        where: 'email = ?',
        whereArgs: [email],
        limit: 1,
      );

      if (existingUsers.isNotEmpty) {
        return UserModel.fromMap(
          existingUsers.first,
        );
      }

      final UserModel newUser = UserModel(
        fullName: fullName.isEmpty ? 'Usuario Facebook' : fullName,
        email: email,
        phone: '',
        passwordHash: hashPassword(
          'facebook:${firebaseUser.uid}',
        ),
        role: 'ganadero',
        createdAt: DateTime.now(),
      );

      final Map<String, dynamic> data = newUser.toMap();

      data.remove('id');

      final int userId = await database.insert(
        DatabaseHelper.usersTable,
        data,
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      return newUser.copyWith(
        id: userId,
      );
    } on FirebaseAuthException catch (error) {
      throw Exception(
        'Error de Firebase: ${error.message ?? error.code}',
      );
    } catch (error) {
      throw Exception(
        'No fue posible iniciar sesión con Facebook: $error',
      );
    }
  }
}
