import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart' as fb_db;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product_model.dart';
import '../providers/user_provider.dart';
import '../services/admin_service.dart';
import '../services/product_service.dart';
import '../utils/colors.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final ProductService _productService = ProductService();
  final AdminService _adminService = AdminService();

  // ============================================================
  // CACHE DE USUARIOS
  // ============================================================

  StreamSubscription<fb_db.DatabaseEvent>? _usuariosSubscription;

  List<Map<String, dynamic>> _usuariosCache = [];

  bool _cargandoUsuarios = true;

  Object? _errorUsuarios;

  @override
  void initState() {
    super.initState();

    _iniciarEscuchaUsuarios();
  }

  void _iniciarEscuchaUsuarios() {
    _usuariosSubscription = _adminService.observarUsuarios().listen(
      (event) {
        if (!mounted) return;

        setState(() {
          _usuariosCache = _obtenerUsuarios(event);
          _cargandoUsuarios = false;
          _errorUsuarios = null;
        });
      },
      onError: (Object error) {
        if (!mounted) return;

        setState(() {
          _errorUsuarios = error;
          _cargandoUsuarios = false;
        });
      },
    );
  }

  @override
  void dispose() {
    _usuariosSubscription?.cancel();
    super.dispose();
  }

  // ============================================================
  // CONVERTIR USUARIOS DE RTDB A LISTA
  // ============================================================

  List<Map<String, dynamic>> _obtenerUsuarios(
    fb_db.DatabaseEvent event,
  ) {
    final dynamic valor = event.snapshot.value;

    if (valor is! Map) {
      return [];
    }

    final List<Map<String, dynamic>> usuarios = [];

    valor.forEach((uid, datosUsuario) {
      if (datosUsuario is Map) {
        final Map<String, dynamic> usuario = {
          'uid': uid.toString(),
        };

        datosUsuario.forEach((key, value) {
          usuario[key.toString()] = value;
        });

        usuarios.add(usuario);
      }
    });

    // Primero admin principal, luego admins,
    // después clientes en orden alfabético.
    int prioridadRol(String rol) {
      if (rol == 'admin_principal') return 0;
      if (rol == 'admin') return 1;
      return 2;
    }

    usuarios.sort((a, b) {
      final String rolA = a['rol']?.toString() ?? 'cliente';

      final String rolB = b['rol']?.toString() ?? 'cliente';

      final int comparacionRol = prioridadRol(rolA).compareTo(
        prioridadRol(rolB),
      );

      if (comparacionRol != 0) {
        return comparacionRol;
      }

      final String nombreA = a['nombre']?.toString() ?? '';

      final String nombreB = b['nombre']?.toString() ?? '';

      return nombreA.toLowerCase().compareTo(
            nombreB.toLowerCase(),
          );
    });

    return usuarios;
  }

  // ============================================================
  // EDITAR PRECIO
  // ============================================================

  Future<void> _editarPrecio(
    Product producto,
  ) async {
    String textoPrecio = producto.precio.toStringAsFixed(2);

    final double? nuevoPrecio = await showDialog<double>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            'Editar precio\n${producto.nombre}',
          ),
          content: TextFormField(
            initialValue: textoPrecio,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            decoration: const InputDecoration(
              labelText: 'Nuevo precio (Bs)',
              prefixIcon: Icon(
                Icons.payments,
              ),
            ),
            onChanged: (value) {
              textoPrecio = value;
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text(
                'Cancelar',
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final String texto = textoPrecio.trim().replaceAll(',', '.');

                final double? valor = double.tryParse(texto);

                if (valor == null || valor < 0) {
                  ScaffoldMessenger.of(
                    dialogContext,
                  ).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Introduce un precio válido.',
                      ),
                    ),
                  );

                  return;
                }

                Navigator.pop(
                  dialogContext,
                  valor,
                );
              },
              child: const Text(
                'Guardar',
              ),
            ),
          ],
        );
      },
    );

    if (nuevoPrecio == null) {
      return;
    }

    try {
      await _productService.actualizarPrecio(
        productoId: producto.productoId,
        nuevoPrecio: nuevoPrecio,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${producto.nombre}: '
            '${nuevoPrecio.toStringAsFixed(2)} Bs',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo actualizar el precio: $error',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // ============================================================
  // REGALAR MUESTRA
  // ============================================================

  Future<void> _regalarMuestra({
    required String uid,
    required String nombre,
  }) async {
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(
                Icons.card_giftcard,
                color: AppColors.lilaOscuro,
              ),
              SizedBox(width: 10),
              Text(
                'Regalar muestra',
              ),
            ],
          ),
          content: Text(
            '¿Deseas agregar 1 muestra gratuita '
            'a $nombre?',
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
                Icons.card_giftcard,
              ),
              label: const Text(
                'Regalar +1',
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
      await _adminService.regalarMuestra(
        uid: uid,
        cantidad: 1,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Se agregó 1 muestra gratuita a $nombre.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo regalar la muestra: $error',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // ============================================================
  // CAMBIAR ROL
  // ============================================================

  Future<void> _cambiarRol({
    required String uid,
    required String nombre,
    required String rolActual,
  }) async {
    final String nuevoRol = rolActual == 'admin' ? 'cliente' : 'admin';

    final bool convertirAdmin = nuevoRol == 'admin';

    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                convertirAdmin
                    ? Icons.admin_panel_settings
                    : Icons.person_remove,
                color: AppColors.lilaOscuro,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Cambiar rol',
                ),
              ),
            ],
          ),
          content: Text(
            convertirAdmin
                ? '¿Deseas convertir a $nombre '
                    'en administrador?'
                : '¿Deseas quitar los permisos '
                    'administrativos de $nombre?',
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
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: Text(
                convertirAdmin ? 'Hacer administrador' : 'Quitar administrador',
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
      await _adminService.cambiarRol(
        uid: uid,
        nuevoRol: nuevoRol,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            convertirAdmin
                ? '$nombre ahora es administrador.'
                : '$nombre volvió a ser cliente.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo cambiar el rol: $error',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // ============================================================
  // AVATAR USUARIO
  // ============================================================

  Widget _avatarUsuario(
    Map<String, dynamic> usuario,
  ) {
    final String rol = usuario['rol']?.toString() ?? 'cliente';

    final bool esAdministrador = rol == 'admin' || rol == 'admin_principal';

    final String? avatarPath = usuario['avatarPath']?.toString();

    final String imagen = esAdministrador
        ? UserProvider.avatarAdmin
        : (avatarPath == null || avatarPath.isEmpty
            ? 'assets/avatares/invitado.png'
            : avatarPath);

    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: rol == 'admin_principal'
              ? Colors.amber
              : rol == 'admin'
                  ? AppColors.lilaOscuro
                  : Colors.grey.shade300,
          width: rol == 'cliente' ? 1 : 2.5,
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
                color: Colors.grey,
              ),
            );
          },
        ),
      ),
    );
  }

  // ============================================================
  // TARJETA ESTADÍSTICA
  // ============================================================

  Widget _tarjetaEstadistica({
    required String titulo,
    required String valor,
    required IconData icono,
  }) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 12,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icono,
              size: 30,
              color: AppColors.lilaOscuro,
            ),
            const SizedBox(height: 7),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                valor,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                titulo,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black54,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // RESUMEN
  // ============================================================

  Widget _buildResumen() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _adminService.observarPedidos(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Error leyendo pedidos:\n'
                '${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final docs = snapshot.data!.docs;

        int pedidosTotales = 0;
        int pedidosEntregados = 0;
        int mlRegistrados = 0;

        double ventas = 0;

        final Map<String, int> productosVendidos = {};
        final Map<String, int> metodosPago = {};

        for (final doc in docs) {
          final Map<String, dynamic> data = doc.data();

          pedidosTotales++;

          final String estado = data['estado']?.toString() ?? '';

          if (estado == 'entregado') {
            pedidosEntregados++;
          }

          mlRegistrados += (data['cantidadTotalMl'] as num?)?.toInt() ?? 0;

          final String estadoPago = data['estadoPago']?.toString() ?? '';

          if (estadoPago == 'aprobado') {
            ventas += (data['total'] as num?)?.toDouble() ?? 0;
          }

          final String metodoPago =
              data['metodoPago']?.toString().toLowerCase() ?? 'desconocido';

          metodosPago[metodoPago] = (metodosPago[metodoPago] ?? 0) + 1;

          final dynamic items = data['items'];

          if (items is List) {
            for (final dynamic item in items) {
              if (item is Map) {
                final String nombre = item['nombre']?.toString() ?? 'Producto';

                final int cantidad = (item['cantidad'] as num?)?.toInt() ?? 1;

                productosVendidos[nombre] =
                    (productosVendidos[nombre] ?? 0) + cantidad;
              }
            }
          }
        }

        String productoMasPedido = 'Sin datos';
        int cantidadMasPedida = 0;

        productosVendidos.forEach(
          (producto, cantidad) {
            if (cantidad > cantidadMasPedida) {
              cantidadMasPedida = cantidad;
              productoMasPedido = producto;
            }
          },
        );

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Resumen general',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,

              // Más alto para evitar el overflow
              childAspectRatio: 1.15,

              children: [
                _tarjetaEstadistica(
                  titulo: 'Pedidos',
                  valor: '$pedidosTotales',
                  icono: Icons.receipt_long,
                ),
                _tarjetaEstadistica(
                  titulo: 'Ventas',
                  valor: '${ventas.toStringAsFixed(2)} Bs',
                  icono: Icons.monetization_on,
                ),
                _tarjetaEstadistica(
                  titulo: 'Entregados',
                  valor: '$pedidosEntregados',
                  icono: Icons.check_circle,
                ),
                _tarjetaEstadistica(
                  titulo: 'Dispensado',
                  valor: '$mlRegistrados ml',
                  icono: Icons.local_drink,
                ),
              ],
            ),
            const SizedBox(height: 22),
            Card(
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.lilaOscuro,
                  child: Icon(
                    Icons.star,
                    color: Colors.white,
                  ),
                ),
                title: const Text(
                  'Producto más solicitado',
                ),
                subtitle: Text(
                  '$productoMasPedido\n'
                  '$cantidadMasPedida unidades',
                ),
                isThreeLine: true,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Métodos de pago',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            if (metodosPago.isEmpty)
              const Card(
                child: ListTile(
                  leading: Icon(
                    Icons.info_outline,
                  ),
                  title: Text(
                    'Todavía no hay pagos registrados',
                  ),
                ),
              ),
            ...metodosPago.entries.map(
              (entry) {
                IconData icono;

                if (entry.key == 'qr') {
                  icono = Icons.qr_code;
                } else if (entry.key == 'efectivo') {
                  icono = Icons.money;
                } else {
                  icono = Icons.admin_panel_settings;
                }

                return Card(
                  child: ListTile(
                    leading: Icon(
                      icono,
                      color: AppColors.lilaOscuro,
                    ),
                    title: Text(
                      entry.key.toUpperCase(),
                    ),
                    trailing: Text(
                      '${entry.value}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.picture_as_pdf,
                  color: Colors.red,
                ),
                title: const Text(
                  'Reportes PDF',
                ),
                subtitle: const Text(
                  'Próximamente podrás generar '
                  'reportes de ventas, usuarios '
                  'y productos.',
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                ),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'La exportación PDF será '
                        'la siguiente fase del panel.',
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // DATOS DE MUESTRAS
  // ============================================================

  Widget _datoUsuario({
    required String titulo,
    required String valor,
    required IconData icono,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            icono,
            color: AppColors.lilaOscuro,
          ),
          const SizedBox(height: 5),
          Text(
            valor,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // USUARIOS
  // ============================================================

  Widget _buildUsuarios(
    UserProvider userProvider,
  ) {
    if (_cargandoUsuarios) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorUsuarios != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.cloud_off,
                size: 60,
                color: Colors.grey,
              ),
              const SizedBox(height: 14),
              const Text(
                'No se pudieron cargar los usuarios.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$_errorUsuarios',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final List<Map<String, dynamic>> usuarios = _usuariosCache;

    if (usuarios.isEmpty) {
      return const Center(
        child: Text(
          'No hay usuarios registrados.',
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Usuarios registrados',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Chip(
              avatar: const Icon(
                Icons.people,
                size: 18,
              ),
              label: Text(
                '${usuarios.length}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (userProvider.esAdminPrincipal)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(
              bottom: 14,
            ),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.amber.shade300,
              ),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.workspace_premium,
                  color: Colors.orange,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Administrador principal: '
                    'puedes asignar o quitar '
                    'administradores.',
                  ),
                ),
              ],
            ),
          ),
        ...usuarios.map(
          (usuario) {
            final String uid = usuario['uid']?.toString() ?? '';

            final String nombre = usuario['nombre']?.toString() ?? 'Usuario';

            final String email = usuario['email']?.toString() ?? '';

            final String rol = usuario['rol']?.toString() ?? 'cliente';

            final int disponibles =
                (usuario['muestrasGratisDisponibles'] as num?)?.toInt() ?? 0;

            final int utilizadas =
                (usuario['muestrasGratisUtilizadas'] as num?)?.toInt() ?? 0;

            final bool esPropioUsuario = uid == userProvider.uid;

            final bool esPrincipal = rol == 'admin_principal';

            final bool esSubAdmin = rol == 'admin';

            final bool puedeCambiarRol = userProvider.esAdminPrincipal &&
                !esPropioUsuario &&
                !esPrincipal;

            String textoRol;

            if (esPrincipal) {
              textoRol = 'Administrador principal';
            } else if (esSubAdmin) {
              textoRol = 'Administrador';
            } else {
              textoRol = 'Cliente';
            }

            return Card(
              margin: const EdgeInsets.only(
                bottom: 12,
              ),
              child: ExpansionTile(
                leading: _avatarUsuario(usuario),
                title: Text(
                  nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (email.isNotEmpty)
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    Text(
                      textoRol,
                      style: TextStyle(
                        color: esPrincipal
                            ? Colors.orange
                            : esSubAdmin
                                ? AppColors.lilaOscuro
                                : Colors.black54,
                        fontWeight: esPrincipal || esSubAdmin
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
                childrenPadding: const EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  16,
                ),
                children: [
                  const Divider(),
                  Row(
                    children: [
                      Expanded(
                        child: _datoUsuario(
                          titulo: 'Disponibles',
                          valor: '$disponibles',
                          icono: Icons.card_giftcard,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _datoUsuario(
                          titulo: 'Utilizadas',
                          valor: '$utilizadas',
                          icono: Icons.redeem,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _regalarMuestra(
                          uid: uid,
                          nombre: nombre,
                        );
                      },
                      icon: const Icon(
                        Icons.card_giftcard,
                      ),
                      label: const Text(
                        'Regalar +1 muestra',
                      ),
                    ),
                  ),
                  if (puedeCambiarRol) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _cambiarRol(
                            uid: uid,
                            nombre: nombre,
                            rolActual: rol,
                          );
                        },
                        icon: Icon(
                          esSubAdmin
                              ? Icons.person_remove
                              : Icons.admin_panel_settings,
                        ),
                        label: Text(
                          esSubAdmin
                              ? 'Quitar administrador'
                              : 'Hacer administrador',
                        ),
                      ),
                    ),
                  ],
                  if (esPrincipal) ...[
                    const SizedBox(height: 10),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.workspace_premium,
                          size: 20,
                          color: Colors.orange,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Administrador principal',
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (esPropioUsuario && !esPrincipal) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'Esta es tu cuenta actual.',
                      style: TextStyle(
                        color: Colors.black54,
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
  }

  // ============================================================
  // PRODUCTOS
  // ============================================================

  Widget _buildProductos() {
    return StreamBuilder<List<Product>>(
      stream: _productService.observarProductos(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.cloud_off,
                    size: 60,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 15),
                  Text(
                    'No se pudo leer el catálogo.\n'
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

        final List<Product> productos = snapshot.data ?? [];

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Gestión de productos',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Los cambios de precio se reflejan '
              'en tiempo real en el catálogo.',
              style: TextStyle(
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 14),
            ...productos.map(
              (producto) {
                return Card(
                  margin: const EdgeInsets.only(
                    bottom: 10,
                  ),
                  child: ListTile(
                    leading: SizedBox(
                      width: 54,
                      height: 54,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          10,
                        ),
                        child: Image.asset(
                          producto.imagen,
                          fit: BoxFit.cover,
                          errorBuilder: (
                            context,
                            error,
                            stackTrace,
                          ) {
                            return Container(
                              color: Colors.grey.shade200,
                              child: const Icon(
                                Icons.local_drink,
                                color: AppColors.lilaOscuro,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    title: Text(
                      producto.nombre,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      '${producto.cantidadMl} ml\n'
                      '${producto.precio.toStringAsFixed(2)} Bs',
                    ),
                    isThreeLine: true,
                    trailing: producto.esGratis
                        ? const Chip(
                            label: Text(
                              'GRATIS',
                            ),
                          )
                        : IconButton(
                            tooltip: 'Editar precio',
                            icon: const Icon(
                              Icons.edit,
                              color: AppColors.lilaOscuro,
                            ),
                            onPressed: () {
                              _editarPrecio(
                                producto,
                              );
                            },
                          ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // PANTALLA PRINCIPAL ADMIN
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final UserProvider userProvider = Provider.of<UserProvider>(context);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            userProvider.esAdminPrincipal
                ? 'Admin Principal CHICHEJ'
                : 'Administración CHICHEJ',
          ),
          backgroundColor: AppColors.lilaOscuro,
          bottom: const TabBar(
            tabs: [
              Tab(
                icon: Icon(
                  Icons.dashboard,
                ),
                text: 'Resumen',
              ),
              Tab(
                icon: Icon(
                  Icons.people,
                ),
                text: 'Usuarios',
              ),
              Tab(
                icon: Icon(
                  Icons.local_drink,
                ),
                text: 'Productos',
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildResumen(),
            _buildUsuarios(
              userProvider,
            ),
            _buildProductos(),
          ],
        ),
      ),
    );
  }
}
