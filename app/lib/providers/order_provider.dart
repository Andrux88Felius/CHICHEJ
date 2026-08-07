import 'package:flutter/foundation.dart';

import '../models/order_model.dart';
import '../screens/cart_item.dart';

class OrderProvider extends ChangeNotifier {
  // ============================================================
  // HISTORIAL LOCAL LEGACY
  // ============================================================
  //
  // Se mantiene temporalmente porque CartPage todavía llama
  // agregarCompra().
  //
  // El historial oficial de compras ahora está en Firestore
  // y HistoryPage ya lo obtiene desde Firebase.
  // ============================================================

  final List<Order> historial = [];

  // ============================================================
  // RESERVAS / EVENTOS
  // ============================================================
  //
  // Por ahora permanecen locales.
  // La siguiente mejora será almacenarlas en Firebase.
  // ============================================================

  final List<Map<String, dynamic>> _reservas = [];

  List<Map<String, dynamic>> get reservas => List.unmodifiable(_reservas);

  void limpiarSesion() {
    historial.clear();
    _reservas.clear();

    notifyListeners();
  }

  void agregarCompra(
    List<CartItem> carritoItems,
    double total,
  ) {
    final List<OrderItem> itemsParaGuardar = carritoItems.map(
      (item) {
        return OrderItem(
          producto: item.producto,
          cantidad: item.cantidad,
        );
      },
    ).toList();

    historial.add(
      Order(
        items: itemsParaGuardar,
        fecha: DateTime.now(),
        total: total,
      ),
    );

    notifyListeners();
  }

  void registrarReserva(
    String evento,
    int cantidad,
    DateTime fecha,
    String telefono,
  ) {
    _reservas.add({
      'evento': evento,
      'cantidad': cantidad,
      'fecha': fecha,
      'telefono': telefono,
      'estado': 'Pendiente',
    });

    // Ya no usamos print().
    debugPrint(
      'ADMIN NOTIFICADO: '
      'Nueva reserva de $cantidad unidades '
      'para "$evento". '
      'Contacto: $telefono',
    );

    notifyListeners();
  }
}
