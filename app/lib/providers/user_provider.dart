import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/user_model.dart';

class UserProvider extends ChangeNotifier {
  UserModel? user;

  void setUser(UserModel newUser) {
    user = newUser;
    notifyListeners();
  }

  // Método para actualizar nombre en memoria y Firebase
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

  // MÉTODO NUEVO: Actualizar Avatar
  Future<void> actualizarAvatar(String nuevoAvatarPath) async {
    if (user != null) {
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

  void logout() {
    user = null;
    notifyListeners();
  }

  // En tu UserProvider.dart, agrega esto:
Future<void> cargarDatosUsuario(String uid) async {
  final ref = FirebaseDatabase.instance.ref("usuarios/$uid");
  final snapshot = await ref.get();
  
  if (snapshot.exists) {
    Map data = snapshot.value as Map;
    // Aquí actualizamos el modelo con lo que viene de Firebase
    user!.avatarPath = data['avatarPath'];
    user!.nombre = data['nombre'];
    user!.rol = data['rol'];
    notifyListeners();
  }
}
}