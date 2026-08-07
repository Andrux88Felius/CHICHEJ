import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/cart_provider.dart';
import '../providers/order_provider.dart';
import '../utils/colors.dart';
import 'qr_payment_page.dart';
import '../providers/user_provider.dart';

class CartPage extends StatelessWidget {
  const CartPage({super.key});

  Future<void> _enviarMensajeWhatsApp(double total) async {
    const String numero = "59173085467";

    final String mensaje =
        "Hola, se ha realizado un nuevo pedido en CHICHEJ.\n"
        "Método de pago: Efectivo.\n"
        "Total: ${total.toStringAsFixed(2)} Bs.";

    final Uri url = Uri.parse(
      "https://wa.me/$numero?text=${Uri.encodeComponent(mensaje)}",
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final carritoProvider = Provider.of<CartProvider>(context);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    debugPrint("Usuario:${userProvider.user?.nombre}");
    debugPrint("Rol:${userProvider.user?.rol}");
    final bool esAdmin = userProvider.user?.rol == "admin";

    return Scaffold(
      appBar: AppBar(
        title: const Text("Carrito 🛒"),
        backgroundColor: AppColors.lilaOscuro,
      ),

      body: carritoProvider.carrito.isEmpty
          ? const Center(
              child: Text(
                "Tu carrito está vacío",
                style: TextStyle(fontSize: 18),
              ),
            )
          : Column(
              children: [

                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    itemCount: carritoProvider.carrito.length,
                    itemBuilder: (context, index) {

                      final item = carritoProvider.carrito[index];

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        child: ListTile(

                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.asset(
                              item.producto.imagen,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                            ),
                          ),

                          title: Text(
                            item.producto.nombre,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          subtitle: Text(
                            "${item.producto.precio} Bs x ${item.cantidad} = ${item.subtotal.toStringAsFixed(2)} Bs",
                          ),

                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [

                              IconButton(
                                icon: const Icon(
                                  Icons.remove_circle_outline,
                                  color: Colors.grey,
                                ),
                                onPressed: () =>
                                    carritoProvider.decrementar(item),
                              ),

                              Text(
                                "${item.cantidad}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              IconButton(
                                icon: const Icon(
                                  Icons.add_circle_outline,
                                  color: Colors.green,
                                ),
                                onPressed: () =>
                                    carritoProvider.incrementar(item),
                              ),

                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () =>
                                    carritoProvider.eliminar(item),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                      )
                    ],
                  ),
                  child: Column(
                    children: [

                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [

                          const Text(
                            "Total a pagar:",
                            style: TextStyle(fontSize: 18),
                          ),

                          Text(
                            "${carritoProvider.total().toStringAsFixed(2)} Bs",
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 15),

                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(

                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.dorado,
                          ),

                          onPressed: () {
                            if (esAdmin) {

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Modo administrador: Dispensado directo."),
                                ),
                              );

                              return;
                            }

                            showDialog(
                              context: context,
                              builder: (_) {

                                return AlertDialog(

                                  title: const Text(
                                    "Seleccionar método de pago",
                                  ),

                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [

                                      ///==========================
                                      /// PAGO QR
                                      ///==========================

                                      ListTile(

                                        leading: const Icon(
                                          Icons.qr_code,
                                          color: AppColors.lilaOscuro,
                                        ),

                                        title: const Text(
                                          "Pagar con QR",
                                        ),

                                        onTap: () {

                                          Navigator.pop(context);

                                          final orderProvider =
                                              Provider.of<OrderProvider>(
                                            context,
                                            listen: false,
                                          );

                                          /// Guardamos el total
                                          final double totalCompra =
                                              carritoProvider.total();

                                          /// Copiamos los productos
                                          final productos =
                                              carritoProvider.carrito.toList();

                                          /// Guardamos historial
                                          orderProvider.agregarCompra(
                                            productos,
                                            totalCompra,
                                          );

                                          /// Abrimos QR
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  QrPaymentPage(
                                                total: totalCompra,
                                              ),
                                            ),
                                          ).then((_) {

                                            /// Cuando vuelva del QR
                                            carritoProvider.limpiar();

                                          });
                                        },
                                      ),

                                      ///==========================
                                      /// EFECTIVO
                                      ///==========================

                                      ListTile(

                                        leading: const Icon(
                                          Icons.money,
                                          color: Colors.green,
                                        ),

                                        title: const Text(
                                          "Pago en efectivo",
                                        ),

                                        onTap: () async {

                                          Navigator.pop(context);

                                          final orderProvider =
                                              Provider.of<OrderProvider>(
                                            context,
                                            listen: false,
                                          );

                                          final totalCompra =
                                              carritoProvider.total();

                                          final productos =
                                              carritoProvider.carrito.toList();

                                          orderProvider.agregarCompra(
                                            productos,
                                            totalCompra,
                                          );

                                          await _enviarMensajeWhatsApp(
                                            totalCompra,
                                          );

                                          carritoProvider.limpiar();

                                          Navigator.pop(context);

                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                "Pedido realizado correctamente.",
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },

                          child: const Text(
                            "Finalizar Compra",
                            style: TextStyle(
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