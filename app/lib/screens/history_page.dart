import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/order_provider.dart';
import '../utils/colors.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<OrderProvider>(context);
    
    // Sumamos la cantidad de pedidos y reservas
    final int totalItems = provider.historial.length + provider.reservas.length;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Historial de Pedidos 📜", style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.lilaOscuro,
        elevation: 0,
      ),
      body: totalItems == 0
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 80, color: Colors.grey),
                  Text("Aún no tienes registros", style: TextStyle(fontSize: 16, color: Colors.grey)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: totalItems,
              itemBuilder: (context, index) {
                // Lógica para separar pedidos normales de reservas
                if (index < provider.historial.length) {
                  // ES UN PEDIDO NORMAL
                  final order = provider.historial[index];
                  return Card(
                    elevation: 3,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    child: ExpansionTile(
                      leading: const CircleAvatar(backgroundColor: AppColors.dorado, child: Icon(Icons.shopping_bag, color: Colors.black)),
                      title: Text("Pedido #${index + 1}", style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("${order.fecha.day}/${order.fecha.month} - Total: ${order.total.toStringAsFixed(2)} Bs"),
                      children: [
                        const Divider(),
                        ...order.items.map((item) => ListTile(
                          dense: true,
                          leading: ClipRRect(borderRadius: BorderRadius.circular(5), child: Image.asset(item.producto.imagen, width: 35, height: 35, fit: BoxFit.cover)),
                          title: Text("${item.producto.nombre} x${item.cantidad}"),
                          trailing: Text(item.producto.esGratis ? "GRATIS" : "${(item.producto.precio * item.cantidad).toStringAsFixed(2)} Bs"),
                        )),
                      ],
                    ),
                  );
                } else {
                  // ES UNA RESERVA DE EVENTO
                  final resIndex = index - provider.historial.length;
                  final reserva = provider.reservas[resIndex];
                  final DateTime fecha = reserva['fecha'];
                  
                  return Card(
                    elevation: 3,
                    margin: const EdgeInsets.only(bottom: 12),
                    color: Colors.orange.shade50, // Color diferenciador
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    child: ListTile(
                      leading: const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.event, color: Colors.white)),
                      title: Text("Reserva: ${reserva['evento']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("Fecha: ${fecha.day}/${fecha.month}/${fecha.year} • Cantidad: ${reserva['cantidad']} uds."),
                      trailing: Chip(
                        label: Text(reserva['estado'], style: const TextStyle(fontSize: 12)),
                        backgroundColor: Colors.orange.shade200,
                      ),
                    ),
                  );
                }
              },
            ),
    );
  }
}