import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/order_ticket_service.dart';
import '../providers/user_provider.dart';
import '../services/dispenser_service.dart';
import '../utils/colors.dart';

class DispenserAdminPage extends StatefulWidget {
  const DispenserAdminPage({super.key});

  @override
  State<DispenserAdminPage> createState() => _DispenserAdminPageState();
}

class _DispenserAdminPageState extends State<DispenserAdminPage> {
  final DispenserService _service = DispenserService();

  late final Stream<DatabaseEvent> _estadoDispensadorStream;

  late final Stream<QuerySnapshot<Map<String, dynamic>>>
      _pedidosPendientesStream;

  late final Stream<QuerySnapshot<Map<String, dynamic>>>
      _pedidosProcesandoStream;

  late final Stream<QuerySnapshot<Map<String, dynamic>>>
      _pedidosRecientesStream;

  @override
  void initState() {
    super.initState();

    _estadoDispensadorStream = _service.observarEstadoDispensador();

    _pedidosPendientesStream = _service.observarPedidosPendientes();

    _pedidosProcesandoStream = _service.observarPedidosProcesando();

    _pedidosRecientesStream = _service.observarPedidosRecientes();
  }

  // ============================================================
  // CONVERSIONES SEGURAS
  // ============================================================

  Map<String, dynamic> _mapSeguro(dynamic valor) {
    if (valor is! Map) {
      return {};
    }

    final Map<String, dynamic> resultado = {};

    valor.forEach((key, value) {
      resultado[key.toString()] = value;
    });

    return resultado;
  }

  DateTime? _fechaPedido(Map<String, dynamic> pedido) {
    final dynamic fecha = pedido['fechaCreacion'];

    if (fecha is Timestamp) {
      return fecha.toDate();
    }

    return null;
  }

  String _fechaTexto(Map<String, dynamic> pedido) {
    final DateTime? fecha = _fechaPedido(pedido);

    if (fecha == null) {
      return 'Sin fecha';
    }

    String dos(int valor) {
      return valor.toString().padLeft(2, '0');
    }

    return '${dos(fecha.day)}/${dos(fecha.month)}/${fecha.year} '
        '${dos(fecha.hour)}:${dos(fecha.minute)}';
  }

  // ============================================================
  // PEDIDO / USUARIO
  // ============================================================

  String _nombreUsuario(Map<String, dynamic> pedido) {
    final String nombre = pedido['nombreUsuario']?.toString().trim() ?? '';

    if (nombre.isNotEmpty) {
      return nombre;
    }

    final String email = pedido['email']?.toString().trim() ?? '';

    if (email.isNotEmpty) {
      return email;
    }

    final String tipo = pedido['tipoUsuario']?.toString().toLowerCase() ?? '';

    if (tipo == 'invitado') {
      return 'Invitado';
    }

    if (tipo == 'maquina') {
      return 'Dispensador CHICHEJ';
    }

    return 'Usuario';
  }

  String _tipoUsuarioTexto(Map<String, dynamic> pedido) {
    final String tipo = pedido['tipoUsuario']?.toString().toLowerCase() ?? '';

    switch (tipo) {
      case 'admin_principal':
        return 'Admin principal';

      case 'admin':
        return 'Administrador';

      case 'invitado':
        return 'Invitado';

      case 'maquina':
        return 'MÃ¡quina';

      case 'registrado':
      case 'cliente':
        return 'Cliente';

      default:
        return tipo.isEmpty ? 'Sin identificar' : tipo;
    }
  }

  String _origenPedido(Map<String, dynamic> pedido) {
    final String origen =
        pedido['origenPedido']?.toString().toLowerCase() ?? '';

    switch (origen) {
      case 'boton_fisico':
        return 'BotÃ³n fÃ­sico';

      case 'admin_app':
        return 'AplicaciÃ³n Admin';

      case 'app':
        return 'AplicaciÃ³n';

      default:
        break;
    }

    final String tipo = pedido['tipoUsuario']?.toString().toLowerCase() ?? '';

    if (tipo == 'maquina') {
      return 'MÃ¡quina';
    }

    return 'AplicaciÃ³n';
  }

  String? _uidPedido(Map<String, dynamic> pedido) {
    final dynamic valor = pedido['usuarioId'];

    if (valor == null) {
      return null;
    }

    final String uid = valor.toString().trim();

    if (uid.isEmpty || uid == 'null') {
      return null;
    }

    return uid;
  }

  bool _esInvitado(Map<String, dynamic> pedido) {
    return pedido['tipoUsuario']?.toString().toLowerCase() == 'invitado';
  }

  bool _esMaquina(Map<String, dynamic> pedido) {
    return pedido['tipoUsuario']?.toString().toLowerCase() == 'maquina';
  }

  // ============================================================
  // ITEMS
  // ============================================================

  int _cantidadTotalUnidades(
    Map<String, dynamic> pedido,
  ) {
    final dynamic items = pedido['items'];

    if (items is! List) {
      return (pedido['cantidadItems'] as num?)?.toInt() ?? 0;
    }

    int total = 0;

    for (final dynamic item in items) {
      if (item is Map) {
        total += (item['cantidad'] as num?)?.toInt() ?? 1;
      }
    }

    return total;
  }

  String _resumenItems(
    Map<String, dynamic> pedido,
  ) {
    final dynamic items = pedido['items'];

    if (items is! List || items.isEmpty) {
      final int ml = (pedido['cantidadTotalMl'] as num?)?.toInt() ?? 0;

      return ml > 0 ? '$ml ml' : 'Sin detalle';
    }

    final List<String> partes = [];

    for (final dynamic item in items) {
      if (item is! Map) {
        continue;
      }

      final String nombre = item['nombre']?.toString() ?? 'Producto';

      final int cantidad = (item['cantidad'] as num?)?.toInt() ?? 1;

      if (cantidad > 1) {
        partes.add('$nombre Ã—$cantidad');
      } else {
        partes.add(nombre);
      }
    }

    return partes.isEmpty ? 'Sin detalle' : partes.join(' â€¢ ');
  }

  // ============================================================
  // COLORES / ICONOS
  // ============================================================

  Color _colorEstado(String estado) {
    switch (estado.toLowerCase()) {
      case 'procesando':
        return Colors.orange;

      case 'entregado':
        return Colors.green;

      case 'cancelado':
        return Colors.redAccent;

      case 'pendiente':
        return Colors.blue;

      default:
        return Colors.grey;
    }
  }

  IconData _iconoEstado(String estado) {
    switch (estado.toLowerCase()) {
      case 'procesando':
        return Icons.local_drink;

      case 'entregado':
        return Icons.check_circle;

      case 'cancelado':
        return Icons.cancel;

      case 'pendiente':
        return Icons.schedule;

      default:
        return Icons.help_outline;
    }
  }

  IconData _iconoOrigen(
    Map<String, dynamic> pedido,
  ) {
    final String tipo = pedido['tipoUsuario']?.toString().toLowerCase() ?? '';

    final dynamic items = pedido['items'];

    bool tieneGratis = false;

    if (items is List) {
      for (final item in items) {
        if (item is Map && item['esGratis'] == true) {
          tieneGratis = true;
          break;
        }
      }
    }

    if (tieneGratis) {
      return Icons.card_giftcard;
    }

    if (tipo == 'maquina') {
      return Icons.precision_manufacturing;
    }

    if (tipo == 'admin' || tipo == 'admin_principal') {
      return Icons.admin_panel_settings;
    }

    if (tipo == 'invitado') {
      return Icons.person_outline;
    }

    return Icons.phone_android;
  }

  // ============================================================
  // CANCELAR PEDIDO
  // ============================================================

  Future<void> _cancelarPedido(
    String pedidoId,
    Map<String, dynamic> pedido,
  ) async {
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Cancelar pedido',
          ),
          content: Text(
            'Â¿Cancelar el pedido de '
            '${_nombreUsuario(pedido)}?\n\n'
            '${_resumenItems(pedido)}',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text('No'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              icon: const Icon(Icons.cancel),
              label: const Text(
                'Cancelar pedido',
              ),
            ),
          ],
        );
      },
    );

    if (confirmar != true) {
      return;
    }

    try {
      await _service.cancelarPedido(
        pedidoId: pedidoId,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Pedido cancelado correctamente.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo cancelar: $e',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // ============================================================
  // BLOQUEAR USUARIO
  // ============================================================

  Future<void> _bloquearUsuario(
    Map<String, dynamic> pedido,
  ) async {
    final String? uid = _uidPedido(pedido);

    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Este pedido no pertenece a un '
            'usuario registrado y no puede '
            'bloquearse por UID.',
          ),
        ),
      );

      return;
    }

    final String nombre = _nombreUsuario(pedido);

    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Bloquear usuario',
          ),
          content: Text(
            'Â¿Bloquear a $nombre?\n\n'
            'El usuario quedarÃ¡ marcado como '
            'bloqueado y no deberÃ¡ poder generar '
            'nuevos pedidos.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              icon: const Icon(Icons.block),
              label: const Text('Bloquear'),
            ),
          ],
        );
      },
    );

    if (confirmar != true) {
      return;
    }

    try {
      await _service.bloquearUsuario(
        uid: uid,
        bloqueado: true,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$nombre fue bloqueado.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo bloquear: $e',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // ============================================================
  // ESTADO MÃQUINA
  // ============================================================

  Widget _estadoMaquina() {
    return StreamBuilder<DatabaseEvent>(
      stream: _estadoDispensadorStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _cardError(
            'TelemetrÃ­a temporalmente no disponible.',
          );
        }

        final dynamic valor = snapshot.data?.snapshot.value;

        final Map<String, dynamic> maquina = _mapSeguro(valor);

        final String estado = maquina['estado']?.toString() ?? 'Sin telemetrÃ­a';

        final String bebida = maquina['bebidaNombre']?.toString() ??
            maquina['productoactual']?.toString() ??
            'Chicha';

        final bool bomba =
            maquina['bombaActiva'] == true || maquina['bomba'] == true;

        final bool agitador =
            maquina['agitadorActivo'] == true || maquina['agitador'] == true;

        final int? nivel = (maquina['nivelPorcentaje'] as num?)?.toInt() ??
            (maquina['nivelliquido'] as num?)?.toInt();

        final bool tieneDatos = maquina.isNotEmpty;

        return Card(
          elevation: 3,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: tieneDatos
                          ? Colors.green.shade100
                          : Colors.grey.shade200,
                      child: Icon(
                        Icons.precision_manufacturing,
                        color: tieneDatos ? Colors.green : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Dispensador CHICHEJ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            tieneDatos
                                ? 'Datos disponibles'
                                : 'Esperando telemetrÃ­a ESP32',
                            style: TextStyle(
                              color: tieneDatos ? Colors.green : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 28),
                _filaEstado(
                  icono: Icons.local_drink,
                  titulo: 'Bebida',
                  valor: bebida,
                ),
                _filaEstado(
                  icono: Icons.memory,
                  titulo: 'Estado',
                  valor: estado.toUpperCase(),
                ),
                _filaEstado(
                  icono: Icons.water,
                  titulo: 'Bomba',
                  valor: bomba ? 'ACTIVA' : 'APAGADA',
                ),
                _filaEstado(
                  icono: Icons.sync,
                  titulo: 'Agitador',
                  valor: agitador ? 'ACTIVO' : 'APAGADO',
                ),
                _filaEstado(
                  icono: Icons.opacity,
                  titulo: 'Nivel',
                  valor: nivel == null ? 'Sensor pendiente' : '$nivel %',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _filaEstado({
    required IconData icono,
    required String titulo,
    required String valor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 6,
      ),
      child: Row(
        children: [
          Icon(
            icono,
            size: 20,
            color: AppColors.lilaOscuro,
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 80,
            child: Text(
              titulo,
              style: const TextStyle(
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              valor,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PEDIDO ACTUAL
  // ============================================================

  Widget _pedidoActual() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _pedidosProcesandoStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _cardError(
            'No se pudo leer el pedido actual.',
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.green.shade50,
                child: const Icon(
                  Icons.check,
                  color: Colors.green,
                ),
              ),
              title: const Text(
                'MÃ¡quina disponible',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text(
                'No hay pedidos procesÃ¡ndose.',
              ),
            ),
          );
        }

        final doc = docs.first;
        final data = doc.data();

        return Card(
          elevation: 3,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.local_drink,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'PEDIDO EN CURSO',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Chip(
                      label: const Text(
                        'PROCESANDO',
                      ),
                      backgroundColor: Colors.orange.shade100,
                    ),
                  ],
                ),
                const Divider(),
                Text(
                  _nombreUsuario(data),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 5),
                Text(_resumenItems(data)),
                const SizedBox(height: 5),
                Text(
                  '${_cantidadTotalUnidades(data)} '
                  'dispensaciÃ³n(es)',
                  style: const TextStyle(
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // COLA
  // ============================================================

  Widget _colaPedidos(
    bool esAdminPrincipal,
  ) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _pedidosPendientesStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _cardError(
            'No se pudo cargar la cola.',
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final docs = [
          ...snapshot.data!.docs,
        ];

        docs.sort((a, b) {
          final fechaA = _fechaPedido(a.data());

          final fechaB = _fechaPedido(b.data());

          if (fechaA == null && fechaB == null) {
            return 0;
          }

          if (fechaA == null) {
            return 1;
          }

          if (fechaB == null) {
            return -1;
          }

          return fechaA.compareTo(fechaB);
        });

        if (docs.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'No hay pedidos en espera.',
                  style: TextStyle(
                    color: Colors.black54,
                  ),
                ),
              ),
            ),
          );
        }

        return Column(
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Cola de dispensaciÃ³n',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Chip(
                  label: Text(
                    '${docs.length} en espera',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...List.generate(
              docs.length,
              (index) {
                final doc = docs[index];
                final data = doc.data();

                final String? uid = _uidPedido(data);

                final bool puedeBloquear = esAdminPrincipal &&
                    uid != null &&
                    !_esInvitado(data) &&
                    !_esMaquina(data);

                return Card(
                  margin: const EdgeInsets.only(
                    bottom: 10,
                  ),
                  child: ExpansionTile(
                    key: PageStorageKey<String>(
                      'pedido_pendiente_${doc.id}',
                    ),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.lilaOscuro,
                      foregroundColor: Colors.white,
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      _nombreUsuario(data),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _resumenItems(data),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(
                              _iconoOrigen(data),
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(
                              width: 4,
                            ),
                            Expanded(
                              child: Text(
                                '${_tipoUsuarioTexto(data)}'
                                ' â€¢ ${_origenPedido(data)}'
                                ' â€¢ ${_fechaTexto(data)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    children: [
                      const Divider(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          14,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.redAccent,
                                ),
                                onPressed: () {
                                  _cancelarPedido(
                                    doc.id,
                                    data,
                                  );
                                },
                                icon: const Icon(
                                  Icons.cancel,
                                ),
                                label: const Text(
                                  'Cancelar',
                                ),
                              ),
                            ),
                            if (puedeBloquear) ...[
                              const SizedBox(
                                width: 10,
                              ),
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.deepOrange,
                                  ),
                                  onPressed: () {
                                    _bloquearUsuario(
                                      data,
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.block,
                                  ),
                                  label: const Text(
                                    'Bloquear',
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _reimprimirComprobante(
    BuildContext context,
    String pedidoId,
    Map<String, dynamic> data,
  ) async {
    final String nombre = _nombreUsuario(data);

    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(
                Icons.print,
                color: Colors.deepPurple,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Reimprimir comprobante',
                ),
              ),
            ],
          ),
          content: Text(
            'Â¿Deseas volver a imprimir el comprobante '
            'del pedido de $nombre?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text(
                'Cancelar',
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              icon: const Icon(
                Icons.print,
              ),
              label: const Text(
                'Reimprimir',
              ),
            ),
          ],
        );
      },
    );

    if (confirmar != true) {
      return;
    }

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Conectando con la impresora MX06...',
        ),
        duration: Duration(
          seconds: 2,
        ),
      ),
    );

    final bool resultado =
        await OrderTicketService.instance.reprintOrder(
      pedidoId,
    );

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          resultado
              ? 'Comprobante enviado a la MX06.'
              : 'No se pudo reimprimir el comprobante.',
        ),
        backgroundColor:
            resultado ? Colors.green : Colors.redAccent,
      ),
    );
  }

  // ============================================================
  // ACTIVIDAD RECIENTE
  // ============================================================

  Widget _actividadReciente() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _pedidosRecientesStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _cardError(
            'No se pudo leer actividad reciente.',
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final docs = snapshot.data!.docs
            .where(
              (doc) {
                final String estado =
                    doc.data()['estado']?.toString() ?? '';

                return estado == 'entregado' ||
                    estado == 'cancelado';
              },
            )
            .take(8)
            .toList();

        if (docs.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Actividad reciente',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),

            ...docs.map(
              (doc) {
                final data = doc.data();

                final String estado =
                    data['estado']
                        ?.toString()
                        .trim()
                        .toLowerCase() ??
                    'desconocido';

                final String tipoUsuario =
                    data['tipoUsuario']
                        ?.toString()
                        .trim()
                        .toLowerCase() ??
                    '';

                final bool ticketImpreso =
                    data['ticketImpreso'] == true;

                final bool puedeReimprimir =
                    estado == 'entregado' &&
                        tipoUsuario != 'admin';

                final Color color =
                    _colorEstado(
                  estado,
                );

                return Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              color.withValues(
                            alpha: 0.12,
                          ),
                          child: Icon(
                            _iconoEstado(
                              estado,
                            ),
                            color: color,
                          ),
                        ),
                        title: Text(
                          _nombreUsuario(
                            data,
                          ),
                          style: const TextStyle(
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          '${_resumenItems(data)}\n'
                          '${_fechaTexto(data)}',
                        ),
                        isThreeLine: true,
                        trailing: Text(
                          estado.toUpperCase(),
                          style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ),

                      if (puedeReimprimir) ...[
                        const Divider(
                          height: 1,
                        ),

                        Padding(
                          padding:
                              const EdgeInsets.fromLTRB(
                            12,
                            6,
                            12,
                            8,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Icon(
                                      ticketImpreso
                                          ? Icons
                                              .check_circle_outline
                                          : Icons
                                              .error_outline,
                                      size: 17,
                                      color: ticketImpreso
                                          ? Colors.green
                                          : Colors.orange,
                                    ),
                                    const SizedBox(
                                      width: 5,
                                    ),
                                    Expanded(
                                      child: Text(
                                        ticketImpreso
                                            ? 'Comprobante impreso'
                                            : 'Comprobante pendiente',
                                        style:
                                            TextStyle(
                                          fontSize: 12,
                                          color: ticketImpreso
                                              ? Colors.green
                                              : Colors.orange,
                                          fontWeight:
                                              FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              TextButton.icon(
                                onPressed: () {
                                  _reimprimirComprobante(
                                    context,
                                    doc.id,
                                    data,
                                  );
                                },
                                icon: const Icon(
                                  Icons.print_outlined,
                                  size: 18,
                                ),
                                label: const Text(
                                  'Reimprimir',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _cardError(String mensaje) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.redAccent,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(mensaje),
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
    final userProvider = context.watch<UserProvider>();

    final String rol = userProvider.user?.rol?.toLowerCase() ?? '';

    final bool esAdminPrincipal = rol == 'admin_principal';

    // No usamos Scaffold/AppBar aquÃ­ porque esta pantalla
    // vive dentro del TabBar del panel administrativo.
    return ColoredBox(
      color: Colors.grey.shade100,
      child: RefreshIndicator(
        onRefresh: () async {
          setState(() {});
        },
        child: ListView(
          key: const PageStorageKey(
            'maquina_chichej_admin',
          ),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Estado de la mÃ¡quina',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _estadoMaquina(),
            const SizedBox(height: 22),
            const Text(
              'Estado de dispensaciÃ³n',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            _pedidoActual(),
            const SizedBox(height: 22),
            _colaPedidos(
              esAdminPrincipal,
            ),
            const SizedBox(height: 22),
            _actividadReciente(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
