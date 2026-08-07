import 'package:chichej/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'home_page.dart';
import 'history_page.dart';
import 'promotions_page.dart';
import 'profile_page.dart';
import 'admin_dashboard_page.dart';


class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});
  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final bool isAdmin = userProvider.user?.rol == 'admin';

    return Scaffold(
      body: IndexedStack( // IndexedStack mantiene el estado de las pantallas
        index: currentIndex,
        children: [
          const HomePage(),
          const HistoryPage(),
          const PromotionsPage(),
          const ProfilePage(),
          if (isAdmin) const AdminDashboardPage(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (index) => setState(() => currentIndex = index),
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: "Inicio"),
          const BottomNavigationBarItem(icon: Icon(Icons.history), label: "Historial"),
          const BottomNavigationBarItem(icon: Icon(Icons.local_offer), label: "Promos"),
          const BottomNavigationBarItem(icon: Icon(Icons.person), label: "Perfil"),
          if (isAdmin) const BottomNavigationBarItem(icon: Icon(Icons.admin_panel_settings), label: "Admin"),
        ],
      ),
    );
  }
}