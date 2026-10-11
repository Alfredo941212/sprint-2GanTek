import 'dart:convert';

import 'package:bcrypt/bcrypt.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

import '../../../../core/database/database_helper.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/session/session_manager.dart';
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

      // ============================================================
      // 1. INICIAR SESIÓN CON GOOGLE
      // ============================================================

      final GoogleSignInAccount googleUser = await googleSignIn.authenticate();

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      final String? googleIdToken = googleAuth.idToken;

      if (googleIdToken == null || googleIdToken.isEmpty) {
        throw Exception(
          'Google no devolvió el token de autenticación.',
        );
      }

      // ============================================================
      // 2. AUTENTICAR CON FIREBASE
      // ============================================================

      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleIdToken,
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

      // ============================================================
      // 3. OBTENER EL FIREBASE ID TOKEN
      // ============================================================

      final String? firebaseIdToken = await firebaseUser.getIdToken(true);

      if (firebaseIdToken == null || firebaseIdToken.isEmpty) {
        throw Exception(
          'Firebase no devolvió un ID Token válido.',
        );
      }

      print('==============================');
      print('GOOGLE + FIREBASE OK');
      print('Correo: ${firebaseUser.email}');
      print('Enviando Firebase ID Token a Laravel...');
      print('==============================');

      // ============================================================
      // 4. ENVIAR EL FIREBASE ID TOKEN A LARAVEL
      // ============================================================

      final response = await ApiClient.instance.post(
        '/auth/google',
        body: {
          'id_token': firebaseIdToken,
        },
      );

      print('==============================');
      print('RESPUESTA LARAVEL GOOGLE');
      print('Status: ${response.statusCode}');
      print('Body: ${response.body}');
      print('==============================');

      final dynamic decodedBody = jsonDecode(response.body);

      if (decodedBody is! Map<String, dynamic>) {
        throw Exception(
          'Laravel devolvió una respuesta inválida.',
        );
      }

      final Map<String, dynamic> responseData = decodedBody;

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          responseData['message']?.toString() ??
              'Laravel no pudo validar la cuenta de Google.',
        );
      }

      // ============================================================
      // 5. OBTENER TOKEN SANCTUM
      // ============================================================

      final String sanctumToken = responseData['token']?.toString() ?? '';

      if (sanctumToken.isEmpty) {
        throw Exception(
          'Laravel no devolvió el token de sesión.',
        );
      }

      final dynamic laravelUserData = responseData['user'];

      if (laravelUserData is! Map) {
        throw Exception(
          'Laravel no devolvió los datos del usuario.',
        );
      }

      final String email =
          (laravelUserData['email'] ?? firebaseUser.email ?? googleUser.email)
              .toString()
              .trim()
              .toLowerCase();

      final String fullName = (laravelUserData['name'] ??
              firebaseUser.displayName ??
              googleUser.displayName ??
              'Usuario Google')
          .toString()
          .trim();

      if (email.isEmpty) {
        throw Exception(
          'No fue posible obtener el correo del usuario.',
        );
      }

      // ============================================================
      // 6. CREAR O RECUPERAR USUARIO LOCAL
      // ============================================================

      final UserModel localUser = await createLocalUser(
        fullName: fullName.isEmpty ? 'Usuario Google' : fullName,
        email: email,
        phone: '',
      );

      // ============================================================
      // 7. GUARDAR SESIÓN LOCAL + TOKEN SANCTUM
      // ============================================================

      await SessionManager.instance.setCurrentUser(
        localUser,
      );

      await SessionManager.instance.setApiToken(
        sanctumToken,
      );

      print('==============================');
      print('SESIÓN GOOGLE COMPLETADA');
      print('Usuario local ID: ${localUser.id}');
      print(
        'Token Sanctum guardado: ${sanctumToken.isNotEmpty}',
      );
      print('==============================');

      return localUser;
    } on GoogleSignInException catch (error) {
      throw Exception(
        'Error de Google: '
        '${error.description ?? error.code.name}',
      );
    } on FirebaseAuthException catch (error) {
      throw Exception(
        'Error de Firebase: '
        '${error.message ?? error.code}',
      );
    } catch (error) {
      throw Exception(
        'No fue posible iniciar sesión con Google: $error',
      );
    }
  }

  Future<UserModel?> signInWithFacebook() async {
    try {
      // ============================================================
      // 1. INICIAR SESIÓN CON FACEBOOK
      // ============================================================

      final LoginResult result = await FacebookAuth.instance.login(
        permissions: [
          'email',
          'public_profile',
        ],
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

      // ============================================================
      // 2. AUTENTICAR FACEBOOK CON FIREBASE
      // ============================================================

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

      // ============================================================
      // 3. OBTENER FIREBASE ID TOKEN
      // ============================================================

      final String? firebaseIdToken = await firebaseUser.getIdToken(true);

      if (firebaseIdToken == null || firebaseIdToken.isEmpty) {
        throw Exception(
          'Firebase no devolvió un ID Token válido.',
        );
      }

      print('==============================');
      print('FACEBOOK + FIREBASE OK');
      print('Correo: ${firebaseUser.email}');
      print('Enviando Firebase ID Token a Laravel...');
      print('==============================');

      // ============================================================
      // 4. ENVIAR TOKEN DE FIREBASE A LARAVEL
      // ============================================================

      final response = await ApiClient.instance.post(
        '/auth/facebook',
        body: {
          'id_token': firebaseIdToken,
        },
      );

      print('==============================');
      print('RESPUESTA LARAVEL FACEBOOK');
      print('Status: ${response.statusCode}');
      print('Body: ${response.body}');
      print('==============================');

      final dynamic decodedBody = jsonDecode(
        response.body,
      );

      if (decodedBody is! Map<String, dynamic>) {
        throw Exception(
          'Laravel devolvió una respuesta inválida.',
        );
      }

      final Map<String, dynamic> responseData = decodedBody;

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          responseData['message']?.toString() ??
              'Laravel no pudo validar la cuenta de Facebook.',
        );
      }

      // ============================================================
      // 5. OBTENER TOKEN SANCTUM
      // ============================================================

      final String sanctumToken = responseData['token']?.toString() ?? '';

      if (sanctumToken.isEmpty) {
        throw Exception(
          'Laravel no devolvió el token de sesión.',
        );
      }

      final dynamic laravelUserData = responseData['user'];

      if (laravelUserData is! Map) {
        throw Exception(
          'Laravel no devolvió los datos del usuario.',
        );
      }

      final String email =
          (laravelUserData['email'] ?? firebaseUser.email ?? '')
              .toString()
              .trim()
              .toLowerCase();

      if (email.isEmpty) {
        throw Exception(
          'Facebook no proporcionó un correo electrónico.',
        );
      }

      final String fullName = (laravelUserData['name'] ??
              firebaseUser.displayName ??
              'Usuario Facebook')
          .toString()
          .trim();

      // ============================================================
      // 6. CREAR O RECUPERAR USUARIO LOCAL
      // ============================================================

      final UserModel localUser = await createLocalUser(
        fullName: fullName.isEmpty ? 'Usuario Facebook' : fullName,
        email: email,
        phone: '',
      );

      // ============================================================
      // 7. GUARDAR USUARIO + TOKEN SANCTUM
      // ============================================================

      await SessionManager.instance.setCurrentUser(
        localUser,
      );

      await SessionManager.instance.setApiToken(
        sanctumToken,
      );

      print('==============================');
      print('SESIÓN FACEBOOK COMPLETADA');
      print('Usuario local ID: ${localUser.id}');
      print(
        'Token Sanctum guardado: ${sanctumToken.isNotEmpty}',
      );
      print('==============================');

      return localUser;
    } on FirebaseAuthException catch (error) {
      throw Exception(
        'Error de Firebase: '
        '${error.message ?? error.code}',
      );
    } catch (error) {
      throw Exception(
        'No fue posible iniciar sesión con Facebook: $error',
      );
    }
  }
}
