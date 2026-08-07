// models/order_model.dart
import '../models/product_model.dart';

class OrderItem {
  final Product producto;
  final int cantidad;
  OrderItem({required this.producto, required this.cantidad});
}

class Order {
  List<OrderItem> items; // Ahora guardamos items con cantidad
  DateTime fecha;
  double total;

  Order({required this.items, required this.fecha, required this.total});
}