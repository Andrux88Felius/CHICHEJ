import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

class DispenserService {
  static const String _databaseUrl =
      'https://chichej-2026-default-rtdb.firebaseio.com';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  FirebaseDatabase get _database {
    return FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: _databaseUrl,
    );
  }

  // ============================================================
  // PEDIDOS FIRESTORE
  // ============================================================

  Stream<QuerySnapshot<Map<String, dynamic>>> observarPedidosPendientes() {
    return _firestore
        .collection('pedidos')
        .where(
          'estado',
          isEqualTo: 'pendiente',
        )
        .snapshots()
        .asBroadcastStream();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> observarPedidosProcesando() {
    return _firestore
        .collection('pedidos')
        .where(
          'estado',
          isEqualTo: 'procesando',
        )
        .snapshots()
        .asBroadcastStream();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> observarPedidosRecientes() {
    return _firestore
        .collection('pedidos')
        .orderBy(
          'fechaCreacion',
          descending: true,
        )
        .snapshots()
        .asBroadcastStream();
  }

  // ============================================================
  // ESTADO EN VIVO - REALTIME DATABASE
  // ============================================================

  Stream<DatabaseEvent> observarEstadoDispensador() {
    return _database.ref('dispensador/principal').onValue.asBroadcastStream();
  }

  Future<void> cancelarPedido({
    required String pedidoId,
  }) async {
    await _firestore.collection('pedidos').doc(pedidoId).update({
      'estado': 'cancelado',
      'procesado': true,
      'fechaCancelado': FieldValue.serverTimestamp(),
      'canceladoPor': 'admin',
    });
  }

  Future<void> reanudarPedido({required String pedidoId}) async {
    final referencia = _firestore.collection('pedidos').doc(pedidoId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(referencia);
      final data = snapshot.data();
      final esPedidoFisico = data?['tipoUsuario'] == 'fisico' ||
          data?['origenPedido'] == 'pulsador';
      final esDispensacionAdministrativa = data?['metodoPago'] == 'admin' ||
          data?['estadoPago'] == 'no_requerido';
      if (!snapshot.exists ||
          data?['estado'] != 'cancelado' ||
          esPedidoFisico ||
          esDispensacionAdministrativa) {
        throw StateError('Solo se pueden reanudar pedidos cancelados.');
      }
      transaction.update(referencia, {
        'estado': 'pendiente',
        'procesado': false,
        'fechaProcesado': null,
        'fechaEntregado': null,
        'fechaReanudado': FieldValue.serverTimestamp(),
        'reanudadoPor': 'admin',
        'fechaCancelado': FieldValue.delete(),
        'canceladoPor': FieldValue.delete(),
      });
    });
  }

  Future<void> bloquearUsuario({
    required String uid,
    required bool bloqueado,
  }) async {
    await _database.ref('usuarios/$uid').update({
      'bloqueado': bloqueado,
      'fechaBloqueo': ServerValue.timestamp,
    });
  }

  Future<bool> usuarioEstaBloqueado({
    required String uid,
  }) async {
    final DataSnapshot snapshot =
        await _database.ref('usuarios/$uid/bloqueado').get();

    if (!snapshot.exists) {
      return false;
    }

    return snapshot.value == true;
  }
}
