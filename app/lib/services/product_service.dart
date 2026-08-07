import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../data/product_data.dart';
import '../models/product_model.dart';

class ProductService {
  ProductService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _productosRef =>
      _db.collection('productos');

  Future<List<Product>> obtenerProductos() async {
    try {
      final snapshot = await _productosRef.get();

      if (snapshot.docs.isEmpty) {
        return List<Product>.from(productosFallback);
      }

      final productos = <Product>[];

      for (final doc in snapshot.docs) {
        try {
          final producto = Product.fromMap(
            doc.data(),
            documentId: doc.id,
          );

          productos.add(producto);
        } catch (error) {
          debugPrint(
            '[PRODUCTOS] Documento inválido ${doc.id}: $error',
          );
        }
      }

      if (productos.isEmpty) {
        return List<Product>.from(productosFallback);
      }

      productos.sort(
        (a, b) => a.option.compareTo(b.option),
      );

      return productos;
    } catch (error) {
      debugPrint(
        '[PRODUCTOS] Firestore no disponible. '
        'Usando catálogo local: $error',
      );

      return List<Product>.from(productosFallback);
    }
  }

  Stream<List<Product>> observarProductos() {
    return _productosRef.snapshots().map((snapshot) {
      final productos = <Product>[];

      for (final doc in snapshot.docs) {
        try {
          productos.add(
            Product.fromMap(
              doc.data(),
              documentId: doc.id,
            ),
          );
        } catch (error) {
          debugPrint(
            '[PRODUCTOS] Documento inválido ${doc.id}: $error',
          );
        }
      }

      productos.sort(
        (a, b) => a.option.compareTo(b.option),
      );

      return productos;
    });
  }

  Future<void> actualizarPrecio({
    required String productoId,
    required double nuevoPrecio,
  }) async {
    if (nuevoPrecio < 0) {
      throw ArgumentError(
        'El precio no puede ser negativo.',
      );
    }

    await _productosRef.doc(productoId).update({
      'precio': nuevoPrecio,
      'actualizadoEn': FieldValue.serverTimestamp(),
    });
  }
}
