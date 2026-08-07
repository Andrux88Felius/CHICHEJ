import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/product_data.dart';
import '../models/product_model.dart';
import '../providers/user_provider.dart';
import '../services/product_service.dart';
import 'cart_page.dart';
import 'product_detail_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final UserProvider userProvider = Provider.of<UserProvider>(context);

    final user = userProvider.user;

    final bool esInvitado = userProvider.esInvitado;
    final bool esAdmin = userProvider.esAdmin;

    final ProductService productService = ProductService();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 80,
        title: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: Colors.white,
              backgroundImage: AssetImage(
                esAdmin
                    ? UserProvider.avatarAdmin
                    : user?.avatarPath ?? 'assets/avatares/invitado.png',
              ),
            ),
            const SizedBox(width: 15),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Hola,',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  user?.nombre ?? 'Invitado',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: IconButton(
              icon: const Icon(
                Icons.shopping_cart,
                color: Colors.deepPurple,
                size: 30,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CartPage(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<Product>>(
        stream: productService.observarProductos(),
        builder: (context, snapshot) {
          List<Product> catalogo;

          if (snapshot.hasError) {
            catalogo = productosFallback;
          } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            catalogo = snapshot.data!;
          } else if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          } else {
            catalogo = productosFallback;
          }

          final productosDisponibles = catalogo.where((producto) {
            if (!producto.activo) {
              return false;
            }

            if (!producto.esGratis) {
              return true;
            }

            if (esAdmin) {
              return true;
            }

            if (esInvitado) {
              return false;
            }

            return (user?.muestrasGratisDisponibles ?? 0) > 0;
          }).toList();

          return GridView.builder(
            padding: const EdgeInsets.all(15),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.73,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
            ),
            itemCount: productosDisponibles.length,
            itemBuilder: (context, index) {
              final Product producto = productosDisponibles[index];

              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProductDetailPage(
                        producto: producto,
                      ),
                    ),
                  );
                },
                child: Card(
                  elevation: 5,
                  color: producto.esGratis
                      ? const Color(0xFFFFF8D6)
                      : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(18),
                          ),
                          child: Hero(
                            tag: producto.productoId,
                            child: Image.asset(
                              producto.imagen,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          8,
                          8,
                          8,
                          12,
                        ),
                        child: Column(
                          children: [
                            Text(
                              producto.nombre,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 6),
                            producto.esGratis
                                ? const Text(
                                    '🎁 GRATIS',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  )
                                : Text(
                                    '${producto.precio.toStringAsFixed(2)} Bs',
                                    style: const TextStyle(
                                      color: Colors.deepPurple,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 17,
                                    ),
                                  ),
                            if (producto.esGratis)
                              const Padding(
                                padding: EdgeInsets.only(top: 5),
                                child: Text(
                                  'Beneficio disponible',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.black54,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
