import 'package:flutter/material.dart';
import '../utils/colors.dart';

class QrPaymentPage extends StatelessWidget {
  final double total;

  const QrPaymentPage({
    super.key,
    required this.total,
  });

  // Devuelve el QR correspondiente al monto
  String _obtenerAssetQr(double monto) {
    final double montoRedondeado =
        double.parse(monto.toStringAsFixed(1));

    final Map<double, String> qrsExactos = {
      3.0: 'assets/qr3.jpeg',
      5.0: 'assets/qr5.jpeg',
      10.0: 'assets/qr10.jpeg',
      15.0: 'assets/qr15.jpeg',
      20.0: 'assets/qr20.jpeg',
    };

    debugPrint(
      "Monto recibido: $monto | Monto redondeado: $montoRedondeado",
    );

    return qrsExactos[montoRedondeado] ??
        'assets/qrlibre.jpeg';
  }

  @override
  Widget build(BuildContext context) {
    final String assetPath = _obtenerAssetQr(total);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("Pago mediante QR"),
        backgroundColor: AppColors.lilaOscuro,
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(25),
          child: Column(
            children: [
            
              const SizedBox(height: 10),
      
              const Text(
                "Escanea este código QR para realizar tu pago",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
      
              const SizedBox(height: 15),
      
              Text(
                "Monto: ${total.toStringAsFixed(2)} Bs",
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
      
              const SizedBox(height: 25),
      
              Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Image.asset(
                    assetPath,
                    width: 260,
                    height: 260,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
      
              const SizedBox(height: 30),
      
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.download),
                  label: const Text(
                    "Guardar QR",
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.dorado,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "La descarga estará disponible en la próxima actualización.",
                        ),
                      ),
                    );
                  },
                ),
              ),
      
              const SizedBox(height: 15),
      
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.local_drink),
                  label: const Text(
                    "Dispensar",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Próximamente conectado con el dispensador.",
                        ),
                      ),
                    );
                  },
                ),
              ),
      
              const SizedBox(height: 25),
      
              const Text(
                "Una vez realizado el pago, presiona DISPENSAR para enviar el pedido al dispensador automático.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                ),
              ),
      
              const SizedBox(height: 20),
      
            ],
          ),
        ),
      ),
    );
  }
}