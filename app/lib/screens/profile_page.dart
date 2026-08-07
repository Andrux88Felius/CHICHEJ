import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import 'event_order_page.dart' as event_page;
import '../utils/colors.dart';
import 'login_page.dart';
import 'monthly_promo_page.dart' as promo_page;

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final TextEditingController nombreController = TextEditingController();

  final List<String> avatares = [
    'assets/avatares/avatar1.png', 'assets/avatares/avatar2.png', 'assets/avatares/avatar3.png',
    'assets/avatares/avatar4.png', 'assets/avatares/avatar5.png', 'assets/avatares/avatar6.png',
    'assets/avatares/avatar7.png', 'assets/avatares/avatar8.png', 'assets/avatares/avatar9.png',
  ];

  void _mostrarSelectorAvatar(BuildContext context, UserProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Elige tu avatar"),
        content: SizedBox(
          width: double.maxFinite,
          child: GridView.builder(
            shrinkWrap: true,
            itemCount: avatares.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3),
            itemBuilder: (context, index) => GestureDetector(
              onTap: () {
                provider.actualizarAvatar(avatares[index]);
                Navigator.pop(context);
              },
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Image.asset(avatares[index]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Función para manejar el acceso a secciones restringidas
  void _verificarAcceso(BuildContext context, bool esInvitado, Widget destination) {
    if (esInvitado) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Acceso Restringido"),
          content: const Text("Regístrate para realizar pedidos especiales y ver promociones exclusivas."),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
              },
              child: const Text("Registrarme"),
            ),
          ],
        ),
      );
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => destination));
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.user;

    if (user == null) return const Center(child: Text("No hay usuario"));

    nombreController.text = user.nombre;
    bool esInvitado = user.nombre == "Invitado";

    return Scaffold(
      appBar: AppBar(title: const Text("Perfil 👤"), backgroundColor: AppColors.lilaOscuro),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            GestureDetector(
              onTap: esInvitado ? null : () => _mostrarSelectorAvatar(context, userProvider),
              child: CircleAvatar(
                radius: 60,
                backgroundColor: Colors.white,
                backgroundImage: AssetImage(user.avatarPath ?? 'assets/avatares/invitado.png'),
              ),
            ),
            const SizedBox(height: 20),
            TextField(controller: nombreController, decoration: const InputDecoration(labelText: "Nombre")),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.dorado),
              onPressed: () {
                userProvider.updateNombre(nombreController.text);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Datos actualizados ✅")));
              },
              child: const Text("Guardar cambios", style: TextStyle(color: Colors.black)),
            ),
            const SizedBox(height: 20),
            
            // Sección de funcionalidades protegidas
            const Divider(),
            ListTile(
              leading: const Icon(Icons.event, color: AppColors.lilaOscuro),
              title: const Text("Pedidos Especiales / Eventos"),
              subtitle: const Text("Reserva unidades para tus celebraciones"),
              onTap: () => _verificarAcceso(context, esInvitado, const event_page.EventOrderPage()),
            ),
            ListTile(
              leading: const Icon(Icons.percent, color: Colors.green),
              title: const Text("Promoción del Mes"),
              subtitle: const Text("Mira lo que tenemos para ti hoy"),
              onTap: () => _verificarAcceso(context, esInvitado, const promo_page.MonthlyPromoPage()),
            ),
            const Divider(),
            
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                userProvider.logout();
                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (route) => false);
              },
              child: const Text("Cerrar sesión", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}