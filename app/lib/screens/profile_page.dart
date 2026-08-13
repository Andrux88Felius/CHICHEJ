import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/order_provider.dart';
import '../providers/user_provider.dart';
import '../services/music_service.dart';
import '../services/auth_session_service.dart';
import '../utils/colors.dart';
import 'chichej_info_page.dart';
import 'event_order_page.dart' as event_page;
import 'login_page.dart';
import 'monthly_promo_page.dart' as promo_page;

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final TextEditingController nombreController = TextEditingController();
  bool _mantenerSesion = false;

  @override
  void initState() {
    super.initState();
    AuthSessionService.keepSessionEnabled().then((value) {
      if (mounted) setState(() => _mantenerSesion = value);
    });
  }

  Future<void> _desactivarAccesoAutomatico() async {
    await AuthSessionService.setKeepSession(false);
    if (!mounted) return;
    setState(() => _mantenerSesion = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Acceso automático desactivado. En el próximo inicio deberás iniciar sesión.',
        ),
      ),
    );
  }

  Future<void> _enviarCambioContrasena() async {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null || email.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No hay un correo disponible para esta cuenta.')),
      );
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Enviamos un enlace de cambio de contraseña a $email.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No se pudo enviar el enlace. Intenta nuevamente.')),
      );
    }
  }

  final List<String> avatares = const [
    'assets/avatares/avatar1.png',
    'assets/avatares/avatar2.png',
    'assets/avatares/avatar3.png',
    'assets/avatares/avatar4.png',
    'assets/avatares/avatar5.png',
    'assets/avatares/avatar6.png',
    'assets/avatares/avatar7.png',
    'assets/avatares/avatar8.png',
    'assets/avatares/avatar9.png',
  ];

  Future<void> _mostrarSelectorAvatar(
    BuildContext context,
    UserProvider provider,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            'Elige tu avatar',
            textAlign: TextAlign.center,
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: GridView.builder(
              shrinkWrap: true,
              itemCount: avatares.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemBuilder: (context, index) {
                final String avatar = avatares[index];
                final bool seleccionado = provider.user?.avatarPath == avatar;

                return GestureDetector(
                  onTap: () async {
                    provider.actualizarAvatar(avatar);

                    if (!dialogContext.mounted) return;
                    Navigator.pop(dialogContext);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: seleccionado
                            ? AppColors.dorado
                            : Colors.transparent,
                        width: 3,
                      ),
                      boxShadow: seleccionado
                          ? const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 7,
                                offset: Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        avatar,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _verificarAcceso(
    BuildContext context,
    bool esInvitado,
    Widget destination,
  ) {
    if (!esInvitado) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => destination),
      );
      return;
    }

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Acceso restringido'),
          content: const Text(
            'Regístrate para realizar pedidos especiales '
            'y ver promociones exclusivas.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);

                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LoginPage(),
                  ),
                );
              },
              child: const Text('Registrarme'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _cerrarSesion(
    BuildContext context,
    UserProvider userProvider,
  ) async {
    final OrderProvider orderProvider =
        Provider.of<OrderProvider>(context, listen: false);
    final MusicService musicService =
        Provider.of<MusicService>(context, listen: false);

    orderProvider.limpiarSesion();
    await musicService.clearSession();
    await AuthSessionService.setKeepSession(false);
    await userProvider.logout();

    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginPage(),
      ),
      (_) => false,
    );
  }

  @override
  void dispose() {
    nombreController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final UserProvider userProvider = Provider.of<UserProvider>(context);

    final user = userProvider.user;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('No hay usuario activo'),
        ),
      );
    }

    if (nombreController.text != user.nombre) {
      nombreController.text = user.nombre;
      nombreController.selection = TextSelection.collapsed(
        offset: nombreController.text.length,
      );
    }

    final bool esInvitado = userProvider.esInvitado;
    final bool esAdmin = userProvider.esAdmin;

    final String avatarActual = esAdmin
        ? UserProvider.avatarAdmin
        : user.avatarPath ?? 'assets/avatares/invitado.png';

    final String tipoCuenta = esAdmin
        ? 'Administrador'
        : esInvitado
            ? 'Invitado'
            : 'Usuario registrado';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil 👤'),
        backgroundColor: AppColors.lilaOscuro,
        actions: [
          IconButton(
            tooltip: 'Información de CHICHEJ',
            icon: const Icon(
              Icons.info_outline,
              color: AppColors.turquesa,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ChichejInfoPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            GestureDetector(
              onTap: esInvitado || esAdmin
                  ? null
                  : () => _mostrarSelectorAvatar(
                        context,
                        userProvider,
                      ),
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: esAdmin
                      ? const LinearGradient(
                          colors: [
                            AppColors.dorado,
                            AppColors.lilaClaro,
                            AppColors.lilaOscuro,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: esAdmin ? null : Colors.white,
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 58,
                  backgroundColor: esAdmin ? AppColors.lilaClaro : Colors.white,
                  child: ClipOval(
                    child: Image.asset(
                      avatarActual,
                      width: 112,
                      height: 112,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              tipoCuenta,
              style: TextStyle(
                color: esAdmin ? AppColors.lilaOscuro : Colors.black54,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (!esInvitado) ...[
              const SizedBox(height: 6),
              Text(
                user.email,
                style: const TextStyle(
                  color: Colors.black54,
                ),
              ),
            ],
            const SizedBox(height: 22),
            TextField(
              controller: nombreController,
              enabled: !esAdmin && !esInvitado,
              decoration: InputDecoration(
                labelText: 'Nombre',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                helperText: esAdmin
                    ? 'El nombre administrativo no se modifica aquí.'
                    : esInvitado
                        ? 'Regístrate para personalizar tu perfil.'
                        : null,
              ),
            ),
            const SizedBox(height: 18),
            if (!esAdmin && !esInvitado)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.dorado,
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                    ),
                  ),
                  onPressed: () async {
                    final String nombre = nombreController.text.trim();

                    if (nombre.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'El nombre no puede estar vacío.',
                          ),
                        ),
                      );
                      return;
                    }

                    userProvider.updateNombre(nombre);

                    if (!mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Datos actualizados ✅',
                        ),
                      ),
                    );
                  },
                  child: const Text(
                    'Guardar cambios',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            if (!esInvitado && !esAdmin) ...[
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.card_giftcard,
                    color: Colors.green,
                  ),
                  title: const Text(
                    'Muestras gratuitas',
                  ),
                  subtitle: Text(
                    'Disponibles: '
                    '${user.muestrasGratisDisponibles} · '
                    'Utilizadas: '
                    '${user.muestrasGratisUtilizadas}',
                  ),
                ),
              ),
            ],
            if (esAdmin) ...[
              const SizedBox(height: 16),
              const Card(
                child: ListTile(
                  leading: Icon(
                    Icons.admin_panel_settings,
                    color: AppColors.lilaOscuro,
                  ),
                  title: Text(
                    'Modo administrador',
                  ),
                  subtitle: Text(
                    'Uso administrativo sin límite. '
                    'Cada dispensación será registrada.',
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            const Divider(),
            ListTile(
              leading: const Icon(
                Icons.event,
                color: AppColors.lilaOscuro,
              ),
              title: const Text(
                'Pedidos especiales / Eventos',
              ),
              subtitle: const Text(
                'Reserva bebidas para tus celebraciones',
              ),
              onTap: () => _verificarAcceso(
                context,
                esInvitado,
                const event_page.EventOrderPage(),
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.percent,
                color: Colors.green,
              ),
              title: const Text(
                'Promoción del mes',
              ),
              subtitle: const Text(
                'Mira lo que tenemos para ti hoy',
              ),
              onTap: () => _verificarAcceso(
                context,
                esInvitado,
                const promo_page.MonthlyPromoPage(),
              ),
            ),
            if (!esInvitado) ...[
              const Divider(),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Seguridad y acceso',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.login, color: AppColors.lilaOscuro),
                title: Text(
                  'Acceso automático: ${_mantenerSesion ? 'Activado' : 'Desactivado'}',
                ),
                subtitle: _mantenerSesion
                    ? const Text(
                        'Entrarás después del splash sin volver a iniciar sesión.')
                    : const Text(
                        'Se solicitará iniciar sesión al abrir nuevamente la app.'),
              ),
              if (_mantenerSesion)
                OutlinedButton.icon(
                  onPressed: _desactivarAccesoAutomatico,
                  icon: const Icon(Icons.no_accounts),
                  label: const Text('Desactivar acceso automático'),
                ),
              ListTile(
                leading:
                    const Icon(Icons.password, color: AppColors.lilaOscuro),
                title: const Text('Cambiar contraseña'),
                subtitle: const Text('Recibe un enlace seguro en tu correo.'),
                onTap: _enviarCambioContrasena,
              ),
            ],
            const Divider(),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                  ),
                ),
                onPressed: () => _cerrarSesion(
                  context,
                  userProvider,
                ),
                icon: const Icon(
                  Icons.logout,
                  color: Colors.white,
                ),
                label: const Text(
                  'Cerrar sesión',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
