import 'package:cloud_firestore/cloud_firestore.dart';
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

  // ============================================================
  // ICONO PROMOCIONES CON ALERTA
  // ============================================================

  Widget _iconoPromociones({
    required bool mostrarAlerta,
  }) {
    if (!mostrarAlerta) {
      return const Icon(
        Icons.local_offer,
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('mensajes')
          .where(
            'activo',
            isEqualTo: true,
          )
          .limit(1)
          .snapshots(),
      builder: (
        context,
        snapshot,
      ) {
        final bool hayMensajeActivo =
            snapshot.hasData &&
            snapshot.data!.docs.isNotEmpty;

        return SizedBox(
          width: 30,
          height: 30,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Positioned.fill(
                child: Center(
                  child: Icon(
                    Icons.local_offer,
                  ),
                ),
              ),

              if (hayMensajeActivo)
                Positioned(
                  top: -3,
                  right: -3,
                  child: Container(
                    width: 16,
                    height: 16,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                    child: const Text(
                      '!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        height: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final UserProvider userProvider =
        Provider.of<UserProvider>(context);

    final bool esAdmin = userProvider.esAdmin;
    final bool esInvitado = userProvider.esInvitado;

    final List<Widget> paginas = [
      const HomePage(),

      // El invitado no tendrá historial personal.
      if (!esInvitado)
        const HistoryPage(),

      const PromotionsPage(),

      const ProfilePage(),

      // Panel administrativo exclusivo.
      if (esAdmin)
        const AdminDashboardPage(),
    ];

    final List<BottomNavigationBarItem> items = [
      const BottomNavigationBarItem(
        icon: Icon(
          Icons.home,
        ),
        label: 'Inicio',
      ),

      if (!esInvitado)
        const BottomNavigationBarItem(
          icon: Icon(
            Icons.history,
          ),
          label: 'Historial',
        ),

      BottomNavigationBarItem(
        icon: _iconoPromociones(
          mostrarAlerta: !esInvitado,
        ),
        label: 'Promos',
      ),

      const BottomNavigationBarItem(
        icon: Icon(
          Icons.person,
        ),
        label: 'Perfil',
      ),

      if (esAdmin)
        const BottomNavigationBarItem(
          icon: Icon(
            Icons.admin_panel_settings,
          ),
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