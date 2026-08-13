import 'package:cloud_firestore/cloud_firestore.dart';

class ReservationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _ref =>
      _db.collection('reservas');

  Future<String> create({
    required String clientName,
    required String phone,
    required String email,
    required String detail,
    required String requestedQuantity,
    required DateTime requestedDate,
    required String userId,
    required String eventPlace,
    required String address,
    required String locationReferences,
    String observations = '',
  }) async {
    final legacyQuantity = int.tryParse(requestedQuantity.trim());
    final document = _ref.doc();
    await document.set({
      'reservaId': document.id,
      'usuarioId': userId,
      'nombreCliente': clientName.trim(),
      'telefono': phone.trim(),
      'email': email.trim(),
      'detalle': detail.trim(),
      if (legacyQuantity != null) 'cantidad': legacyQuantity,
      'cantidadSolicitada': requestedQuantity.trim(),
      'fechaSolicitada': Timestamp.fromDate(requestedDate),
      'lugarEvento': eventPlace.trim(),
      'direccion': address.trim(),
      'referenciasLugar': locationReferences.trim(),
      'observaciones': observations.trim(),
      'fechaCreacion': FieldValue.serverTimestamp(),
      'estado': 'pendiente',
    });
    return document.id;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchAll() =>
      _ref.orderBy('fechaCreacion', descending: true).snapshots();

  Future<void> updateStatus(String id, String status) async {
    const allowed = {
      'pendiente',
      'aceptada',
      'rechazada',
      'completada',
      'cancelada',
    };
    if (!allowed.contains(status)) throw ArgumentError('Estado no válido');
    await _ref.doc(id).update({
      'estado': status,
      'fechaActualizacion': FieldValue.serverTimestamp(),
    });
  }
}
