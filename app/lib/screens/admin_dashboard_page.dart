import 'package:flutter/material.dart';

import '../models/product_model.dart';
import '../services/product_service.dart';
import '../utils/colors.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final ProductService _productService = ProductService();

  Future<void> _editarPrecio(Product producto) async {
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
              prefixIcon: Icon(Icons.payments),
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
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final texto = textoPrecio.trim().replaceAll(',', '.');

                final valor = double.tryParse(texto);

                if (valor == null || valor < 0) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
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
              child: const Text('Guardar'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administración CHICHEJ'),
        backgroundColor: AppColors.lilaOscuro,
      ),
      body: StreamBuilder<List<Product>>(
        stream: _productService.observarProductos(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.cloud_off,
                      size: 70,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'No se pudo leer el catálogo '
                      'administrativo.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${snapshot.error}',
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

          final productos = snapshot.data ?? [];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Card(
                child: ListTile(
                  leading: Icon(
                    Icons.dashboard,
                    color: AppColors.lilaOscuro,
                  ),
                  title: Text(
                    'Panel administrativo',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    'Gestión inicial de productos '
                    'y precios.',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Productos',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              ...productos.map(
                (producto) => Card(
                  child: ListTile(
                    leading: SizedBox(
                      width: 50,
                      height: 50,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset(
                          producto.imagen,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
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
                            label: Text('GRATIS'),
                          )
                        : IconButton(
                            tooltip: 'Editar precio',
                            icon: const Icon(
                              Icons.edit,
                              color: AppColors.lilaOscuro,
                            ),
                            onPressed: () => _editarPrecio(producto),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Card(
                child: ListTile(
                  enabled: false,
                  leading: Icon(
                    Icons.analytics,
                  ),
                  title: Text('Reportes y estadísticas'),
                  subtitle: Text(
                    'Ventas, usuarios, bebidas y PDF '
                    'se implementarán después de '
                    'integrar los pedidos reales.',
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
