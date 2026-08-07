import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/user_model.dart';

class UserProvider extends ChangeNotifier {
  static const _claveSesionInvitado =
  'chichej_sesion_invitado_id';
  static const avatarAdmin =
  'assets/icon/logo_icon2.png';

  UserModel? user;
  String? _sesionInvitadoId;

  bool get esInvitado => 
  user?.tipoSesion == TipoSesion.invitado;

  bool get esRegistrado => 
  user?.tipoSesion == TipoSesion.registrado;

  bool get esAdmin => 
  user?.tipoSesion == TipoSesion.admin;

  String? get uid => user?.uid;

  String? get sesionInvitadoId =>
  esInvitado ? _sesionInvitadoId : null;

  void setUser(UserModel newUser) {
    if (newUser.tipoSesion == TipoSesion.admin) {
      newUser.avatarPath = avatarAdmin;
      newUser.rol = "admin";
    }
    user = newUser;
    notifyListeners();
  }


  void updateNombre(String nuevoNombre) {
    if (user != null) {
      user!.nombre = nuevoNombre;
      if (user!.uid != null) {
        FirebaseDatabase.instanceFor(
          app: Firebase.app(),
          databaseURL: "https://chichej-2026-default-rtdb.firebaseio.com"
        ).ref("usuarios/${user!.uid}").update({"nombre": nuevoNombre});
      }
      notifyListeners();
    }
  }

  Future<void> iniciarSesionInvitada() async {
    if (FirebaseAuth.instance.currentUser != null) {
      await FirebaseAuth.instance.signOut();
    }
  
    final preferencias = await SharedPreferences.getInstance();
    var id = preferencias.getString(_claveSesionInvitado);
  
    if (id == null || id.isEmpty) {
      final aleatorio = Random().nextInt(1 << 32);
      id = 'invitado_${DateTime.now().microsecondsSinceEpoch}_$aleatorio';
      await preferencias.setString(_claveSesionInvitado, id);
    }
  
    _sesionInvitadoId = id;
  
    user = UserModel(
      nombre: 'Invitado',
      email: '',
      tipoSesion: TipoSesion.invitado,
      muestrasGratisDisponibles: 0,
      muestrasGratisUtilizadas: 0,
      avatarPath: 'assets/avatares/invitado.png',
      rol: 'invitado',
    );
  
    notifyListeners();
  }

  Future<void> actualizarAvatar(String nuevoAvatarPath) async {
    if (user != null && !esAdmin && !esInvitado) {
      user!.avatarPath = nuevoAvatarPath;
      notifyListeners();
      
      // Guardar en Firebase para que se mantenga al cerrar sesión
      if (user!.uid != null) {
        try {
          await FirebaseDatabase.instanceFor(
            app: Firebase.app(),
            databaseURL: "https://chichej-2026-default-rtdb.firebaseio.com"
          ).ref("usuarios/${user!.uid}").update({"avatarPath": nuevoAvatarPath});
        } catch (e) {
          debugPrint("Error guardando avatar: $e");
        }
      }
      
      notifyListeners();
    }
  }

  void logout() async {
    if (esRegistrado || esAdmin) {
      await FirebaseAuth.instance.signOut();
    }
  
    user = null;
    _sesionInvitadoId = null;
    notifyListeners();
  }


  Future<void> cargarDatosUsuario(String uid) async {
    final ref = FirebaseDatabase.instance.ref("usuarios/$uid");
    final snapshot = await ref.get();

    if (snapshot.exists) {
      Map data = snapshot.value as Map;
      // Aquí actualizamos el modelo con lo que viene de Firebase
      user!.avatarPath = data['avatarPath'];
      user!.nombre = data['nombre'];
      user!.rol = data['rol'];
      user!.muestrasGratisDisponibles =
      (data['muestrasGratisDisponibles'] as num?)?.toInt() ?? 0;
      user!.muestrasGratisUtilizadas =
      (data['muestrasGratisUtilizadas'] as num?)?.toInt() ?? 0;

      if (user!.rol == "admin") {
        user!.tipoSesion = TipoSesion.admin;
        user!.avatarPath = avatarAdmin;
      } else {
        user!.tipoSesion = TipoSesion.registrado;
      }
      notifyListeners();
    }
  }
}