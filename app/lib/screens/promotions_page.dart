import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/user_provider.dart';
import '../utils/colors.dart';

class PromotionsPage extends StatefulWidget {
  const PromotionsPage({super.key});

  @override
  State<PromotionsPage> createState() => _PromotionsPageState();
}

class _PromotionsPageState extends State<PromotionsPage> {
  final PageController _pageController = PageController(
    viewportFraction: 0.92,
  );

  Timer? _timer;

  int _paginaActual = 0;

  final List<Map<String, String>> promos = const [
    {
      'imagen': 'assets/promos/enero.png',
      'mes': 'Enero',
    },
    {
      'imagen': 'assets/promos/febrero.png',
      'mes': 'Febrero',
    },
    {
      'imagen': 'assets/promos/marzo.png',
      'mes': 'Marzo',
    },
    {
      'imagen': 'assets/promos/abril.png',
      'mes': 'Abril',
    },
    {
      'imagen': 'assets/promos/mayo.png',
      'mes': 'Mayo',
    },
    {
      'imagen': 'assets/promos/junio.png',
      'mes': 'Junio',
    },
    {
      'imagen': 'assets/promos/julio.png',
      'mes': 'Julio',
    },
    {
      'imagen': 'assets/promos/agosto.png',
      'mes': 'Agosto',
    },
    {
      'imagen': 'assets/promos/septiembre.png',
      'mes': 'Septiembre',
    },
    {
      'imagen': 'assets/promos/octubre.png',
      'mes': 'Octubre',
    },
    {
      'imagen': 'assets/promos/noviembre.png',
      'mes': 'Noviembre',
    },
    {
      'imagen': 'assets/promos/diciembre.png',
      'mes': 'Diciembre',
    },
  ];

  @override
  void initState() {
    super.initState();

    _paginaActual = DateTime.now().month - 1;

    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        if (_pageController.hasClients) {
          _pageController.jumpToPage(
            _paginaActual,
          );
        }
      },
    );

    _timer = Timer.periodic(
      const Duration(seconds: 5),
      (_) {
        if (!_pageController.hasClients) {
          return;
        }

        int siguiente = _paginaActual + 1;

        if (siguiente >= promos.length) {
          siguiente = 0;
        }

        _pageController.animateToPage(
          siguiente,
          duration: const Duration(
            milliseconds: 650,
          ),
          curve: Curves.easeInOutCubic,
        );
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  // ============================================================
  // ESTADÍSTICAS DEL USUARIO
  // ============================================================

  Map<String, int> _calcularEstadisticasUsuario(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String uid,
  ) {
    final DateTime ahora = DateTime.now();

    int comprasMes = 0;
    int bebidasMes = 0;
    int mlMes = 0;

    for (final doc in docs) {
      final Map<String, dynamic> data = doc.data();

      // Solo pedidos del usuario actual.
      if (data['usuarioId']?.toString() != uid) {
        continue;
      }

      // Solamente compras válidas.
      final String estadoPago =
          data['estadoPago']?.toString().toLowerCase() ?? '';

      if (estadoPago != 'aprobado') {
        continue;
      }

      // Ignoramos pedidos cancelados.
      final String estado = data['estado']?.toString().toLowerCase() ?? '';

      if (estado == 'cancelado') {
        continue;
      }

      final dynamic fechaRaw = data['fechaCreacion'];

      if (fechaRaw is! Timestamp) {
        continue;
      }

      final DateTime fecha = fechaRaw.toDate();

      // Solo contamos el mes actual.
      if (fecha.year != ahora.year || fecha.month != ahora.month) {
        continue;
      }

      comprasMes++;

      final dynamic items = data['items'];

      if (items is List) {
        for (final dynamic item in items) {
          if (item is! Map) {
            continue;
          }

          final int cantidad = (item['cantidad'] as num?)?.toInt() ?? 1;

          final bool esGratis = item['esGratis'] == true;

          final int cantidadMl = (item['cantidadMl'] as num?)?.toInt() ?? 0;

          // Las muestras gratuitas no cuentan
          // como bebida comprada para la recompensa.
          if (!esGratis) {
            bebidasMes += cantidad;
            mlMes += cantidadMl * cantidad;
          }
        }
      }
    }

    return {
      'comprasMes': comprasMes,
      'bebidasMes': bebidasMes,
      'mlMes': mlMes,
    };
  }

  // ============================================================
  // INDICADORES DEL CARRUSEL
  // ============================================================

  Widget _indicadores() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          promos.length,
          (index) {
            final bool activo = index == _paginaActual;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(
                horizontal: 3,
              ),
              width: activo ? 20 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: activo ? AppColors.dorado : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(20),
              ),
            );
          },
        ),
      ),
    );
  }

  // ============================================================
  // TARJETA DE META
  // ============================================================

  Widget _tarjetaMeta({
    required IconData icono,
    required String titulo,
    required String descripcion,
    required double progreso,
    required String avance,
    bool completado = false,
  }) {
    final double progresoSeguro = progreso.clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: completado
                  ? Colors.green.withValues(
                      alpha: 0.12,
                    )
                  : AppColors.lilaOscuro.withValues(
                      alpha: 0.10,
                    ),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              completado ? Icons.check_circle : icono,
              color: completado ? Colors.green : AppColors.lilaOscuro,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  descripcion,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progresoSeguro,
                    minHeight: 9,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      completado ? Colors.green : AppColors.lilaOscuro,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        avance,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: completado ? Colors.green : Colors.black87,
                        ),
                      ),
                    ),
                    if (completado)
                      const Icon(
                        Icons.emoji_events,
                        color: Colors.amber,
                        size: 20,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PROMOCIONES PARA INVITADO
  // ============================================================

  Widget _mensajeInvitado() {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: 16,
      ),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
          ),
        ],
      ),
      child: const Column(
        children: [
          Icon(
            Icons.lock_outline,
            size: 40,
            color: AppColors.lilaOscuro,
          ),
          SizedBox(height: 10),
          Text(
            'Regístrate para acumular beneficios',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Las compras de usuarios registrados '
            'pueden acumular progreso, muestras '
            'gratuitas y futuras recompensas.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black54,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CARRUSEL
  // ============================================================

  Widget _carrusel() {
    return Column(
      children: [
        SizedBox(
          height: 430,
          child: PageView.builder(
            controller: _pageController,
            itemCount: promos.length,
            onPageChanged: (index) {
              setState(() {
                _paginaActual = index;
              });
            },
            itemBuilder: (
              context,
              index,
            ) {
              return AnimatedBuilder(
                animation: _pageController,
                builder: (
                  context,
                  child,
                ) {
                  double escala = 1;

                  if (_pageController.position.haveDimensions) {
                    final double pagina =
                        _pageController.page ?? _paginaActual.toDouble();

                    final double diferencia = (pagina - index).abs();

                    escala = 1 - (diferencia * 0.06);

                    escala = escala.clamp(
                      0.94,
                      1.0,
                    );
                  }

                  return Transform.scale(
                    scale: escala,
                    child: child,
                  );
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 16,
                        offset: Offset(0, 7),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(
                          color: AppColors.lilaOscuro,
                        ),
                        Image.asset(
                          promos[index]['imagen']!,
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                          errorBuilder: (
                            context,
                            error,
                            stackTrace,
                          ) {
                            return Container(
                              color: AppColors.lilaOscuro,
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.local_offer,
                                size: 70,
                                color: Colors.white,
                              ),
                            );
                          },
                        ),
                        Positioned(
                          top: 14,
                          left: 14,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 13,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(
                                alpha: 0.55,
                              ),
                              borderRadius: BorderRadius.circular(
                                20,
                              ),
                            ),
                            child: Text(
                              promos[index]['mes']!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        _indicadores(),
      ],
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final UserProvider userProvider = Provider.of<UserProvider>(context);

    final String? uid = userProvider.uid;

    final bool puedeAcumular = userProvider.esRegistrado && uid != null;
    final bool esInvitado = userProvider.esInvitado;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'Promociones 🎉',
        ),
        backgroundColor: AppColors.lilaOscuro,
      ),
      body: ListView(
        padding: const EdgeInsets.only(
          bottom: 30,
        ),
        children: [
          const SizedBox(height: 12),
          _carrusel(),
          const SizedBox(height: 18),
          _publicacionesActivas(),
          const SizedBox(height: 22),
          if (esInvitado)
            _mensajeInvitado()
          else if (puedeAcumular)
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              // Por ahora escuchamos pedidos y filtramos
              // en memoria. Para la feria es suficiente
              // y evita exigir índices compuestos.
              stream:
                  FirebaseFirestore.instance.collection('pedidos').snapshots(),
              builder: (
                context,
                snapshot,
              ) {
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'No se pudo cargar tu progreso.\n'
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final estadisticas = _calcularEstadisticasUsuario(
                  snapshot.data!.docs,
                  uid,
                );

                final int comprasMes = estadisticas['comprasMes'] ?? 0;

                final int bebidasMes = estadisticas['bebidasMes'] ?? 0;

                final int mlMes = estadisticas['mlMes'] ?? 0;

                const int objetivoCompras = 5;
                const int objetivoBebidas = 10;

                final double progresoCompras = comprasMes / objetivoCompras;

                final double progresoBebidas = bebidasMes / objetivoBebidas;

                final bool metaCompras = comprasMes >= objetivoCompras;

                final bool metaBebidas = bebidasMes >= objetivoBebidas;

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.emoji_events,
                            color: AppColors.lilaOscuro,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Tu progreso este mes',
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Tus compras se actualizan '
                        'automáticamente.',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _tarjetaMeta(
                        icono: Icons.shopping_bag,
                        titulo: 'Cliente del mes',
                        descripcion: 'Realiza 5 compras '
                            'durante el mes.',
                        progreso: progresoCompras,
                        avance: metaCompras
                            ? '¡Meta alcanzada!'
                            : '$comprasMes de '
                                '$objetivoCompras compras',
                        completado: metaCompras,
                      ),
                      _tarjetaMeta(
                        icono: Icons.local_drink,
                        titulo: 'Fan de CHICHEJ',
                        descripcion: 'Compra 10 bebidas '
                            'y desbloquea una '
                            'recompensa especial.',
                        progreso: progresoBebidas,
                        avance: metaBebidas
                            ? '¡10 bebidas alcanzadas!'
                            : '$bebidasMes de '
                                '$objetivoBebidas bebidas',
                        completado: metaBebidas,
                      ),
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(
                          bottom: 12,
                        ),
                        padding: const EdgeInsets.all(
                          16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: AppColors.lilaOscuro.withValues(
                                  alpha: 0.10,
                                ),
                                borderRadius: BorderRadius.circular(
                                  15,
                                ),
                              ),
                              child: const Icon(
                                Icons.water_drop,
                                color: AppColors.lilaOscuro,
                              ),
                            ),
                            const SizedBox(
                              width: 14,
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Consumo del mes',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(
                                    height: 4,
                                  ),
                                  Text(
                                    '$mlMes ml acumulados',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.lilaOscuro,
                                    ),
                                  ),
                                  Text(
                                    '${(mlMes / 1000).toStringAsFixed(2)} litros',
                                    style: const TextStyle(
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _publicacionesActivas() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('mensajes')
          .orderBy(
            'fechaCreacion',
            descending: true,
          )
          .snapshots(),
      builder: (
        context,
        snapshot,
      ) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        QueryDocumentSnapshot<Map<String, dynamic>>? promocionActiva;
        QueryDocumentSnapshot<Map<String, dynamic>>? informativoActivo;

        for (final doc in snapshot.data!.docs) {
          final data = doc.data();
          if (data['activo'] != true) continue;
          if (data['tipo'] == 'promocion' && promocionActiva == null) {
            promocionActiva = doc;
          } else if (data['tipo'] != 'promocion' && informativoActivo == null) {
            informativoActivo = doc;
          }
        }

        if (promocionActiva == null && informativoActivo == null) {
          return const SizedBox.shrink();
        }

        return Column(
          children: [
            if (promocionActiva != null)
              _bloquePublicacion(promocionActiva.data(), esPromocion: true),
            if (promocionActiva != null && informativoActivo != null)
              const SizedBox(height: 12),
            if (informativoActivo != null)
              _bloquePublicacion(informativoActivo.data(), esPromocion: false),
          ],
        );
      },
    );
  }

  Widget _bloquePublicacion(
    Map<String, dynamic> data, {
    required bool esPromocion,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: esPromocion
              ? const [AppColors.lilaOscuro, AppColors.lilaMedio]
              : [Colors.teal.shade700, Colors.teal.shade400],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: Colors.white24,
            child: Icon(
              esPromocion ? Icons.local_offer : Icons.info_outline,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  esPromocion ? 'PROMOCIÓN ACTIVA' : 'INFORMATIVO ACTIVO',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  data['titulo']?.toString() ?? 'CHICHEJ',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  data['mensaje']?.toString() ?? '',
                  style: const TextStyle(color: Colors.white, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
