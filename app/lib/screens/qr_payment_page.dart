import 'package:flutter/material.dart';

import '../utils/colors.dart';

class QrPaymentPage extends StatelessWidget {
  final double total;

  const QrPaymentPage({
    super.key,
    required this.total,
  });

  String _obtenerAssetQr(double monto) {
    final double montoRedondeado = double.parse(monto.toStringAsFixed(1));

    final Map<double, String> qrsExactos = {
      3.0: 'assets/qr3.jpeg',
      5.0: 'assets/qr5.jpeg',
      10.0: 'assets/qr10.jpeg',
      15.0: 'assets/qr15.jpeg',
      20.0: 'assets/qr20.jpeg',
    };

    return qrsExactos[montoRedondeado] ?? 'assets/qrlibre.jpeg';
  }

  bool _usaQrLibre(double monto) {
    final double montoRedondeado = double.parse(monto.toStringAsFixed(1));

    return ![
      3.0,
      5.0,
      10.0,
      15.0,
      20.0,
    ].contains(montoRedondeado);
  }

  Future<void> _confirmarPago(
    BuildContext context,
  ) async {
    final bool? confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(
                Icons.verified_outlined,
                color: Colors.green,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Confirmar pago',
                ),
              ),
            ],
          ),
          content: Text(
            '¿Confirmas que realizaste el pago de '
            '${total.toStringAsFixed(2)} Bs?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text(
                'Cancelar',
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              icon: const Icon(
                Icons.check_circle,
              ),
              label: const Text(
                'Sí, pagué',
              ),
            ),
          ],
        );
      },
    );

    if (confirmado != true) {
      return;
    }

    if (!context.mounted) {
      return;
    }

    // Esto regresa a CartPage.
    // CartPage recibe TRUE y recién entonces
    // crea el pedido en Firestore.
    Navigator.pop(
      context,
      true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final String assetPath = _obtenerAssetQr(total);

    final bool qrLibre = _usaQrLibre(total);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'Pago mediante QR',
        ),
        backgroundColor: AppColors.lilaOscuro,
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            20,
            20,
            20,
            30,
          ),
          child: Column(
            children: [
              const Icon(
                Icons.qr_code_2,
                size: 42,
                color: AppColors.lilaOscuro,
              ),
              const SizedBox(height: 8),

              const Text(
                'Escanea el código QR',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                qrLibre
                    ? 'Ingresa manualmente el monto indicado'
                    : 'Realiza el pago desde tu aplicación bancaria',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),

              const SizedBox(height: 18),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.green.shade200,
                  ),
                ),
                child: Column(
                  children: [
                    const Text(
                      'MONTO A PAGAR',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${total.toStringAsFixed(2)} Bs',
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // TARJETA DEL QR
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 15,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: SizedBox(
                        width: double.infinity,
                        height: 410,
                        child: FittedBox(
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                          child: Image.asset(
                            assetPath,
                            width: 330,
                            errorBuilder: (
                              context,
                              error,
                              stackTrace,
                            ) {
                              return Container(
                                width: 330,
                                height: 410,
                                alignment: Alignment.center,
                                color: Colors.grey.shade200,
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.broken_image_outlined,
                                      size: 60,
                                      color: Colors.grey,
                                    ),
                                    SizedBox(
                                      height: 10,
                                    ),
                                    Text(
                                      'No se pudo cargar el QR',
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Eduardo Jordy Zeballos Garcia',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (qrLibre) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(
                            12,
                          ),
                          border: Border.all(
                            color: Colors.orange.shade200,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: Colors.orange,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Este QR no tiene un monto '
                                'predefinido. Ingresa '
                                '${total.toStringAsFixed(2)} Bs '
                                'manualmente antes de pagar.',
                                style: const TextStyle(
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.lilaOscuro.withValues(
                    alpha: 0.08,
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppColors.lilaOscuro,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Después de realizar el pago, '
                        'confírmalo para enviar el pedido '
                        'al dispensador.',
                        style: TextStyle(
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        16,
                      ),
                    ),
                  ),
                  onPressed: () {
                    _confirmarPago(context);
                  },
                  icon: const Icon(
                    Icons.verified,
                  ),
                  label: const Text(
                    'YA REALICÉ EL PAGO',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              TextButton.icon(
                onPressed: () {
                  Navigator.pop(
                    context,
                    false,
                  );
                },
                icon: const Icon(
                  Icons.arrow_back,
                ),
                label: const Text(
                  'Volver sin pagar',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
