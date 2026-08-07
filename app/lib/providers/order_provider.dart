import 'package:chichej/screens/cart_item.dart';
import 'package:flutter/material.dart';
import '../models/order_model.dart';

class OrderProvider extends ChangeNotifier {
  List<Order> historial = [];

  // providers/order_provider.dart
  void agregarCompra(List<CartItem> carritoItems, double total) {
    List<OrderItem> itemsParaGuardar = carritoItems.map((c) => 
      OrderItem(producto: c.producto, cantidad: c.cantidad)
    ).toList();
    
    historial.add(Order(items: itemsParaGuardar, fecha: DateTime.now(), total: total));
    notifyListeners();
  }

  final List<Map<String, dynamic>> _reservas = [];
  
  List<Map<String, dynamic>> get reservas => _reservas;

  void registrarReserva(String evento, int cantidad, DateTime fecha, String telefono) {
    _reservas.add({
      'evento': evento,
      'cantidad': cantidad,
      'fecha': fecha,
      'telefono': telefono,
      'estado': 'Pendiente',
    });
    
    // AQUÍ SIMULAS EL MENSAJE AL ADMIN
    print("ADMIN NOTIFICADO: Nueva reserva de $cantidad unidades para el evento '$evento'. Contacto: $telefono");
    
    notifyListeners();
  }
}


  
