import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'firestore_service.dart';
import 'printer_service.dart';

class OrderTicketService {
  OrderTicketService._();

  static final OrderTicketService instance =
      OrderTicketService._();

  final FirebaseFirestore _db =
      FirebaseFirestore.instance;

  final FirestoreService _firestoreService =
      FirestoreService();

  final Map<
      String,
      StreamSubscription<
          DocumentSnapshot<Map<String, dynamic>>>> _listeners = {};

  final Set<String> _automaticAttemptedOrders = {};

  void watchOrder(String pedidoId) {
    if (pedidoId.trim().isEmpty) {
      return;
    }

    if (_listeners.containsKey(pedidoId)) {
      return;
    }

    debugPrint(
      '[OrderTicketService] Observando pedido: $pedidoId',
    );

    final subscription = _db
        .collection('pedidos')
        .doc(pedidoId)
        .snapshots()
        .listen(
      (snapshot) async {
        if (!snapshot.exists) {
          return;
        }

        final data = snapshot.data();

        if (data == null) {
          return;
        }

        final String estado =
            data['estado']
                ?.toString()
                .trim()
                .toLowerCase() ??
            '';

        final bool ticketImpreso =
            data['ticketImpreso'] == true;

        debugPrint(
          '[OrderTicketService] '
          '$pedidoId -> estado=$estado '
          'ticketImpreso=$ticketImpreso',
        );

        if (estado != 'entregado') {
          return;
        }

        if (ticketImpreso) {
          await stopWatching(pedidoId);
          return;
        }

        if (_automaticAttemptedOrders.contains(pedidoId)) {
          return;
        }

        _automaticAttemptedOrders.add(pedidoId);

        await _printDeliveredOrder(
          pedidoId: pedidoId,
          data: data,
        );
      },
      onError: (Object error) {
        debugPrint(
          '[OrderTicketService] '
          'Error observando $pedidoId: $error',
        );
      },
    );

    _listeners[pedidoId] = subscription;
  }

  Future<void> _printDeliveredOrder({
    required String pedidoId,
    required Map<String, dynamic> data,
  }) async {
    try {
      final String customerName =
          data['nombreUsuario']
              ?.toString()
              .trim() ??
          '';

      final String nombreCliente =
          customerName.isEmpty
              ? 'Invitado'
              : customerName;

      final dynamic rawItems =
          data['items'];

      if (rawItems is! List ||
          rawItems.isEmpty) {
        debugPrint(
          '[OrderTicketService] '
          'Pedido $pedidoId sin items válidos.',
        );

        await _firestoreService
            .registrarIntentoImpresionFallido(
          pedidoId: pedidoId,
        );

        await stopWatching(pedidoId);
        return;
      }

      final List<PrinterOrderItem>
          printerItems = [];

      for (final rawItem in rawItems) {
        if (rawItem is! Map) {
          continue;
        }

        final map =
            Map<String, dynamic>.from(
          rawItem,
        );

        final String productName =
            map['nombre']
                ?.toString()
                .trim() ??
            'Producto';

        final int quantityMl =
            _toInt(
          map['cantidadMl'],
        );

        final int cantidad =
            _toInt(
          map['cantidad'],
        );

        final double precioUnitario =
            _toDouble(
          map['precioUnitario'],
        );

        final int cantidadSegura =
            cantidad <= 0
                ? 1
                : cantidad;

        final int totalMl =
            quantityMl *
                cantidadSegura;

        final double subtotal =
            map['subtotal'] != null
                ? _toDouble(
                    map['subtotal'],
                  )
                : precioUnitario *
                    cantidadSegura;

        printerItems.add(
          PrinterOrderItem(
            productName:
                cantidadSegura > 1
                    ? '$productName x$cantidadSegura'
                    : productName,
            quantityMl:
                totalMl,
            price:
                subtotal,
          ),
        );
      }

      if (printerItems.isEmpty) {
        debugPrint(
          '[OrderTicketService] '
          'Pedido $pedidoId sin items imprimibles.',
        );

        await _firestoreService
            .registrarIntentoImpresionFallido(
          pedidoId: pedidoId,
        );

        await stopWatching(pedidoId);
        return;
      }

      DateTime ticketDate =
          DateTime.now();

      final dynamic fechaEntregado =
          data['fechaEntregado'];

      if (fechaEntregado is Timestamp) {
        ticketDate =
            fechaEntregado.toDate();
      } else {
        final dynamic fechaCreacion =
            data['fechaCreacion'];

        if (fechaCreacion is Timestamp) {
          ticketDate =
              fechaCreacion.toDate();
        }
      }

      final String shortOrderId =
          _formatOrderId(
        pedidoId,
      );

      debugPrint(
        '[OrderTicketService] '
        'Imprimiendo pedido $pedidoId...',
      );

      final bool printed =
          await PrinterService.instance
              .printOrder(
        customerName:
            nombreCliente,
        orderId:
            shortOrderId,
        items:
            printerItems,
        dateTime:
            ticketDate,
      );

      if (printed) {
        await _firestoreService
            .marcarTicketImpreso(
          pedidoId: pedidoId,
        );

        debugPrint(
          '[OrderTicketService] '
          'Ticket $pedidoId impreso correctamente.',
        );
      } else {
        await _firestoreService
            .registrarIntentoImpresionFallido(
          pedidoId: pedidoId,
        );

        debugPrint(
          '[OrderTicketService] '
          'No se pudo imprimir $pedidoId: '
          '${PrinterService.instance.status}',
        );
      }

      await stopWatching(
        pedidoId,
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[OrderTicketService] '
        'Error procesando $pedidoId: $error',
      );

      debugPrint(
        '$stackTrace',
      );

      try {
        await _firestoreService
            .registrarIntentoImpresionFallido(
          pedidoId: pedidoId,
        );
      } catch (_) {}

      await stopWatching(
        pedidoId,
      );
    }
  }

  Future<bool> reprintOrder(
    String pedidoId,
  ) async {
    try {
      final snapshot = await _db
          .collection('pedidos')
          .doc(pedidoId)
          .get();

      if (!snapshot.exists) {
        return false;
      }

      final data = snapshot.data();

      if (data == null) {
        return false;
      }

      final String estado =
          data['estado']
              ?.toString()
              .trim()
              .toLowerCase() ??
          '';

      if (estado != 'entregado') {
        return false;
      }

      await _printDeliveredOrder(
        pedidoId: pedidoId,
        data: data,
      );

      return true;
    } catch (e) {
      debugPrint(
        '[OrderTicketService] '
        'Error reimprimiendo $pedidoId: $e',
      );

      return false;
    }
  }

  Future<void> recoverPendingTickets() async {
    try {
      debugPrint(
        '[OrderTicketService] Buscando tickets pendientes...',
      );

      final snapshot = await _db
          .collection('pedidos')
          .where('estado', isEqualTo: 'entregado')
          .where('ticketImpreso', isEqualTo: false)
          .limit(10)
          .get();

      if (snapshot.docs.isEmpty) {
        debugPrint(
          '[OrderTicketService] No existen tickets pendientes.',
        );
        return;
      }

      debugPrint(
        '[OrderTicketService] '
        'Tickets pendientes encontrados: ${snapshot.docs.length}',
      );

      for (final document in snapshot.docs) {
        final data = document.data();

        final String tipoUsuario =
            data['tipoUsuario']
                ?.toString()
                .trim()
                .toLowerCase() ??
            '';

        if (tipoUsuario == 'admin') {
          debugPrint(
            '[OrderTicketService] '
            'Pedido administrativo ${document.id}: '
            'no requiere ticket.',
          );

          continue;
        }

        final pedidoId = document.id;

        if (_automaticAttemptedOrders.contains(pedidoId)) {
          continue;
        }

        _automaticAttemptedOrders.add(pedidoId);

        await _printDeliveredOrder(
          pedidoId: pedidoId,
          data: data,
        );

        await Future.delayed(
          const Duration(milliseconds: 500),
        );
      }
    } catch (error) {
      debugPrint(
        '[OrderTicketService] '
        'Error recuperando tickets pendientes: $error',
      );
    }
  }

  Future<void> stopWatching(
    String pedidoId,
  ) async {
    final subscription =
        _listeners.remove(
      pedidoId,
    );

    await subscription?.cancel();

    debugPrint(
      '[OrderTicketService] '
      'Listener cerrado: $pedidoId',
    );
  }

  Future<void> stopAll() async {
    final subscriptions =
        _listeners.values.toList();

    _listeners.clear();

    for (final subscription
        in subscriptions) {
      await subscription.cancel();
    }
  }

  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  double _toDouble(dynamic value) {
    if (value is double) {
      return value;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  String _formatOrderId(
    String pedidoId,
  ) {
    final cleaned =
        pedidoId
            .replaceAll(
              RegExp(
                r'[^A-Za-z0-9]',
              ),
              '',
            )
            .toUpperCase();

    if (cleaned.isEmpty) {
      return 'CH-PEDIDO';
    }

    final suffix =
        cleaned.length <= 6
            ? cleaned
            : cleaned.substring(
                cleaned.length - 6,
              );

    return 'CH-$suffix';
  }
}