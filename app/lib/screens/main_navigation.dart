import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/user_provider.dart';
import 'admin_dashboard_page.dart';
import 'history_page.dart';
import 'home_page.dart';
import 'profile_page.dart';
import 'promotions_page.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final UserProvider userProvider = Provider.of<UserProvider>(context);

    final bool esAdmin = userProvider.esAdmin;
    final bool esInvitado = userProvider.esInvitado;

    final List<Widget> paginas = [
      const HomePage(),

      // El invitado no tendrá historial personal.
      if (!esInvitado) const HistoryPage(),

      const PromotionsPage(),
      const ProfilePage(),

      // Panel administrativo exclusivo.
      if (esAdmin) const AdminDashboardPage(),
    ];

    final List<BottomNavigationBarItem> items = [
      const BottomNavigationBarItem(
        icon: Icon(Icons.home),
        label: 'Inicio',
      ),
      if (!esInvitado)
        const BottomNavigationBarItem(
          icon: Icon(Icons.history),
          label: 'Historial',
        ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.local_offer),
        label: 'Promos',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.person),
        label: 'Perfil',
      ),
      if (esAdmin)
        const BottomNavigationBarItem(
          icon: Icon(Icons.admin_panel_settings),
          label: 'Admin',
        ),
    ];

    // Protección por si cambia el tipo de sesión mientras
    // MainNavigation sigue montado.
    if (currentIndex >= paginas.length) {
      currentIndex = 0;
    }

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: paginas,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() {
            currentIndex = index;
          });
        },
        items: items,
      ),
    );
  }
}
