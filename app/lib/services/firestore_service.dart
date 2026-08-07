import 'package:cloud_firestore/cloud_firestore.dart';

import '../screens/cart_item.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<String> crearPedido({
    required String tipoUsuario,
    required String? usuarioId,
    required String? sesionInvitadoId,
    required String nombreUsuario,
    required String email,
    required List<CartItem> items,
    required String metodoPago,
    required String estadoPago,
  }) async {
    if (items.isEmpty) {
      throw ArgumentError('El pedido no puede estar vacío.');
    }

    final double total = items.fold<double>(
      0,
      (acumulador, item) => acumulador + item.subtotal,
    );

    final int cantidadItems = items.fold<int>(
      0,
      (acumulador, item) => acumulador + item.cantidad,
    );

    final int cantidadTotalMl = items.fold<int>(
      0,
      (acumulador, item) =>
          acumulador + (item.producto.cantidadMl * item.cantidad),
    );

    final pedidoRef = _db.collection('pedidos').doc();

    final itemsFirestore = items.map((item) {
      return {
        'productoId': item.producto.productoId,
        'bebidaId': item.producto.bebidaId,
        'tipoBebida': item.producto.tipoBebida,
        'nombre': item.producto.nombre,
        'cantidadMl': item.producto.cantidadMl,
        'opcion': item.producto.option,
        'precioUnitario': item.producto.precio,
        'cantidad': item.cantidad,
        'subtotal': item.subtotal,
        'esGratis': item.producto.esGratis,
      };
    }).toList();

    await pedidoRef.set({
      'pedidoId': pedidoRef.id,
      'tipoUsuario': tipoUsuario,
      'usuarioId': usuarioId,
      'sesionInvitadoId': sesionInvitadoId,
      'nombreUsuario': nombreUsuario,
      'email': email,
      'items': itemsFirestore,
      'cantidadItems': cantidadItems,
      'cantidadTotalMl': cantidadTotalMl,
      'subtotal': total,
      'total': total,
      'metodoPago': metodoPago,
      'estadoPago': estadoPago,
      'estado': 'pendiente',
      'procesado': false,
      'fechaCreacion': FieldValue.serverTimestamp(),
      'fechaProcesado': null,
      'fechaEntregado': null,
    });

    return pedidoRef.id;
  }

  Future<void> actualizarEstadoPedido({
    required String pedidoId,
    required String estado,
  }) async {
    final datos = <String, dynamic>{
      'estado': estado,
    };

    if (estado == 'procesando') {
      datos['procesado'] = true;
      datos['fechaProcesado'] = FieldValue.serverTimestamp();
    }

    if (estado == 'entregado') {
      datos['procesado'] = true;
      datos['fechaEntregado'] = FieldValue.serverTimestamp();
    }

    await _db.collection('pedidos').doc(pedidoId).update(datos);
  }

  Future<void> actualizarEstadoPago({
    required String pedidoId,
    required String estadoPago,
  }) async {
    await _db.collection('pedidos').doc(pedidoId).update({
      'estadoPago': estadoPago,
    });
  }
}
