import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart' as fb_db;

class AdminService {
  static const String _databaseUrl =
      'https://chichej-2026-default-rtdb.firebaseio.com';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  fb_db.FirebaseDatabase get _database {
    return fb_db.FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: _databaseUrl,
    );
  }

  late final Stream<fb_db.DatabaseEvent> _usuariosStream =
      _database.ref('usuarios').onValue.asBroadcastStream();

  Stream<fb_db.DatabaseEvent> observarUsuarios() {
    return _usuariosStream;
  }

  Future<void> regalarMuestra({
    required String uid,
    int cantidad = 1,
  }) async {
    if (cantidad <= 0) {
      throw ArgumentError(
        'La cantidad debe ser mayor a cero.',
      );
    }

    final fb_db.DatabaseReference ref = _database.ref('usuarios/$uid');

    final fb_db.DataSnapshot snapshot = await ref.get();

    if (!snapshot.exists || snapshot.value is! Map) {
      throw StateError(
        'El usuario no existe en Realtime Database.',
      );
    }

    final Map<dynamic, dynamic> datosOriginales =
        snapshot.value as Map<dynamic, dynamic>;

    final Map<String, dynamic> datosServidor = {};

    datosOriginales.forEach((key, value) {
      datosServidor[key.toString()] = value;
    });

    final fb_db.TransactionResult resultado = await ref.runTransaction(
      (Object? valorActual) {
        Map<String, dynamic> datos;

        if (valorActual == null) {
          datos = Map<String, dynamic>.from(
            datosServidor,
          );
        } else if (valorActual is Map) {
          datos = {};

          valorActual.forEach((key, value) {
            datos[key.toString()] = value;
          });
        } else {
          return fb_db.Transaction.abort();
        }

        final int disponibles =
            (datos['muestrasGratisDisponibles'] as num?)?.toInt() ?? 0;

        datos['muestrasGratisDisponibles'] = disponibles + cantidad;

        return fb_db.Transaction.success(datos);
      },
      applyLocally: false,
    );

    if (!resultado.committed) {
      throw StateError(
        'Firebase no pudo asignar la muestra gratuita.',
      );
    }
  }

  Future<void> cambiarRol({
    required String uid,
    required String nuevoRol,
  }) async {
    const Set<String> rolesPermitidos = {
      'cliente',
      'admin',
    };

    if (!rolesPermitidos.contains(nuevoRol)) {
      throw ArgumentError(
        'Rol no permitido: $nuevoRol',
      );
    }

    await _database.ref('usuarios/$uid').update({
      'rol': nuevoRol,
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> observarPedidos() {
    return _firestore
        .collection('pedidos')
        .orderBy(
          'fechaCreacion',
          descending: true,
        )
        .snapshots();
  }
}
