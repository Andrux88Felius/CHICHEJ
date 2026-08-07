import '../models/product_model.dart';

class CartItem {
  final Product producto;
  int cantidad;

  CartItem({
    required this.producto,
    this.cantidad = 1,
  });

  double get subtotal => producto.precio * cantidad;
}
