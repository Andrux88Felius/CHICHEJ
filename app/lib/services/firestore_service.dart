import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<String> crearPedido({

    required String usuarioId,
    required String nombre,
    required String email,

    required String producto,
    required int opcion,

    required int cantidad,

    required double precio,

    required String metodoPago,

  }) async {

    final doc = await _db.collection("pedidos").add({

      "usuarioId": usuarioId,

      "nombre": nombre,

      "email": email,

      "producto": producto,

      "opcion": opcion,

      "cantidad": cantidad,

      "precio": precio,

      "metodoPago": metodoPago,

      "estado": "pendiente",

      "fecha": FieldValue.serverTimestamp(),

    });

    return doc.id;

  }

}