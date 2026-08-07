import 'package:flutter/material.dart';

import '../utils/colors.dart';

class MonthlyPromoPage extends StatelessWidget {
  const MonthlyPromoPage({
    super.key,
  });

  static const List<String> _promos = [
    'assets/promos/enero.png',
    'assets/promos/febrero.png',
    'assets/promos/marzo.png',
    'assets/promos/abril.png',
    'assets/promos/mayo.png',
    'assets/promos/junio.png',
    'assets/promos/julio.png',
    'assets/promos/agosto.png',
    'assets/promos/septiembre.png',
    'assets/promos/octubre.png',
    'assets/promos/noviembre.png',
    'assets/promos/diciembre.png',
  ];

  static const List<String> _meses = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];

  @override
  Widget build(BuildContext context) {
    final int mesActual = DateTime.now().month;

    final String imagenPromo = _promos[mesActual - 1];

    final String nombreMes = _meses[mesActual - 1];

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(
          'Promoción de $nombreMes',
        ),
        backgroundColor: AppColors.lilaOscuro,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(
                25,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 12,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(
                25,
              ),
              child: Image.asset(
                imagenPromo,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '¡Promoción exclusiva '
            'de este mes!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Compra productos CHICHEJ '
            'y acumula beneficios para '
            'futuras promociones.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black54,
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
