import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/user_model.dart';

class UserProvider extends ChangeNotifier {
  static const _claveSesionInvitado = 'chichej_sesion_invitado_id';
  static const avatarAdmin = 'assets/logochichej.png';

  UserModel? user;
  String? _sesionInvitadoId;

  bool get esInvitado => user?.tipoSesion == TipoSesion.invitado;

  bool get esRegistrado => user?.tipoSesion == TipoSesion.registrado;

  bool get esAdmin => user?.tipoSesion == TipoSesion.admin;

  bool get esAdminPrincipal => user?.rol == 'admin_principal';

  bool get esSubAdmin => user?.rol == 'admin';

  String? get uid => user?.uid;

  String? get sesionInvitadoId => esInvitado ? _sesionInvitadoId : null;

  void setUser(UserModel newUser) {
    if (newUser.rol == 'admin' || newUser.rol == 'admin_principal') {
      newUser.tipoSesion = TipoSesion.admin;
      newUser.avatarPath = avatarAdmin;
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
                databaseURL: "https://chichej-2026-default-rtdb.firebaseio.com")
            .ref("usuarios/${user!.uid}")
            .update({"nombre": nuevoNombre});
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
                  databaseURL:
                      "https://chichej-2026-default-rtdb.firebaseio.com")
              .ref("usuarios/${user!.uid}")
              .update({"avatarPath": nuevoAvatarPath});
        } catch (e) {
          debugPrint("Error guardando avatar: $e");
        }
      }

      notifyListeners();
    }
  }

  Future<bool> consumirMuestraGratis() async {
    if (!esRegistrado) {
      return false;
    }

    final String? usuarioUid =
        user?.uid ?? FirebaseAuth.instance.currentUser?.uid;

    if (usuarioUid == null || usuarioUid.isEmpty) {
      debugPrint('[MUESTRA] UID no disponible.');
      return false;
    }

    final DatabaseReference ref = FirebaseDatabase.instanceFor(
            app: Firebase.app(),
            databaseURL: "https://chichej-2026-default-rtdb.firebaseio.com")
        .ref('usuarios/$usuarioUid');

    try {
      // Primero obtenemos el estado real del servidor.
      final DataSnapshot snapshot = await ref.get();

      if (!snapshot.exists || snapshot.value is! Map) {
        debugPrint(
          '[MUESTRA] El perfil no existe en Realtime Database.',
        );
        return false;
      }

      final Map<dynamic, dynamic> datosServidorOriginales =
          snapshot.value as Map<dynamic, dynamic>;

      final Map<String, dynamic> datosServidor = {};

      datosServidorOriginales.forEach((key, value) {
        datosServidor[key.toString()] = value;
      });

      final int disponiblesServidor =
          (datosServidor['muestrasGratisDisponibles'] as num?)?.toInt() ?? 0;

      final int utilizadasServidor =
          (datosServidor['muestrasGratisUtilizadas'] as num?)?.toInt() ?? 0;

      debugPrint('========== MUESTRA GRATIS ==========');
      debugPrint('Email: ${user?.email}');
      debugPrint('UID: $usuarioUid');
      debugPrint(
        'Servidor antes -> disponibles: $disponiblesServidor | '
        'utilizadas: $utilizadasServidor',
      );
      debugPrint('====================================');

      if (disponiblesServidor <= 0) {
        debugPrint(
          '[MUESTRA] El usuario ya no tiene muestras disponibles.',
        );
        return false;
      }

      final TransactionResult resultado = await ref.runTransaction(
        (Object? valorActual) {
          Map<String, dynamic> datos;

          // Firebase puede entregar null en la primera ejecución
          // del callback aunque el nodo exista en el servidor.
          // En ese caso usamos la lectura que acabamos de realizar.
          if (valorActual == null) {
            datos = Map<String, dynamic>.from(datosServidor);
          } else if (valorActual is Map) {
            datos = {};

            valorActual.forEach((key, value) {
              datos[key.toString()] = value;
            });
          } else {
            return Transaction.abort();
          }

          final int disponibles =
              (datos['muestrasGratisDisponibles'] as num?)?.toInt() ?? 0;

          final int utilizadas =
              (datos['muestrasGratisUtilizadas'] as num?)?.toInt() ?? 0;

          if (disponibles <= 0) {
            return Transaction.abort();
          }

          datos['muestrasGratisDisponibles'] = disponibles - 1;

          datos['muestrasGratisUtilizadas'] = utilizadas + 1;

          return Transaction.success(datos);
        },
        applyLocally: false,
      );

      if (!resultado.committed) {
        debugPrint(
          '[MUESTRA] Firebase rechazó la transacción.',
        );
        return false;
      }

      user!.uid ??= usuarioUid;
      user!.muestrasGratisDisponibles =
          (user!.muestrasGratisDisponibles - 1).clamp(0, 999999);
      user!.muestrasGratisUtilizadas++;

      notifyListeners();

      debugPrint(
        '[MUESTRA] Consumida correctamente -> '
        'disponibles=${user!.muestrasGratisDisponibles}, '
        'utilizadas=${user!.muestrasGratisUtilizadas}',
      );

      return true;
    } catch (error) {
      debugPrint(
        '[MUESTRA] Error consumiendo muestra: $error',
      );
      return false;
    }
  }

  Future<void> devolverMuestraGratis() async {
    if (!esRegistrado) {
      return;
    }

    final String? usuarioUid =
        user?.uid ?? FirebaseAuth.instance.currentUser?.uid;

    if (usuarioUid == null || usuarioUid.isEmpty) {
      return;
    }

    final DatabaseReference ref = FirebaseDatabase.instanceFor(
            app: Firebase.app(),
            databaseURL: "https://chichej-2026-default-rtdb.firebaseio.com")
        .ref('usuarios/$usuarioUid');

    try {
      final TransactionResult resultado = await ref.runTransaction(
        (Object? valorActual) {
          if (valorActual is! Map) {
            return Transaction.abort();
          }

          final Map<String, dynamic> datos = {};

          valorActual.forEach((key, value) {
            datos[key.toString()] = value;
          });

          final int disponibles =
              (datos['muestrasGratisDisponibles'] as num?)?.toInt() ?? 0;

          final int utilizadas =
              (datos['muestrasGratisUtilizadas'] as num?)?.toInt() ?? 0;

          if (utilizadas <= 0) {
            return Transaction.abort();
          }

          datos['muestrasGratisDisponibles'] = disponibles + 1;

          datos['muestrasGratisUtilizadas'] = utilizadas - 1;

          return Transaction.success(datos);
        },
      );

      if (!resultado.committed) {
        return;
      }

      user!.muestrasGratisDisponibles++;

      if (user!.muestrasGratisUtilizadas > 0) {
        user!.muestrasGratisUtilizadas--;
      }

      notifyListeners();

      debugPrint(
        '[MUESTRA] Beneficio restaurado correctamente.',
      );
    } catch (error) {
      debugPrint(
        '[MUESTRA] Error devolviendo muestra: $error',
      );
    }
  }

  Future<void> logout() async {
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

      if (user!.rol == 'admin' || user!.rol == 'admin_principal') {
        user!.tipoSesion = TipoSesion.admin;
        user!.avatarPath = avatarAdmin;
      } else {
        user!.tipoSesion = TipoSesion.registrado;
      }
      notifyListeners();
    }
  }
}
