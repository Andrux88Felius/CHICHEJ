import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../providers/user_provider.dart';
import '../utils/colors.dart';

class AdminUserDetailPage extends StatelessWidget {
  final String uid;
  final String nombre;
  final String email;
  final String rol;
  final String? avatarPath;
  final int muestrasDisponibles;
  final int muestrasUtilizadas;

  const AdminUserDetailPage({
    super.key,
    required this.uid,
    required this.nombre,
    required this.email,
    required this.rol,
    required this.avatarPath,
    required this.muestrasDisponibles,
    required this.muestrasUtilizadas,
  });

  String _formatearFecha(DateTime fecha) {
    String dosDigitos(int valor) {
      return valor.toString().padLeft(2, '0');
    }

    return '${dosDigitos(fecha.day)}/'
        '${dosDigitos(fecha.month)}/'
        '${fecha.year} • '
        '${dosDigitos(fecha.hour)}:'
        '${dosDigitos(fecha.minute)}';
  }

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

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filtrarPedidos(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final pedidos = docs.where((doc) {
      return doc.data()['usuarioId']?.toString() == uid;
    }).toList();

    pedidos.sort((a, b) {
      final dynamic fechaARaw = a.data()['fechaCreacion'];

      final dynamic fechaBRaw = b.data()['fechaCreacion'];

      final DateTime fechaA = fechaARaw is Timestamp
          ? fechaARaw.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0);

      final DateTime fechaB = fechaBRaw is Timestamp
          ? fechaBRaw.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0);

      return fechaB.compareTo(fechaA);
    });

    return pedidos;
  }

  Map<String, dynamic> _calcularEstadisticas(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> pedidos,
  ) {
    final DateTime ahora = DateTime.now();

    int comprasTotales = 0;
    int bebidasTotales = 0;
    int mlTotales = 0;

    int comprasMes = 0;
    int bebidasMes = 0;
    int mlMes = 0;

    double totalGastado = 0;

    for (final doc in pedidos) {
      final data = doc.data();

      final String estadoPago =
          data['estadoPago']?.toString().toLowerCase() ?? '';

      final String estado = data['estado']?.toString().toLowerCase() ?? '';

      if (estado == 'cancelado') {
        continue;
      }

      if (estadoPago != 'aprobado') {
        continue;
      }

      comprasTotales++;

      totalGastado += (data['total'] as num?)?.toDouble() ?? 0;

      final dynamic fechaRaw = data['fechaCreacion'];

      final DateTime? fecha = fechaRaw is Timestamp ? fechaRaw.toDate() : null;

      final bool esMesActual = fecha != null &&
          fecha.year == ahora.year &&
          fecha.month == ahora.month;

      if (esMesActual) {
        comprasMes++;
      }

      final dynamic itemsRaw = data['items'];

      if (itemsRaw is! List) {
        continue;
      }

      for (final dynamic itemRaw in itemsRaw) {
        if (itemRaw is! Map) {
          continue;
        }

        final int cantidad = (itemRaw['cantidad'] as num?)?.toInt() ?? 1;

        final int cantidadMl = (itemRaw['cantidadMl'] as num?)?.toInt() ?? 0;

        final bool esGratis = itemRaw['esGratis'] == true;

        if (esGratis) {
          continue;
        }

        bebidasTotales += cantidad;
        mlTotales += cantidadMl * cantidad;

        if (esMesActual) {
          bebidasMes += cantidad;
          mlMes += cantidadMl * cantidad;
        }
      }
    }

    return {
      'comprasTotales': comprasTotales,
      'bebidasTotales': bebidasTotales,
      'mlTotales': mlTotales,
      'comprasMes': comprasMes,
      'bebidasMes': bebidasMes,
      'mlMes': mlMes,
      'totalGastado': totalGastado,
    };
  }

  Widget _avatar() {
    final bool esAdmin = rol == 'admin' || rol == 'admin_principal';

    final String imagen = esAdmin
        ? UserProvider.avatarAdmin
        : (avatarPath == null || avatarPath!.isEmpty
            ? 'assets/avatares/invitado.png'
            : avatarPath!);

    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: rol == 'admin_principal'
              ? Colors.amber
              : rol == 'admin'
                  ? AppColors.lilaOscuro
                  : Colors.grey.shade300,
          width: 3,
        ),
      ),
      child: ClipOval(
        child: Image.asset(
          imagen,
          fit: BoxFit.cover,
          errorBuilder: (
            context,
            error,
            stackTrace,
          ) {
            return Container(
              color: Colors.grey.shade200,
              child: const Icon(
                Icons.person,
                size: 45,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _datoResumen({
    required String titulo,
    required String valor,
    required IconData icono,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 6,
          vertical: 12,
        ),
        child: Column(
          children: [
            Icon(
              icono,
              color: Colors.white,
            ),
            const SizedBox(height: 5),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                valor,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaProgreso({
    required String titulo,
    required String descripcion,
    required int actual,
    required int objetivo,
    required IconData icono,
  }) {
    final double progreso = (actual / objetivo).clamp(0.0, 1.0);

    final bool completado = actual >= objetivo;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: completado
                  ? Colors.green.shade50
                  : AppColors.lilaOscuro.withValues(alpha: 0.10),
              child: Icon(
                completado ? Icons.check_circle : icono,
                color: completado ? Colors.green : AppColors.lilaOscuro,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    descripcion,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 9),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: LinearProgressIndicator(
                      value: progreso,
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        completado ? Colors.green : AppColors.lilaOscuro,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    completado ? '¡Meta alcanzada!' : '$actual de $objetivo',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: completado ? Colors.green : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaPedido(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    int numero,
  ) {
    final data = doc.data();

    final String estado = data['estado']?.toString() ?? 'pendiente';

    final String metodoPago =
        data['metodoPago']?.toString() ?? 'No especificado';

    final double total = (data['total'] as num?)?.toDouble() ?? 0;

    final int totalMl = (data['cantidadTotalMl'] as num?)?.toInt() ?? 0;

    final dynamic fechaRaw = data['fechaCreacion'];

    final DateTime? fecha = fechaRaw is Timestamp ? fechaRaw.toDate() : null;

    final dynamic itemsRaw = data['items'];

    final List<dynamic> items = itemsRaw is List ? itemsRaw : [];

    final Color colorEstado = _colorEstado(estado);

    return Card(
      margin: const EdgeInsets.only(
        bottom: 10,
      ),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.dorado,
          child: const Icon(
            Icons.receipt_long,
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
                color: colorEstado.withValues(
                  alpha: 0.12,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                estado.toUpperCase(),
                style: TextStyle(
                  color: colorEstado,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(
          '${fecha != null ? _formatearFecha(fecha) : 'Sin fecha'}\n'
          '${total.toStringAsFixed(2)} Bs • $totalMl ml',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(
          14,
          0,
          14,
          14,
        ),
        children: [
          const Divider(),
          ...items.map(
            (dynamic itemRaw) {
              if (itemRaw is! Map) {
                return const SizedBox.shrink();
              }

              final String producto =
                  itemRaw['nombre']?.toString() ?? 'Producto';

              final int cantidad = (itemRaw['cantidad'] as num?)?.toInt() ?? 1;

              final int cantidadMl =
                  (itemRaw['cantidadMl'] as num?)?.toInt() ?? 0;

              final bool esGratis = itemRaw['esGratis'] == true;

              final double subtotal =
                  (itemRaw['subtotal'] as num?)?.toDouble() ?? 0;

              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  esGratis ? Icons.card_giftcard : Icons.local_drink,
                  color: esGratis ? Colors.green : AppColors.lilaOscuro,
                ),
                title: Text(
                  '$producto ×$cantidad',
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
          Row(
            children: [
              const Icon(
                Icons.payment,
                size: 20,
                color: AppColors.lilaOscuro,
              ),
              const SizedBox(width: 8),
              Text(
                'Método: '
                '${metodoPago.toUpperCase()}',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'ID: ${doc.id}',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'Detalle del cliente',
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
              child: Text(
                'No se pudo cargar '
                'la información.\n'
                '${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final pedidos = _filtrarPedidos(
            snapshot.data!.docs,
          );

          final estadisticas = _calcularEstadisticas(
            pedidos,
          );

          final int comprasTotales = estadisticas['comprasTotales'] ?? 0;

          final int bebidasTotales = estadisticas['bebidasTotales'] ?? 0;

          final int mlTotales = estadisticas['mlTotales'] ?? 0;

          final int comprasMes = estadisticas['comprasMes'] ?? 0;

          final int bebidasMes = estadisticas['bebidasMes'] ?? 0;

          final int mlMes = estadisticas['mlMes'] ?? 0;

          final double totalGastado = estadisticas['totalGastado'] ?? 0.0;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ============================================
              // PERFIL
              // ============================================

              Center(
                child: _avatar(),
              ),

              const SizedBox(height: 12),

              Text(
                nombre,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                ),
              ),

              if (email.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(
                    top: 3,
                  ),
                  child: Text(
                    email,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.black54,
                    ),
                  ),
                ),

              const SizedBox(height: 6),

              Center(
                child: Chip(
                  label: Text(
                    rol == 'admin_principal'
                        ? 'ADMIN PRINCIPAL'
                        : rol == 'admin'
                            ? 'ADMIN'
                            : 'CLIENTE',
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ============================================
              // RECORD TOTAL
              // ============================================

              Container(
                padding: const EdgeInsets.all(
                  16,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      AppColors.lilaOscuro,
                      AppColors.lilaMedio,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(
                    20,
                  ),
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
                          'Récord CHICHEJ',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: 14,
                    ),
                    Row(
                      children: [
                        _datoResumen(
                          titulo: 'Compras',
                          valor: '$comprasTotales',
                          icono: Icons.receipt_long,
                        ),
                        _datoResumen(
                          titulo: 'Bebidas',
                          valor: '$bebidasTotales',
                          icono: Icons.local_drink,
                        ),
                        _datoResumen(
                          titulo: 'Consumo',
                          valor: '${(mlTotales / 1000).toStringAsFixed(2)} L',
                          icono: Icons.water_drop,
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    Text(
                      'Total registrado: '
                      '${totalGastado.toStringAsFixed(2)} Bs',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // ============================================
              // PROGRESO MENSUAL
              // ============================================

              const Text(
                'Progreso del mes',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              _tarjetaProgreso(
                titulo: 'Cliente del mes',
                descripcion: '5 compras durante '
                    'el mes.',
                actual: comprasMes,
                objetivo: 5,
                icono: Icons.shopping_bag,
              ),

              _tarjetaProgreso(
                titulo: 'Fan de CHICHEJ',
                descripcion: '10 bebidas durante '
                    'el mes.',
                actual: bebidasMes,
                objetivo: 10,
                icono: Icons.local_drink,
              ),

              Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.lilaOscuro,
                    child: Icon(
                      Icons.water_drop,
                      color: Colors.white,
                    ),
                  ),
                  title: const Text(
                    'Consumo del mes',
                  ),
                  subtitle: Text(
                    '$mlMes ml • '
                    '${(mlMes / 1000).toStringAsFixed(2)} L',
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // ============================================
              // MUESTRAS
              // ============================================

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(
                    14,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            const Icon(
                              Icons.card_giftcard,
                              color: AppColors.lilaOscuro,
                            ),
                            const SizedBox(
                              height: 4,
                            ),
                            Text(
                              '$muestrasDisponibles',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Text(
                              'Muestras disponibles',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 60,
                        color: Colors.grey.shade300,
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            const Icon(
                              Icons.redeem,
                              color: AppColors.lilaOscuro,
                            ),
                            const SizedBox(
                              height: 4,
                            ),
                            Text(
                              '$muestrasUtilizadas',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Text(
                              'Muestras utilizadas',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // ============================================
              // HISTORIAL
              // ============================================

              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Historial de compras',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Chip(
                    label: Text(
                      '${pedidos.length}',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              if (pedidos.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(
                      20,
                    ),
                    child: Center(
                      child: Text(
                        'Este usuario todavía '
                        'no tiene compras registradas.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),

              ...List.generate(
                pedidos.length,
                (index) {
                  return _tarjetaPedido(
                    pedidos[index],
                    pedidos.length - index,
                  );
                },
              ),

              const SizedBox(height: 20),

              Text(
                'UID: $uid',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black38,
                  fontSize: 10,
                ),
              ),

              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }
}
