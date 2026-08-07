import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product_model.dart';
import '../providers/cart_provider.dart';
import '../utils/colors.dart';
import 'cart_page.dart';

class ProductDetailPage extends StatelessWidget {
  final Product producto;

  const ProductDetailPage({super.key, required this.producto});

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: AppColors.lilaOscuro,
        elevation: 0,
        centerTitle: true,
        title: Text(producto.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),

      // Acceso rápido al carrito
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color.fromARGB(255, 114, 7, 255),
        elevation: 6,
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartPage())),
        child: const Icon(Icons.shopping_cart, color: Colors.white),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            // 🖼️ FOTO
            Hero(
              tag: producto.nombre,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  producto.imagen,
                  width: double.infinity,
                  height: 330,
                  fit: BoxFit.cover,
                ),
              ),
            ),

            const SizedBox(height: 22),

            // 🧾 TARJETA DE DETALLES
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: producto.esGratis ? const Color(0xFFFFF8D6) : Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(color: Colors.grey.withOpacity(.15), blurRadius: 12, offset: const Offset(0, 5))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(producto.nombre, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 14),
                  Text(producto.descripcion, style: TextStyle(fontSize: 16, color: Colors.grey.shade700, height: 1.4)),
                  const SizedBox(height: 25),

                  // 💰 CONTENEDOR DE PRECIO
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: producto.esGratis ? Colors.green.shade50 : Colors.deepPurple.shade50,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      children: [
                        if (!producto.esGratis) ...[
                          Icon(Icons.payments, color: AppColors.lilaOscuro),
                          const SizedBox(width: 10),
                        ],
                        Text(
                          producto.esGratis ? "🎁 GRATIS" : "${producto.precio} Bs",
                          style: TextStyle(
                            color: producto.esGratis ? Colors.green : AppColors.lilaOscuro,
                            fontSize: 24, fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 35),

            // 🛒 BOTÓN AGREGAR (Único, grande y limpio)
            SizedBox(
              width: double.infinity,
              height: 58,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add_shopping_cart, color: Colors.black),
                label: const Text(
                  "AGREGAR AL CARRITO",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.black),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.dorado,
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).clearSnackBars();
                  final cantidad = cart.agregar(producto);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("${producto.nombre} agregado x$cantidad 🛒"),
                      backgroundColor: AppColors.lilaOscuro,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}