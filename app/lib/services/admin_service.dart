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

  Stream<QuerySnapshot<Map<String, dynamic>>> observarPedidos() {
    return _firestore
        .collection('pedidos')
        .orderBy(
          'fechaCreacion',
          descending: true,
        )
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> observarAuditoria() {
    return _firestore
        .collection('auditoria_admin')
        .orderBy(
          'fecha',
          descending: true,
        )
        .limit(100)
        .snapshots();
  }

  Future<void> registrarAuditoria({
    required String accion,
    required String adminUid,
    required String adminNombre,
    required String adminRol,
    String? descripcion,
    String? usuarioUid,
    String? usuarioNombre,
    String? productoId,
    String? productoNombre,
    dynamic valorAnterior,
    dynamic valorNuevo,
    int? cantidad,
  }) async {
    await _firestore.collection('auditoria_admin').add({
      'accion': accion,
      'fecha': FieldValue.serverTimestamp(),
      'adminUid': adminUid,
      'adminNombre': adminNombre,
      'adminRol': adminRol,
      'descripcion': descripcion,
      'usuarioUid': usuarioUid,
      'usuarioNombre': usuarioNombre,
      'productoId': productoId,
      'productoNombre': productoNombre,
      'valorAnterior': valorAnterior,
      'valorNuevo': valorNuevo,
      'cantidad': cantidad,
    });
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

  // ============================================================
  // MENSAJES GENERALES CHICHEJ
  // ============================================================
  
  Stream<QuerySnapshot<Map<String, dynamic>>> observarMensajes() {
    return _firestore
        .collection('mensajes')
        .orderBy(
          'fechaCreacion',
          descending: true,
        )
        .snapshots();
  }
  
  Future<String> crearMensaje({
    required String titulo,
    required String mensaje,
    required String creadoPorUid,
    required String creadoPorNombre,
  }) async {
    final String tituloLimpio = titulo.trim();
    final String mensajeLimpio = mensaje.trim();
  
    if (tituloLimpio.isEmpty) {
      throw ArgumentError(
        'El título no puede estar vacío.',
      );
    }
  
    if (mensajeLimpio.isEmpty) {
      throw ArgumentError(
        'El mensaje no puede estar vacío.',
      );
    }
  
    final DocumentReference<Map<String, dynamic>> documento =
        await _firestore.collection('mensajes').add({
      'titulo': tituloLimpio,
      'mensaje': mensajeLimpio,
      'tipo': 'general',
      'activo': true,
      'fechaCreacion': FieldValue.serverTimestamp(),
      'creadoPorUid': creadoPorUid,
      'creadoPorNombre': creadoPorNombre,
    });
  
    return documento.id;
  }
  
  Future<void> cambiarEstadoMensaje({
    required String mensajeId,
    required bool activo,
  }) async {
    await _firestore.collection('mensajes').doc(mensajeId).update({
      'activo': activo,
      'fechaActualizacion': FieldValue.serverTimestamp(),
    });
  }
  
  Future<void> eliminarMensaje({
    required String mensajeId,
  }) async {
    await _firestore.collection('mensajes').doc(mensajeId).delete();
  }
}
