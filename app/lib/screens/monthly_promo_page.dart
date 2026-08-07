import 'package:flutter/material.dart';
import '../utils/colors.dart';

class MonthlyPromoPage extends StatelessWidget {
  const MonthlyPromoPage({super.key});

  final List<String> _promos = const [
    'assets/promos/enero.png', 'assets/promos/febrero.png', 'assets/promos/marzo.png',
    'assets/promos/abril.png', 'assets/promos/mayo.png', 'assets/promos/junio.png',
    'assets/promos/julio.png', 'assets/promos/agosto.png', 'assets/promos/septiembre.png',
    'assets/promos/octubre.png', 'assets/promos/noviembre.png', 'assets/promos/diciembre.png',
  ];

  @override
  Widget build(BuildContext context) {
    // Detecta el mes actual: 1 es enero, 7 es julio
    int mesActual = DateTime.now().month; 
    String imagenPromo = _promos[mesActual - 1];

    return Scaffold(
      appBar: AppBar(title: const Text("Promoción de Julio"), backgroundColor: AppColors.lilaOscuro),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: Image.asset(imagenPromo, fit: BoxFit.cover),
              ),
              const SizedBox(height: 20),
              const Text("¡Promoción exclusiva de este mes!", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}