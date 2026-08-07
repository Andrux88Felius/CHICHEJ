import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../models/product_model.dart';
import 'product_detail_page.dart';
import 'cart_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.user;

    final List<Map<String, String>> todosLosProductos = [
      {"nombre": "Prueba Gratis", "img": "assets/productos/45ml.png", "option": "1"},
      {"nombre": "150ml", "img": "assets/productos/150ml.png", "option": "2"},
      {"nombre": "250ml", "img": "assets/productos/250ml.png", "option": "3"},
      {"nombre": "500ml", "img": "assets/productos/500ml.png", "option": "4"},
      {"nombre": "750ml", "img": "assets/productos/750ml.png", "option": "5"},
      {"nombre": "1000ml", "img": "assets/productos/1000ml.png", "option": "6"},
    ];

    final List<Map<String, String>> productosMostrados = (user == null || user.nombre == "Invitado")
        ? todosLosProductos.where((p) => p['nombre'] != "Prueba Gratis").toList()
        : todosLosProductos;

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
              backgroundImage: user?.avatarPath != null 
                  ? AssetImage(user!.avatarPath!) 
                  : const AssetImage('assets/avatares/invitado.png'),
            ),
            const SizedBox(width: 15),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Hola,", style: TextStyle(fontSize: 12, color: Colors.grey)),
                Text(
                  user?.nombre ?? "Invitado",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: IconButton(
              icon: const Icon(Icons.shopping_cart, color: Colors.deepPurple, size: 30),
              onPressed: () {
                Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CartPage()),
        );
              },
            ),
          ),
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(15),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.73,
          crossAxisSpacing: 15,
          mainAxisSpacing: 15,
        ),
        itemCount: productosMostrados.length,
        itemBuilder: (context, index) {
          final producto = productosMostrados[index];
          final bool esGratis = producto["nombre"] == "Prueba Gratis";

          // Definir datos para la navegación
          double precio = _obtenerPrecio(producto["nombre"]!);
          
          final Product productoObj = Product(
            nombre: producto["nombre"]!,
            descripcion: "Tradición y sabor en cada gota de ${producto["nombre"]}.",
            precio: precio,
            imagen: producto["img"]!,
            option: int.parse(producto["option"]!),
            esGratis: esGratis,
          );

          return InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ProductDetailPage(producto: productoObj)),
              );
            },
            child: Card(
              elevation: 5,
              color: esGratis ? const Color(0xFFFFF8D6) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                      child: Image.asset(producto["img"]!, fit: BoxFit.cover),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                    child: Column(
                      children: [
                        Text(
                          producto["nombre"]!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        const SizedBox(height: 6),
                        esGratis
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(width: 6),
                                  Text(" 🎁 GRATIS", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 18)),
                                ],
                              )
                            : Text(
                                "$precio Bs",
                                style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold, fontSize: 17),
                              ),
                        if (esGratis)
                          const Padding(
                            padding: EdgeInsets.only(top: 5),
                            child: Text("Solo por registro", textAlign: TextAlign.center, style: TextStyle(color: Colors.black54, fontSize: 12)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  double _obtenerPrecio(String nombre) {
    switch (nombre) {
      case "150ml": return 3.0;
      case "250ml": return 5.0;
      case "500ml": return 10.0;
      case "750ml": return 15.0;
      case "1000ml": return 20.0;
      default: return 0.0;
    }
  }
}