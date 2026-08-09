import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../data/product_data.dart';
import '../models/product_model.dart';

class ProductService {
  ProductService({
    FirebaseFirestore? firestore,
  }) : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _productosRef =>
      _db.collection('productos');

  // ============================================================
  // LEER PRODUCTOS
  // ============================================================

  Future<List<Product>> obtenerProductos() async {
    try {
      final snapshot = await _productosRef.get();

      if (snapshot.docs.isEmpty) {
        return List<Product>.from(
          productosFallback,
        );
      }

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

      if (productos.isEmpty) {
        return List<Product>.from(
          productosFallback,
        );
      }

      productos.sort(
        (a, b) => a.option.compareTo(
          b.option,
        ),
      );

      return productos;
    } catch (error) {
      debugPrint(
        '[PRODUCTOS] Firestore no disponible. '
        'Usando catálogo local: $error',
      );

      return List<Product>.from(
        productosFallback,
      );
    }
  }

  Stream<List<Product>> observarProductos() {
    return _productosRef.snapshots().map(
      (snapshot) {
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
          (a, b) => a.option.compareTo(
            b.option,
          ),
        );

        return productos;
      },
    );
  }

  // ============================================================
  // CREAR PRODUCTO
  // ============================================================

  Future<String> crearProducto({
    required String nombre,
    required String descripcion,
    required String tipoBebida,
    required int cantidadMl,
    required double precio,
    required String imagen,
    required int opcion,
    bool esGratis = false,
  }) async {
    final String nombreLimpio =
        nombre.trim();

    if (nombreLimpio.isEmpty) {
      throw ArgumentError(
        'El nombre no puede estar vacío.',
      );
    }

    if (cantidadMl <= 0) {
      throw ArgumentError(
        'La cantidad debe ser mayor a cero.',
      );
    }

    if (precio < 0) {
      throw ArgumentError(
        'El precio no puede ser negativo.',
      );
    }

    final documento =
        _productosRef.doc();

    await documento.set({
      'productoId': documento.id,
      'bebidaId': tipoBebida
          .trim()
          .toLowerCase()
          .replaceAll(' ', '_'),
      'tipoBebida':
          tipoBebida.trim(),
      'cantidadMl': cantidadMl,
      'nombre': nombreLimpio,
      'descripcion':
          descripcion.trim(),
      'precio':
          esGratis ? 0.0 : precio,
      'imagen': imagen,
      'opcion': opcion,
      'esGratis': esGratis,
      'activo': true,
      'agotado': false,
      'creadoEn':
          FieldValue.serverTimestamp(),
      'actualizadoEn':
          FieldValue.serverTimestamp(),
    });

    return documento.id;
  }

  // ============================================================
  // EDITAR PRODUCTO
  // ============================================================

  Future<void> actualizarProducto({
    required String productoId,
    required String nombre,
    required String descripcion,
    required String tipoBebida,
    required int cantidadMl,
    required double precio,
    required String imagen,
    required int opcion,
    required bool esGratis,
    required bool activo,
    required bool agotado,
  }) async {
    if (nombre.trim().isEmpty) {
      throw ArgumentError(
        'El nombre no puede estar vacío.',
      );
    }

    if (cantidadMl <= 0) {
      throw ArgumentError(
        'La cantidad debe ser mayor a cero.',
      );
    }

    if (precio < 0) {
      throw ArgumentError(
        'El precio no puede ser negativo.',
      );
    }

    await _productosRef
        .doc(productoId)
        .update({
      'nombre': nombre.trim(),
      'descripcion':
          descripcion.trim(),
      'tipoBebida':
          tipoBebida.trim(),
      'bebidaId': tipoBebida
          .trim()
          .toLowerCase()
          .replaceAll(' ', '_'),
      'cantidadMl':
          cantidadMl,
      'precio':
          esGratis ? 0.0 : precio,
      'imagen': imagen,
      'opcion': opcion,
      'esGratis': esGratis,
      'activo': activo,
      'agotado': agotado,
      'actualizadoEn':
          FieldValue.serverTimestamp(),
    });
  }

  // ============================================================
  // PRECIO
  // ============================================================

  Future<void> actualizarPrecio({
    required String productoId,
    required double nuevoPrecio,
  }) async {
    if (nuevoPrecio < 0) {
      throw ArgumentError(
        'El precio no puede ser negativo.',
      );
    }

    await _productosRef
        .doc(productoId)
        .update({
      'precio': nuevoPrecio,
      'actualizadoEn':
          FieldValue.serverTimestamp(),
    });
  }

  // ============================================================
  // DISPONIBILIDAD
  // ============================================================

  Future<void> cambiarAgotado({
    required String productoId,
    required bool agotado,
  }) async {
    await _productosRef
        .doc(productoId)
        .update({
      'agotado': agotado,
      'actualizadoEn':
          FieldValue.serverTimestamp(),
    });
  }

  Future<void> cambiarActivo({
    required String productoId,
    required bool activo,
  }) async {
    await _productosRef
        .doc(productoId)
        .update({
      'activo': activo,
      'actualizadoEn':
          FieldValue.serverTimestamp(),
    });
  }

  // ============================================================
  // ELIMINAR PRODUCTO
  // ============================================================

  Future<void> eliminarProducto({
    required String productoId,
  }) async {
    await _productosRef
        .doc(productoId)
        .delete();
  }
}