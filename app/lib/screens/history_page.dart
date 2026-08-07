import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/order_provider.dart';
import '../providers/user_provider.dart';
import '../utils/colors.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  // ============================================================
  // FORMATO DE FECHA
  // ============================================================

  String _formatearFecha(DateTime fecha) {
    String dosDigitos(int numero) => numero.toString().padLeft(2, '0');

    return '${dosDigitos(fecha.day)}/'
        '${dosDigitos(fecha.month)}/'
        '${fecha.year} • '
        '${dosDigitos(fecha.hour)}:'
        '${dosDigitos(fecha.minute)}';
  }

  // ============================================================
  // COLOR SEGÚN ESTADO
  // ============================================================

  Color _colorEstado(String estado) {
    switch (estado.toLowerCase()) {
      case 'entregado':
        return Colors.green;

      case 'procesando':
        return Colors.orange;

      case 'pendiente':
        return Colors.amber.shade700;

      case 'cancelado':
        return Colors.red;

      default:
        return Colors.grey;
    }
  }

  // ============================================================
  // ICONO MÉTODO DE PAGO
  // ============================================================

  IconData _iconoPago(String metodoPago) {
    switch (metodoPago.toLowerCase()) {
      case 'qr':
        return Icons.qr_code_2;

      case 'efectivo':
        return Icons.payments;

      case 'admin':
        return Icons.admin_panel_settings;

      default:
        return Icons.payment;
    }
  }

  // ============================================================
  // NOMBRE MÉTODO DE PAGO
  // ============================================================

  String _nombrePago(String metodoPago) {
    switch (metodoPago.toLowerCase()) {
      case 'qr':
        return 'QR';

      case 'efectivo':
        return 'Efectivo';

      case 'admin':
        return 'Dispensación administrativa';

      default:
        return metodoPago.isEmpty ? 'No especificado' : metodoPago;
    }
  }

  // ============================================================
  // PEDIDOS PERTENECIENTES AL USUARIO
  // ============================================================

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filtrarPedidosUsuario(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> documentos,
    String uid,
  ) {
    final pedidos = documentos.where((doc) {
      final data = doc.data();

      return data['usuarioId']?.toString() == uid;
    }).toList();

    // Ordenamos localmente para no necesitar
    // un índice compuesto en Firestore.
    pedidos.sort((a, b) {
      final dataA = a.data();
      final dataB = b.data();

      final fechaA = dataA['fechaCreacion'];
      final fechaB = dataB['fechaCreacion'];

      final DateTime aDate = fechaA is Timestamp
          ? fechaA.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0);

      final DateTime bDate = fechaB is Timestamp
          ? fechaB.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0);

      return bDate.compareTo(aDate);
    });

    return pedidos;
  }

  // ============================================================
  // CABECERA RESUMEN
  // ============================================================

  Widget _resumenHistorial(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> pedidos,
  ) {
    int totalMl = 0;
    int totalProductos = 0;
    double totalGastado = 0;

    for (final doc in pedidos) {
      final data = doc.data();

      final String estadoPago =
          data['estadoPago']?.toString().toLowerCase() ?? '';

      if (estadoPago == 'aprobado') {
        totalGastado += (data['total'] as num?)?.toDouble() ?? 0;
      }

      totalMl += (data['cantidadTotalMl'] as num?)?.toInt() ?? 0;

      final dynamic items = data['items'];

      if (items is List) {
        for (final dynamic item in items) {
          if (item is Map) {
            final bool esGratis = item['esGratis'] == true;

            if (!esGratis) {
              totalProductos += (item['cantidad'] as num?)?.toInt() ?? 1;
            }
          }
        }
      }
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(
        12,
        12,
        12,
        6,
      ),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AppColors.lilaOscuro,
            AppColors.lilaMedio,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(
                Icons.insights,
                color: Colors.white,
              ),
              SizedBox(width: 8),
              Text(
                'Tu récord CHICHEJ',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _datoResumen(
                  titulo: 'Compras',
                  valor: '${pedidos.length}',
                  icono: Icons.receipt_long,
                ),
              ),
              Expanded(
                child: _datoResumen(
                  titulo: 'Bebidas',
                  valor: '$totalProductos',
                  icono: Icons.local_drink,
                ),
              ),
              Expanded(
                child: _datoResumen(
                  titulo: 'Consumo',
                  valor: '${(totalMl / 1000).toStringAsFixed(2)} L',
                  icono: Icons.water_drop,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 9,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(
                alpha: 0.12,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Total registrado: '
              '${totalGastado.toStringAsFixed(2)} Bs',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _datoResumen({
    required String titulo,
    required String valor,
    required IconData icono,
  }) {
    return Column(
      children: [
        Icon(
          icono,
          color: Colors.white,
          size: 25,
        ),
        const SizedBox(height: 5),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            valor,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Text(
          titulo,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // PEDIDO FIRESTORE
  // ============================================================

  Widget _tarjetaPedido(
    QueryDocumentSnapshot<Map<String, dynamic>> documento,
    int numero,
  ) {
    final data = documento.data();

    final String estado = data['estado']?.toString() ?? 'pendiente';

    final String metodoPago = data['metodoPago']?.toString() ?? '';

    final String estadoPago = data['estadoPago']?.toString() ?? '';

    final double total = (data['total'] as num?)?.toDouble() ?? 0;

    final int cantidadTotalMl = (data['cantidadTotalMl'] as num?)?.toInt() ?? 0;

    final dynamic fechaRaw = data['fechaCreacion'];

    final DateTime? fecha = fechaRaw is Timestamp ? fechaRaw.toDate() : null;

    final dynamic itemsRaw = data['items'];

    final List<dynamic> items = itemsRaw is List ? itemsRaw : [];

    final Color estadoColor = _colorEstado(estado);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(17),
      ),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.dorado,
          child: const Icon(
            Icons.shopping_bag,
            color: Colors.black,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                'Pedido #$numero',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: estadoColor.withValues(
                  alpha: 0.12,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                estado.toUpperCase(),
                style: TextStyle(
                  color: estadoColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(
            top: 4,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fecha != null ? _formatearFecha(fecha) : 'Fecha no disponible',
              ),
              const SizedBox(height: 3),
              Text(
                '${total.toStringAsFixed(2)} Bs'
                ' • $cantidadTotalMl ml',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(
          14,
          0,
          14,
          14,
        ),
        children: [
          const Divider(),

          // =====================================================
          // ITEMS
          // =====================================================

          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(10),
              child: Text(
                'Este pedido no contiene '
                'detalle de productos.',
              ),
            ),

          ...items.map(
            (dynamic itemRaw) {
              if (itemRaw is! Map) {
                return const SizedBox.shrink();
              }

              final String nombre = itemRaw['nombre']?.toString() ?? 'Producto';

              final int cantidad = (itemRaw['cantidad'] as num?)?.toInt() ?? 1;

              final int cantidadMl =
                  (itemRaw['cantidadMl'] as num?)?.toInt() ?? 0;

              final double precioUnitario =
                  (itemRaw['precioUnitario'] as num?)?.toDouble() ?? 0;

              final double subtotal =
                  (itemRaw['subtotal'] as num?)?.toDouble() ??
                      (precioUnitario * cantidad);

              final bool esGratis = itemRaw['esGratis'] == true;

              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 19,
                  backgroundColor: esGratis
                      ? Colors.green.shade50
                      : AppColors.lilaOscuro.withValues(
                          alpha: 0.10,
                        ),
                  child: Icon(
                    esGratis ? Icons.card_giftcard : Icons.local_drink,
                    size: 20,
                    color: esGratis ? Colors.green : AppColors.lilaOscuro,
                  ),
                ),
                title: Text(
                  '$nombre ×$cantidad',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '$cantidadMl ml por unidad',
                ),
                trailing: Text(
                  esGratis ? 'GRATIS' : '${subtotal.toStringAsFixed(2)} Bs',
                  style: TextStyle(
                    color: esGratis ? Colors.green : Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            },
          ),

          const Divider(),

          // =====================================================
          // DATOS DEL PEDIDO
          // =====================================================

          Row(
            children: [
              Icon(
                _iconoPago(metodoPago),
                color: AppColors.lilaOscuro,
                size: 21,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _nombrePago(metodoPago),
                ),
              ),
              Text(
                estadoPago.toUpperCase(),
                style: TextStyle(
                  color: estadoPago.toLowerCase() == 'aprobado'
                      ? Colors.green
                      : Colors.black54,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${total.toStringAsFixed(2)} Bs',
                style: const TextStyle(
                  fontSize: 18,
                  color: AppColors.lilaOscuro,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'ID: ${documento.id}',
              style: const TextStyle(
                color: Colors.black38,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // RESERVAS LOCALES - TEMPORAL
  // ============================================================

  Widget _reservasLocales(
    OrderProvider orderProvider,
  ) {
    if (orderProvider.reservas.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            20,
            16,
            8,
          ),
          child: Text(
            'Pedidos especiales / Eventos',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...orderProvider.reservas.map(
          (reserva) {
            final dynamic fechaRaw = reserva['fecha'];

            final DateTime? fecha = fechaRaw is DateTime ? fechaRaw : null;

            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              color: Colors.orange.shade50,
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.orange,
                  child: Icon(
                    Icons.event,
                    color: Colors.white,
                  ),
                ),
                title: Text(
                  'Reserva: '
                  '${reserva['evento'] ?? 'Evento'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  fecha == null
                      ? 'Cantidad: '
                          '${reserva['cantidad']}'
                      : '${_formatearFecha(fecha)}\n'
                          'Cantidad: '
                          '${reserva['cantidad']}',
                ),
                isThreeLine: fecha != null,
                trailing: Chip(
                  label: Text(
                    reserva['estado']?.toString() ?? 'Pendiente',
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ============================================================
  // INVITADO
  // ============================================================

  Widget _vistaInvitado() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.history_toggle_off,
              size: 80,
              color: Colors.grey,
            ),
            const SizedBox(height: 20),
            const Text(
              'Historial disponible '
              'para usuarios registrados',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Puedes comprar como invitado, '
              'pero crea una cuenta para '
              'conservar tu historial, '
              'progreso y promociones.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final UserProvider userProvider = Provider.of<UserProvider>(context);

    final OrderProvider orderProvider = Provider.of<OrderProvider>(context);

    if (userProvider.esInvitado) {
      return Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: AppBar(
          title: const Text(
            'Historial de Pedidos 📜',
          ),
          backgroundColor: AppColors.lilaOscuro,
        ),
        body: _vistaInvitado(),
      );
    }

    final String? uid = userProvider.uid;

    if (uid == null || uid.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: AppBar(
          title: const Text(
            'Historial de Pedidos 📜',
          ),
          backgroundColor: AppColors.lilaOscuro,
        ),
        body: const Center(
          child: Text(
            'No se pudo identificar '
            'la sesión actual.',
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'Mi Historial 📜',
        ),
        backgroundColor: AppColors.lilaOscuro,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('pedidos').snapshots(),
        builder: (
          context,
          snapshot,
        ) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(
                  24,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.cloud_off,
                      size: 70,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No se pudo cargar '
                      'tu historial.',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final pedidos = _filtrarPedidosUsuario(
            snapshot.data!.docs,
            uid,
          );

          if (pedidos.isEmpty && orderProvider.reservas.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history,
                    size: 80,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Aún no tienes compras registradas',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView(
            children: [
              if (pedidos.isNotEmpty)
                _resumenHistorial(
                  pedidos,
                ),
              if (pedidos.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    14,
                    16,
                    7,
                  ),
                  child: Text(
                    'Compras',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ...List.generate(
                pedidos.length,
                (index) {
                  // Como ya están ordenados
                  // de reciente a antiguo:
                  final int numero = pedidos.length - index;

                  return _tarjetaPedido(
                    pedidos[index],
                    numero,
                  );
                },
              ),
              _reservasLocales(
                orderProvider,
              ),
              const SizedBox(height: 30),
            ],
          );
        },
      ),
    );
  }
}
