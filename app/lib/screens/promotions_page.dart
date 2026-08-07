import 'dart:async'; // Necesario para el Timer
import 'package:flutter/material.dart';
import '../utils/colors.dart';

class PromotionsPage extends StatefulWidget { // Cambiamos a StatefulWidget
  const PromotionsPage({super.key});
  @override
  State<PromotionsPage> createState() => _PromotionsPageState();
}

class _PromotionsPageState extends State<PromotionsPage> {
  final PageController _pageController = PageController(viewportFraction: 0.85);
  Timer? _timer;
  
  final List<String> promos = [
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

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {   
      if (_pageController.hasClients) {
        int nextPage = (_pageController.page?.round() ?? 0) + 1;
        if (nextPage >= 12) nextPage = 0; // Reinicia al llegar al final
        _pageController.animateToPage(nextPage, duration: const Duration(seconds: 1), curve: Curves.easeInOut);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // (Usa el mismo PageView que te envié antes, pero con el controller: _pageController)
    return Scaffold(
      appBar: AppBar(title: const Text("Promociones 🎉"), backgroundColor: AppColors.lilaOscuro),
      body: PageView.builder(
        controller: _pageController,
        itemCount: 12,
        itemBuilder: (context, index) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 5))],
              image: DecorationImage(image: AssetImage(promos[index]), fit: BoxFit.cover),
            ),
          );
        },
      ),
    );
  }
}