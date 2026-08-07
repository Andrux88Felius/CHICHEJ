import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/cart_provider.dart';
import '../providers/order_provider.dart';
import '../providers/user_provider.dart';
import '../services/firestore_service.dart';
import '../utils/colors.dart';
import 'cart_item.dart';
import 'qr_payment_page.dart';

class CartPage extends StatelessWidget {
  const CartPage({super.key});

  Future<void> _enviarMensajeWhatsApp(
    double total,
  ) async {
    const String numero = '59173085467';

    final String mensaje = 'Hola, se ha realizado un nuevo pedido en CHICHEJ.\n'
        'Método de pago: Efectivo.\n'
        'Total: ${total.toStringAsFixed(2)} Bs.';

    final Uri url = Uri.parse(
      'https://wa.me/$numero?text=${Uri.encodeComponent(mensaje)}',
    );

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(
          url,
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (error) {
      // El pedido ya pudo haberse registrado.
      // Una falla de WhatsApp no debe cancelar
      // ni devolver una muestra.
      debugPrint(
        'No se pudo abrir WhatsApp: $error',
      );
    }
  }

  List<CartItem> _copiarCarrito(
    CartProvider provider,
  ) {
    return provider.carrito
        .map(
          (item) => CartItem(
            producto: item.producto,
            cantidad: item.cantidad,
          ),
        )
        .toList();
  }

  String _tipoUsuario(
    UserProvider userProvider,
  ) {
    if (userProvider.esAdmin) {
      return 'admin';
    }

    if (userProvider.esInvitado) {
      return 'invitado';
    }

    return 'registrado';
  }

  bool _contieneMuestra(
    List<CartItem> items,
  ) {
    return items.any(
      (item) => item.producto.esGratis,
    );
  }

  Future<void> _procesarPedidoAdmin(
    BuildContext context,
    CartProvider carritoProvider,
    UserProvider userProvider,
  ) async {
    final FirestoreService firestoreService = FirestoreService();

    final List<CartItem> items = _copiarCarrito(carritoProvider);

    final double total = carritoProvider.total();

    if (items.isEmpty) {
      return;
    }

    try {
      final String pedidoId = await firestoreService.crearPedido(
        tipoUsuario: 'admin',
        usuarioId: userProvider.uid,
        sesionInvitadoId: null,
        nombreUsuario: userProvider.user?.nombre ?? 'Administrador',
        email: userProvider.user?.email ?? '',
        items: items,
        metodoPago: 'admin',
        estadoPago: 'no_requerido',
      );

      if (!context.mounted) {
        return;
      }

      Provider.of<OrderProvider>(
        context,
        listen: false,
      ).agregarCompra(
        items,
        total,
      );

      carritoProvider.limpiar();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Pedido administrativo enviado.\n'
            'ID: $pedidoId',
          ),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo enviar el pedido: '
            '$error',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _procesarPagoEfectivo(
    BuildContext context,
    CartProvider carritoProvider,
    UserProvider userProvider,
  ) async {
    final FirestoreService firestoreService = FirestoreService();

    final List<CartItem> items = _copiarCarrito(carritoProvider);

    final double total = carritoProvider.total();

    if (items.isEmpty) {
      return;
    }

    final bool esInvitado = userProvider.esInvitado;

    final bool contieneMuestra = _contieneMuestra(items);

    // Protección extra:
    // un invitado no puede utilizar una muestra,
    // aunque hubiera quedado una en el carrito
    // por un cambio de sesión.
    if (esInvitado && contieneMuestra) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La muestra gratuita requiere '
            'una cuenta registrada.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );

      return;
    }

    bool muestraConsumida = false;

    if (contieneMuestra && userProvider.esRegistrado) {
      muestraConsumida = await userProvider.consumirMuestraGratis();

      if (!muestraConsumida) {
        if (!context.mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'La muestra gratuita ya no '
              'está disponible.',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );

        return;
      }
    }

    String pedidoId;

    // Este try/catch protege únicamente
    // la creación del pedido.
    try {
      pedidoId = await firestoreService.crearPedido(
        tipoUsuario: _tipoUsuario(userProvider),
        usuarioId: esInvitado ? null : userProvider.uid,
        sesionInvitadoId: esInvitado ? userProvider.sesionInvitadoId : null,
        nombreUsuario: userProvider.user?.nombre ?? 'Invitado',
        email: userProvider.user?.email ?? '',
        items: items,
        metodoPago: 'efectivo',
        estadoPago: 'aprobado',
      );
    } catch (error) {
      // Firestore falló:
      // restauramos el beneficio.
      if (muestraConsumida) {
        await userProvider.devolverMuestraGratis();
      }

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo crear el pedido: '
            '$error',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );

      return;
    }

    // Desde este punto el pedido YA existe.
    // No debemos devolver una muestra aunque
    // luego falle WhatsApp.

    if (!context.mounted) {
      return;
    }

    if (!esInvitado) {
      Provider.of<OrderProvider>(
        context,
        listen: false,
      ).agregarCompra(
        items,
        total,
      );
    }

    carritoProvider.limpiar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Pedido realizado correctamente.\n'
          'ID: $pedidoId',
        ),
        backgroundColor: Colors.green,
      ),
    );

    // WhatsApp es complementario.
    // No forma parte de la transacción del pedido.
    await _enviarMensajeWhatsApp(total);

    if (!context.mounted) {
      return;
    }

    Navigator.pop(context);
  }

  Future<void> _procesarPagoQr(
    BuildContext context,
    CartProvider carritoProvider,
    UserProvider userProvider,
  ) async {
    final List<CartItem> items = _copiarCarrito(carritoProvider);

    final double total = carritoProvider.total();

    if (items.isEmpty) {
      return;
    }

    final bool esInvitado = userProvider.esInvitado;

    final bool contieneMuestra = _contieneMuestra(items);

    if (esInvitado && contieneMuestra) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La muestra gratuita requiere '
            'una cuenta registrada.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );

      return;
    }

    // El QR todavía depende de que
    // QrPaymentPage retorne true.
    final bool? pagoConfirmado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => QrPaymentPage(
          total: total,
        ),
      ),
    );

    if (!context.mounted) {
      return;
    }

    if (pagoConfirmado != true) {
      return;
    }

    bool muestraConsumida = false;

    if (contieneMuestra && userProvider.esRegistrado) {
      muestraConsumida = await userProvider.consumirMuestraGratis();

      if (!muestraConsumida) {
        if (!context.mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'La muestra gratuita ya no '
              'está disponible.',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );

        return;
      }
    }

    final FirestoreService firestoreService = FirestoreService();

    String pedidoId;

    try {
      pedidoId = await firestoreService.crearPedido(
        tipoUsuario: _tipoUsuario(userProvider),
        usuarioId: esInvitado ? null : userProvider.uid,
        sesionInvitadoId: esInvitado ? userProvider.sesionInvitadoId : null,
        nombreUsuario: userProvider.user?.nombre ?? 'Invitado',
        email: userProvider.user?.email ?? '',
        items: items,
        metodoPago: 'qr',
        estadoPago: 'aprobado',
      );
    } catch (error) {
      if (muestraConsumida) {
        await userProvider.devolverMuestraGratis();
      }

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo enviar el pedido: '
            '$error',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );

      return;
    }

    if (!context.mounted) {
      return;
    }

    if (!esInvitado) {
      Provider.of<OrderProvider>(
        context,
        listen: false,
      ).agregarCompra(
        items,
        total,
      );
    }

    carritoProvider.limpiar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Pago confirmado y pedido enviado.\n'
          'ID: $pedidoId',
        ),
        backgroundColor: Colors.green,
      ),
    );

    Navigator.pop(context);
  }

  void _mostrarMetodosPago(
    BuildContext context,
    CartProvider carritoProvider,
    UserProvider userProvider,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Seleccionar método de pago',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.qr_code,
                  color: AppColors.lilaOscuro,
                ),
                title: const Text(
                  'Pagar con QR',
                ),
                subtitle: const Text(
                  'Yape / QR',
                ),
                onTap: () {
                  Navigator.pop(
                    dialogContext,
                  );

                  _procesarPagoQr(
                    context,
                    carritoProvider,
                    userProvider,
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(
                  Icons.money,
                  color: Colors.green,
                ),
                title: const Text(
                  'Pago en efectivo',
                ),
                subtitle: const Text(
                  'Confirmación directa',
                ),
                onTap: () {
                  Navigator.pop(
                    dialogContext,
                  );

                  _procesarPagoEfectivo(
                    context,
                    carritoProvider,
                    userProvider,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final CartProvider carritoProvider = Provider.of<CartProvider>(
      context,
    );

    final UserProvider userProvider = Provider.of<UserProvider>(
      context,
    );

    final bool esAdmin = userProvider.esAdmin;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Carrito 🛒',
        ),
        backgroundColor: AppColors.lilaOscuro,
      ),
      body: carritoProvider.carrito.isEmpty
          ? const Center(
              child: Text(
                'Tu carrito está vacío',
                style: TextStyle(
                  fontSize: 18,
                ),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                    ),
                    itemCount: carritoProvider.carrito.length,
                    itemBuilder: (
                      context,
                      index,
                    ) {
                      final CartItem item = carritoProvider.carrito[index];

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 4,
                          ),
                          child: ListTile(
                            leading: SizedBox(
                              width: 50,
                              height: 50,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  8,
                                ),
                                child: Image.asset(
                                  item.producto.imagen,
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
                              item.producto.nombre,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              item.producto.esGratis
                                  ? 'GRATIS × ${item.cantidad}'
                                  : '${item.producto.precio.toStringAsFixed(2)} Bs '
                                      '× ${item.cantidad} = '
                                      '${item.subtotal.toStringAsFixed(2)} Bs',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.remove_circle_outline,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () {
                                    carritoProvider.decrementar(
                                      item,
                                    );
                                  },
                                ),
                                Text(
                                  '${item.cantidad}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.add_circle_outline,
                                    color: item.producto.esGratis && !esAdmin
                                        ? Colors.grey
                                        : Colors.green,
                                  ),
                                  onPressed: item.producto.esGratis && !esAdmin
                                      ? null
                                      : () {
                                          carritoProvider.incrementar(
                                            item,
                                            permitirMultiplesGratis: esAdmin,
                                          );
                                        },
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () {
                                    carritoProvider.eliminar(
                                      item,
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(
                    20,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            esAdmin ? 'Total dispensado:' : 'Total a pagar:',
                            style: const TextStyle(
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            '${carritoProvider.total().toStringAsFixed(2)} Bs',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: 6,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Cantidad total:',
                            style: TextStyle(
                              color: Colors.black54,
                            ),
                          ),
                          Text(
                            '${carritoProvider.cantidadTotalMl()} ml',
                            style: const TextStyle(
                              color: Colors.black54,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: 15,
                      ),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.dorado,
                          ),
                          onPressed: () {
                            if (esAdmin) {
                              _procesarPedidoAdmin(
                                context,
                                carritoProvider,
                                userProvider,
                              );

                              return;
                            }

                            _mostrarMetodosPago(
                              context,
                              carritoProvider,
                              userProvider,
                            );
                          },
                          icon: Icon(
                            esAdmin
                                ? Icons.local_drink
                                : Icons.shopping_cart_checkout,
                            color: Colors.black,
                          ),
                          label: Text(
                            esAdmin ? 'Dispensar' : 'Finalizar compra',
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
