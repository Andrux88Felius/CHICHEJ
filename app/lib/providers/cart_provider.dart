import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../screens/cart_item.dart'; // Importa el nuevo modelo

class CartProvider extends ChangeNotifier {
  List<CartItem> carrito = [];

  int agregar(Product producto) {
    int index = carrito.indexWhere((item) => item.producto.nombre == producto.nombre);
    if (index != -1) {
      if(producto.esGratis && carrito[index].cantidad >= 1) {
        // No permitir incrementar si es gratis y ya hay uno en el carrito
        return carrito[index].cantidad; // Retornamos la cantidad actual sin cambios
      }
      carrito[index].cantidad++;
      notifyListeners();
      return carrito[index].cantidad; // Retornamos la nueva cantidad
    } else {
      carrito.add(CartItem(producto: producto, cantidad: 1));
      notifyListeners();
      return 1; // Primera vez que se agrega
    }
  }

  void decrementar(CartItem item) {
    if (item.cantidad > 1) {
      item.cantidad--;
    } else {
      carrito.remove(item);
    }
    notifyListeners();
  }

  void incrementar(CartItem item) {

    if(item.producto.esGratis && item.cantidad >= 1) {
      // No permitir incrementar si es gratis y ya hay uno en el carrito
      return;
    }
    item.cantidad++;
    notifyListeners();
  }

  void eliminar(CartItem item) {
    carrito.remove(item);
    notifyListeners();
  }

  double total() {
    return carrito.fold(0, (sum, item) => sum + item.subtotal);
  }

  void limpiar() {
    carrito.clear();
    notifyListeners();
  }
}