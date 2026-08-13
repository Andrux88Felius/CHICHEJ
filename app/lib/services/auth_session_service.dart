import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';
import '../providers/user_provider.dart';

class AuthSessionResult {
  final UserModel? user;
  final bool blocked;

  const AuthSessionResult({this.user, this.blocked = false});
}

class AuthSessionService {
  static const String _key = 'mantenerSesion';
  static const String _databaseUrl =
      'https://chichej-2026-default-rtdb.firebaseio.com';

  static Future<bool> keepSessionEnabled() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_key) ?? false;
  }

  static Future<void> setKeepSession(bool value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_key, value);
  }

  static Future<AuthSessionResult> loadCurrentUser() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return const AuthSessionResult();

    final database = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: _databaseUrl,
    );
    final snapshot = await database.ref('usuarios/${firebaseUser.uid}').get();
    if (!snapshot.exists || snapshot.value is! Map) {
      return const AuthSessionResult();
    }

    final data = Map<String, dynamic>.from(snapshot.value as Map);
    if (data['bloqueado'] == true) {
      return const AuthSessionResult(blocked: true);
    }

    final role = data['rol']?.toString() ?? 'cliente';
    final isAdmin = role == 'admin' || role == 'admin_principal';
    return AuthSessionResult(
      user: UserModel(
        uid: firebaseUser.uid,
        nombre: data['nombre']?.toString() ?? 'Usuario',
        email: firebaseUser.email ?? data['email']?.toString() ?? '',
        tipoSesion: isAdmin ? TipoSesion.admin : TipoSesion.registrado,
        muestrasGratisDisponibles:
            (data['muestrasGratisDisponibles'] as num?)?.toInt() ?? 0,
        muestrasGratisUtilizadas:
            (data['muestrasGratisUtilizadas'] as num?)?.toInt() ?? 0,
        avatarPath: isAdmin
            ? UserProvider.avatarAdmin
            : data['avatarPath']?.toString() ?? 'assets/avatares/invitado.png',
        rol: role,
      ),
    );
  }
}
