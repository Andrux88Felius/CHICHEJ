import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_model.dart';
import '../providers/order_provider.dart';
import '../providers/user_provider.dart';
import '../services/music_service.dart';
import '../services/auth_session_service.dart';
import '../utils/colors.dart';
import 'main_navigation.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isLoading = false;
  bool isPasswordVisible = false;
  bool mantenerSesion = false;

  bool _correoValido(String email) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);

  void _mostrarMensaje(String mensaje, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: error ? Colors.redAccent : Colors.green,
      ),
    );
  }

  String _mensajeAuth(String codigo, {bool recuperacion = false}) {
    switch (codigo) {
      case 'wrong-password':
        return 'La contraseña es incorrecta.';
      case 'user-not-found':
        return recuperacion
            ? 'No existe una cuenta con este correo.'
            : 'No existe una cuenta con este correo. Puedes registrarte.';
      case 'invalid-credential':
        return 'El correo o la contraseña son incorrectos.';
      case 'invalid-email':
        return 'Ingresa un correo electrónico válido.';
      case 'user-disabled':
        return 'Esta cuenta está deshabilitada. Contacta al administrador.';
      case 'too-many-requests':
        return 'Demasiados intentos. Intenta nuevamente más tarde.';
      case 'network-request-failed':
        return 'No se pudo conectar. Verifica tu conexión a Internet.';
      default:
        return recuperacion
            ? 'No se pudo enviar el enlace. Intenta nuevamente.'
            : 'No se pudo iniciar sesión. Intenta nuevamente.';
    }
  }

  Future<void> _restablecerContrasena() async {
    final email = emailController.text.trim();
    if (!_correoValido(email)) {
      _mostrarMensaje('Ingresa un correo electrónico válido.', error: true);
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      _mostrarMensaje('Te enviamos un enlace para restablecer tu contraseña.');
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      _mostrarMensaje(_mensajeAuth(error.code, recuperacion: true),
          error: true);
    } catch (_) {
      if (!mounted) return;
      _mostrarMensaje('No se pudo enviar el enlace. Intenta nuevamente.',
          error: true);
    }
  }

  Future<void> login({bool isGuest = false}) async {
    if (isLoading) return;

    if (isGuest) {
      await _iniciarComoInvitado();
      return;
    }

    if (emailController.text.trim().isEmpty ||
        passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completa todos los campos'),
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final UserCredential userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final String? uid = userCredential.user?.uid;

      if (uid == null || uid.isEmpty) {
        throw FirebaseAuthException(
          code: 'uid-no-disponible',
          message: 'Firebase no devolvió un UID válido.',
        );
      }

      String nombreUsuario = 'Usuario';
      String rolUsuario = 'cliente';
      String avatarUsuario = 'assets/avatares/invitado.png';
      int muestrasGratisDisponibles = 0;
      int muestrasGratisUtilizadas = 0;
      bool bloqueado = false;

      try {
        final FirebaseDatabase database = FirebaseDatabase.instanceFor(
          app: Firebase.app(),
          databaseURL: 'https://chichej-2026-default-rtdb.firebaseio.com',
        );

        final DatabaseReference ref = database.ref('usuarios/$uid');
        final DataSnapshot snapshot = await ref.get();

        if (snapshot.exists && snapshot.value is Map) {
          final Map<String, dynamic> data =
              Map<String, dynamic>.from(snapshot.value as Map);

          nombreUsuario = data['nombre']?.toString() ?? 'Usuario';
          rolUsuario = data['rol']?.toString() ?? 'cliente';
          avatarUsuario =
              data['avatarPath']?.toString() ?? 'assets/avatares/invitado.png';

          muestrasGratisDisponibles =
              (data['muestrasGratisDisponibles'] as num?)?.toInt() ?? 0;

          muestrasGratisUtilizadas =
              (data['muestrasGratisUtilizadas'] as num?)?.toInt() ?? 0;
          bloqueado = data['bloqueado'] == true;
        }
      } catch (dbError) {
        debugPrint(
          '[LOGIN] No se pudo cargar el perfil desde Realtime Database: '
          '$dbError',
        );
      }

      if (!mounted) return;

      if (bloqueado) {
        await FirebaseAuth.instance.signOut();
        await AuthSessionService.setKeepSession(false);
        if (!mounted) return;
        _mostrarMensaje(
          'Esta cuenta está bloqueada. Contacta al administrador.',
          error: true,
        );
        return;
      }

      final bool esAdmin =
          rolUsuario == 'admin' || rolUsuario == 'admin_principal';

      final UserModel usuario = UserModel(
        uid: uid,
        nombre: nombreUsuario,
        email: emailController.text.trim(),
        tipoSesion: esAdmin ? TipoSesion.admin : TipoSesion.registrado,
        muestrasGratisDisponibles: muestrasGratisDisponibles,
        muestrasGratisUtilizadas: muestrasGratisUtilizadas,
        avatarPath: esAdmin ? UserProvider.avatarAdmin : avatarUsuario,
        rol: rolUsuario,
      );

      final OrderProvider orderProvider =
          Provider.of<OrderProvider>(context, listen: false);

      final UserProvider userProvider =
          Provider.of<UserProvider>(context, listen: false);

      final MusicService musicService =
          Provider.of<MusicService>(context, listen: false);

      // Evita que el historial temporal de una sesión anterior
      // aparezca en la cuenta que acaba de iniciar sesión.
      orderProvider.limpiarSesion();

      // UserProvider vuelve a imponer el avatar oficial si es administrador.
      userProvider.setUser(usuario);
      await musicService.activateUser(uid);
      await AuthSessionService.setKeepSession(mantenerSesion);

      debugPrint('-------------------------');
      debugPrint('UID: ${usuario.uid}');
      debugPrint('Nombre: ${usuario.nombre}');
      debugPrint('Rol: ${usuario.rol}');
      debugPrint('Tipo de sesión: ${usuario.tipoSesion.name}');
      debugPrint('Avatar: ${usuario.avatarPath}');
      debugPrint(
        'Muestras disponibles: '
        '${usuario.muestrasGratisDisponibles}',
      );
      debugPrint(
        'Muestras utilizadas: '
        '${usuario.muestrasGratisUtilizadas}',
      );
      debugPrint('-------------------------');

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const MainNavigation(),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      final errorMessage = _mensajeAuth(e.code);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.redAccent,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      debugPrint('[LOGIN] Error inesperado: $error');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ocurrió un error inesperado al iniciar sesión.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _iniciarComoInvitado() async {
    setState(() => isLoading = true);

    try {
      final OrderProvider orderProvider =
          Provider.of<OrderProvider>(context, listen: false);

      final UserProvider userProvider =
          Provider.of<UserProvider>(context, listen: false);

      final MusicService musicService =
          Provider.of<MusicService>(context, listen: false);

      // Elimina información temporal de la sesión anterior.
      orderProvider.limpiarSesion();

      // Cierra cualquier sesión de Firebase activa y crea/reutiliza
      // el identificador local persistente del invitado.
      await userProvider.iniciarSesionInvitada();
      await AuthSessionService.setKeepSession(false);
      await musicService.startGuestSession();

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const MainNavigation(),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      debugPrint('[LOGIN] Error al iniciar como invitado: $error');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo iniciar el modo invitado.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.lilaOscuro,
              AppColors.lilaMedio,
              AppColors.lilaClaro,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 40,
                horizontal: 30,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/logochichej.png',
                    height: 150,
                  ),
                  const SizedBox(height: 40),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    enabled: !isLoading,
                    decoration: InputDecoration(
                      hintText: 'Correo',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(
                        Icons.email_outlined,
                        color: AppColors.lilaOscuro,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: passwordController,
                    obscureText: !isPasswordVisible,
                    textInputAction: TextInputAction.done,
                    enabled: !isLoading,
                    onSubmitted: (_) => login(),
                    decoration: InputDecoration(
                      hintText: 'Contraseña',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(
                        Icons.lock_outline,
                        color: AppColors.lilaOscuro,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          isPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: AppColors.lilaOscuro,
                        ),
                        onPressed: isLoading
                            ? null
                            : () {
                                setState(
                                  () => isPasswordVisible = !isPasswordVisible,
                                );
                              },
                      ),
                    ),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: AppColors.dorado,
                    checkColor: Colors.black,
                    title: const Text(
                      'Mantener sesión iniciada',
                      style: TextStyle(color: Colors.white),
                    ),
                    value: mantenerSesion,
                    onChanged: isLoading
                        ? null
                        : (value) {
                            setState(() => mantenerSesion = value ?? false);
                          },
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: isLoading ? null : _restablecerContrasena,
                      child: const Text(
                        '¿Olvidaste tu contraseña?',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  if (isLoading)
                    const CircularProgressIndicator(
                      color: AppColors.dorado,
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.dorado,
                          padding: const EdgeInsets.symmetric(
                            vertical: 15,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onPressed: login,
                        child: const Text(
                          'Iniciar sesión',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  TextButton.icon(
                    onPressed: isLoading ? null : () => login(isGuest: true),
                    icon: const Icon(
                      Icons.person_outline,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Ingresar como Invitado',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: isLoading
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const RegisterPage(),
                              ),
                            );
                          },
                    child: const Text(
                      '¿No tienes cuenta? Regístrate',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
