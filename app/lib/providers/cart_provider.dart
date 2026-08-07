import 'package:flutter/material.dart';

import '../models/product_model.dart';
import '../screens/cart_item.dart';

class CartProvider extends ChangeNotifier {
  final List<CartItem> carrito = [];

  int agregar(
    Product producto, {
    bool permitirMultiplesGratis = false,
  }) {
    final index = carrito.indexWhere(
      (item) => item.producto.productoId == producto.productoId,
    );

    if (index != -1) {
      if (producto.esGratis &&
          !permitirMultiplesGratis &&
          carrito[index].cantidad >= 1) {
        return carrito[index].cantidad;
      }

      carrito[index].cantidad++;
      notifyListeners();

      return carrito[index].cantidad;
    }

    carrito.add(
      CartItem(
        producto: producto,
        cantidad: 1,
      ),
    );

    notifyListeners();
    return 1;
  }

  void decrementar(CartItem item) {
    if (item.cantidad > 1) {
      item.cantidad--;
    } else {
      carrito.remove(item);
    }

    notifyListeners();
  }

  void incrementar(
    CartItem item, {
    bool permitirMultiplesGratis = false,
  }) {
    if (item.producto.esGratis &&
        !permitirMultiplesGratis &&
        item.cantidad >= 1) {
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
    return carrito.fold<double>(
      0,
      (acumulado, item) => acumulado + item.subtotal,
    );
  }

  int cantidadItems() {
    return carrito.fold<int>(
      0,
      (acumulado, item) => acumulado + item.cantidad,
    );
  }

  int cantidadTotalMl() {
    return carrito.fold<int>(
      0,
      (acumulado, item) =>
          acumulado + (item.producto.cantidadMl * item.cantidad),
    );
  }

  bool get contieneMuestraGratis {
    return carrito.any(
      (item) => item.producto.esGratis,
    );
  }

  void limpiar() {
    carrito.clear();
    notifyListeners();
  }
}
