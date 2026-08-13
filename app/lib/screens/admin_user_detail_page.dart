import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/user_provider.dart';
import '../screens/cart_item.dart';
import 'admin_reservations_page.dart';
import '../services/admin_service.dart';
import '../services/firestore_service.dart';
import '../services/product_service.dart';
import '../utils/colors.dart';

enum _PeriodoDetalle { recientes, hoy, mes, anio, todos }

class AdminUserDetailPage extends StatefulWidget {
  final String uid;
  final String nombre;
  final String email;
  final String rol;
  final String? avatarPath;
  final int muestrasDisponibles;
  final int muestrasUtilizadas;
  final String telefono;
  final DateTime? fechaRegistro;

  const AdminUserDetailPage({
    super.key,
    required this.uid,
    required this.nombre,
    required this.email,
    required this.rol,
    required this.avatarPath,
    required this.muestrasDisponibles,
    required this.muestrasUtilizadas,
    this.telefono = '',
    this.fechaRegistro,
  });

  @override
  State<AdminUserDetailPage> createState() => _AdminUserDetailPageState();
}

class _AdminUserDetailPageState extends State<AdminUserDetailPage> {
  _PeriodoDetalle _periodo = _PeriodoDetalle.recientes;
  bool _dispensandoCortesia = false;

  String get uid => widget.uid;
  String get nombre => widget.nombre;
  String get email => widget.email;
  String get rol => widget.rol;
  String? get avatarPath => widget.avatarPath;
  int get muestrasDisponibles => widget.muestrasDisponibles;
  int get muestrasUtilizadas => widget.muestrasUtilizadas;

  num _numero(dynamic valor, {num respaldo = 0}) {
    if (valor is num) return valor;
    if (valor is String) return num.tryParse(valor.trim()) ?? respaldo;
    return respaldo;
  }

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

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filtrarPeriodo(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> pedidos,
  ) {
    if (_periodo == _PeriodoDetalle.recientes) return pedidos.take(7).toList();
    if (_periodo == _PeriodoDetalle.todos) return pedidos;
    final ahora = DateTime.now();
    return pedidos.where((doc) {
      final raw = doc.data()['fechaCreacion'];
      if (raw is! Timestamp) return false;
      final fecha = raw.toDate();
      if (_periodo == _PeriodoDetalle.hoy) {
        return fecha.year == ahora.year &&
            fecha.month == ahora.month &&
            fecha.day == ahora.day;
      }
      if (_periodo == _PeriodoDetalle.mes) {
        return fecha.year == ahora.year && fecha.month == ahora.month;
      }
      return fecha.year == ahora.year;
    }).toList();
  }

  Future<void> _dispensarCortesia() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Dispensar muestra de cortesía'),
        content: Text(
          'Se enviará ahora una muestra gratuita para $nombre. '
          'Esta cortesía no consume su saldo disponible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Dispensar ahora'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    final admin = context.read<UserProvider>();
    setState(() => _dispensandoCortesia = true);
    try {
      final productos = await ProductService().obtenerProductos();
      final muestras = productos
          .where((p) => p.esGratis && p.activo && !p.agotado && p.precio == 0)
          .toList();
      if (muestras.isEmpty) {
        throw StateError('No hay una muestra gratuita activa y disponible.');
      }
      final pedidoId = await FirestoreService().crearPedido(
        tipoUsuario: 'registrado',
        usuarioId: uid,
        sesionInvitadoId: null,
        nombreUsuario: nombre,
        email: email,
        items: [CartItem(producto: muestras.first)],
        metodoPago: 'admin',
        estadoPago: 'no_requerido',
      );
      await AdminService().registrarAuditoria(
        accion: 'cortesia_dispensada',
        adminUid: admin.uid ?? '',
        adminNombre: admin.user?.nombre ?? 'Administrador',
        adminRol: admin.user?.rol ?? 'admin',
        descripcion: 'Dispensó una muestra de cortesía a $nombre',
        usuarioUid: uid,
        usuarioNombre: nombre,
        productoId: muestras.first.productoId,
        productoNombre: muestras.first.nombre,
        valorNuevo: pedidoId,
        cantidad: 1,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La muestra de cortesía entró a la cola.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo dispensar la cortesía: $error')),
      );
    } finally {
      if (mounted) setState(() => _dispensandoCortesia = false);
    }
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
    int entregados = 0;
    int cancelados = 0;
    final productos = <String, int>{};
    final fechas = <DateTime>[];

    for (final doc in pedidos) {
      final data = doc.data();

      final String estadoPago =
          data['estadoPago']?.toString().toLowerCase() ?? '';

      final String estado = data['estado']?.toString().toLowerCase() ?? '';
      final fechaRaw = data['fechaCreacion'];
      if (fechaRaw is Timestamp) fechas.add(fechaRaw.toDate());
      if (estado == 'entregado') entregados++;
      if (estado == 'cancelado') cancelados++;

      if (estado == 'cancelado') {
        continue;
      }

      if (estadoPago != 'aprobado') {
        continue;
      }

      comprasTotales++;

      totalGastado += _numero(data['total']).toDouble();

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

        final int cantidad = _numero(itemRaw['cantidad'], respaldo: 1).toInt();

        final int cantidadMl = _numero(itemRaw['cantidadMl']).toInt();

        final bool esGratis = itemRaw['esGratis'] == true;

        final producto = itemRaw['nombre']?.toString() ?? 'Producto';
        productos[producto] = (productos[producto] ?? 0) + cantidad;

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

    fechas.sort();
    final favorito = productos.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return {
      'comprasTotales': comprasTotales,
      'bebidasTotales': bebidasTotales,
      'mlTotales': mlTotales,
      'comprasMes': comprasMes,
      'bebidasMes': bebidasMes,
      'mlMes': mlMes,
      'totalGastado': totalGastado,
      'pedidos': pedidos.length,
      'entregados': entregados,
      'cancelados': cancelados,
      'primerPedido': fechas.isEmpty ? null : fechas.first,
      'ultimoPedido': fechas.isEmpty ? null : fechas.last,
      'productoFavorito': favorito.isEmpty ? null : favorito.first.key,
      'productoFavoritoCantidad': favorito.isEmpty ? 0 : favorito.first.value,
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

    final double total = _numero(data['total']).toDouble();

    final int totalMl = _numero(data['cantidadTotalMl']).toInt();

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

              final int cantidad =
                  _numero(itemRaw['cantidad'], respaldo: 1).toInt();

              final int cantidadMl = _numero(itemRaw['cantidadMl']).toInt();

              final bool esGratis = itemRaw['esGratis'] == true;

              final double subtotal = _numero(itemRaw['subtotal']).toDouble();

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

          final todosLosPedidos = _filtrarPedidos(
            snapshot.data!.docs,
          );
          final pedidos = _filtrarPeriodo(todosLosPedidos);

          final estadisticas = _calcularEstadisticas(
            todosLosPedidos,
          );

          final int comprasTotales = estadisticas['comprasTotales'] ?? 0;

          final int bebidasTotales = estadisticas['bebidasTotales'] ?? 0;

          final int mlTotales = estadisticas['mlTotales'] ?? 0;

          final int comprasMes = estadisticas['comprasMes'] ?? 0;

          final int bebidasMes = estadisticas['bebidasMes'] ?? 0;

          final int mlMes = estadisticas['mlMes'] ?? 0;

          final double totalGastado = estadisticas['totalGastado'] ?? 0.0;
          final int entregados = estadisticas['entregados'] ?? 0;
          final int cancelados = estadisticas['cancelados'] ?? 0;
          final DateTime? primerPedido = estadisticas['primerPedido'];
          final DateTime? ultimoPedido = estadisticas['ultimoPedido'];
          final String? productoFavorito = estadisticas['productoFavorito'];
          final int productoFavoritoCantidad =
              estadisticas['productoFavoritoCantidad'] ?? 0;

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

              Text(
                [
                  if (widget.telefono.isNotEmpty) widget.telefono,
                  'Registro: ${widget.fechaRegistro == null ? 'No disponible' : _formatearFecha(widget.fechaRegistro!).split(' • ').first}',
                ].join(' • '),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54, fontSize: 12),
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

              Card(
                child: ExpansionTile(
                  leading: const Icon(Icons.analytics_outlined),
                  title: const Text('Resumen histórico'),
                  subtitle: Text(
                    '${todosLosPedidos.length} pedidos • $entregados entregados • '
                    '$cancelados cancelados',
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  children: [
                    ListTile(
                      dense: true,
                      title: const Text('Primer pedido'),
                      trailing: Text(primerPedido == null
                          ? 'Sin pedidos'
                          : _formatearFecha(primerPedido).split(' • ').first),
                    ),
                    ListTile(
                      dense: true,
                      title: const Text('Último pedido'),
                      trailing: Text(ultimoPedido == null
                          ? 'Sin pedidos'
                          : _formatearFecha(ultimoPedido).split(' • ').first),
                    ),
                    ListTile(
                      dense: true,
                      title: const Text('Producto favorito'),
                      trailing: Text(productoFavorito == null
                          ? 'Sin datos'
                          : '$productoFavorito ($productoFavoritoCantidad)'),
                    ),
                  ],
                ),
              ),

              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('reservas')
                    .snapshots(),
                builder: (context, reservaSnapshot) {
                  if (reservaSnapshot.hasError) {
                    return const Card(
                      child: ListTile(
                        leading: Icon(Icons.event_note),
                        title: Text('Solicitudes comerciales / Reservas'),
                        subtitle: Text('No se pudieron consultar.'),
                      ),
                    );
                  }
                  final correoNormalizado = email.trim().toLowerCase();
                  final reservas = reservaSnapshot.data?.docs.where((doc) {
                        final data = doc.data();
                        final reservaUid = data['usuarioId']?.toString().trim();
                        if (reservaUid != null && reservaUid.isNotEmpty) {
                          return reservaUid == uid;
                        }
                        final correoReserva =
                            data['email']?.toString().trim().toLowerCase() ??
                                '';
                        return correoNormalizado.isNotEmpty &&
                            correoReserva == correoNormalizado;
                      }).toList() ??
                      const [];
                  final cantidad = reservas.length;
                  return Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.event_note,
                        color: AppColors.lilaOscuro,
                      ),
                      title: const Text('Solicitudes comerciales / Reservas'),
                      subtitle: Text('$cantidad solicitud(es) asociada(s)'),
                      trailing:
                          cantidad > 0 ? const Icon(Icons.chevron_right) : null,
                      onTap: cantidad == 0
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AdminReservationsPage(
                                    usuarioId: uid,
                                    nombreCliente: nombre,
                                    emailCliente: email,
                                  ),
                                ),
                              );
                            },
                    ),
                  );
                },
              ),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _dispensandoCortesia ? null : _dispensarCortesia,
                  icon: _dispensandoCortesia
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.local_drink),
                  label: const Text('Dispensar muestra de cortesía ahora'),
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

              Wrap(
                spacing: 7,
                runSpacing: 6,
                children: _PeriodoDetalle.values.map((periodo) {
                  final texto = switch (periodo) {
                    _PeriodoDetalle.recientes => 'Últimos 7',
                    _PeriodoDetalle.hoy => 'Hoy',
                    _PeriodoDetalle.mes => 'Este mes',
                    _PeriodoDetalle.anio => 'Este año',
                    _PeriodoDetalle.todos => 'Todos',
                  };
                  return ChoiceChip(
                    label: Text(texto),
                    selected: _periodo == periodo,
                    onSelected: (_) => setState(() => _periodo = periodo),
                  );
                }).toList(),
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
                        'No hay compras en el período seleccionado',
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
                    todosLosPedidos.length - index,
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
