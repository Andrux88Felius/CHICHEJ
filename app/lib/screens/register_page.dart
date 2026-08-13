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

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController nombreController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isLoading = false;
  bool isPasswordVisible = false;

  bool _contrasenaSegura(String value) =>
      value.length >= 8 &&
      RegExp(r'[A-Z]').hasMatch(value) &&
      RegExp(r'[a-z]').hasMatch(value) &&
      RegExp(r'[0-9]').hasMatch(value) &&
      RegExp(r'[^A-Za-z0-9]').hasMatch(value);

  Future<void> register() async {
    if (isLoading) return;

    final String nombre = nombreController.text.trim();
    final String email = emailController.text.trim();
    final String password = passwordController.text;

    if (nombre.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completa todos los campos'),
        ),
      );
      return;
    }

    if (!_contrasenaSegura(password)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La contraseña no cumple todos los requisitos de seguridad.',
          ),
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    User? usuarioFirebase;

    try {
      final UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      usuarioFirebase = userCredential.user;
      final String? uid = usuarioFirebase?.uid;

      if (uid == null || uid.isEmpty) {
        throw FirebaseAuthException(
          code: 'uid-no-disponible',
          message: 'Firebase no devolvió un UID válido.',
        );
      }

      final FirebaseDatabase database = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: 'https://chichej-2026-default-rtdb.firebaseio.com',
      );

      final DatabaseReference ref = database.ref('usuarios/$uid');

      await ref.set({
        'nombre': nombre,
        'email': email,
        'rol': 'cliente',
        'avatarPath': 'assets/avatares/invitado.png',
        'fechaRegistro': ServerValue.timestamp,
        'muestrasGratisDisponibles': 1,
        'muestrasGratisUtilizadas': 0,
      });

      final UserModel usuario = UserModel(
        uid: uid,
        nombre: nombre,
        email: email,
        tipoSesion: TipoSesion.registrado,
        muestrasGratisDisponibles: 1,
        muestrasGratisUtilizadas: 0,
        avatarPath: 'assets/avatares/invitado.png',
        rol: 'cliente',
      );

      if (!mounted) return;

      final OrderProvider orderProvider =
          Provider.of<OrderProvider>(context, listen: false);

      final UserProvider userProvider =
          Provider.of<UserProvider>(context, listen: false);

      final MusicService musicService =
          Provider.of<MusicService>(context, listen: false);

      // Evita que el nuevo usuario herede datos temporales
      // de una sesión invitada o anterior.
      orderProvider.limpiarSesion();
      userProvider.setUser(usuario);
      await musicService.activateUser(uid);
      await AuthSessionService.setKeepSession(false);

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const MainNavigation(),
        ),
        (_) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String errorMessage = 'Error al registrarse.';

      switch (e.code) {
        case 'weak-password':
          errorMessage = 'La contraseña es muy débil.';
          break;

        case 'email-already-in-use':
          errorMessage = 'Este correo ya está registrado.';
          break;

        case 'invalid-email':
          errorMessage = 'El formato del correo no es válido.';
          break;

        case 'operation-not-allowed':
          errorMessage =
              'El registro con correo y contraseña no está habilitado.';
          break;

        case 'network-request-failed':
          errorMessage = 'No se pudo conectar. Revisa tu conexión a Internet.';
          break;

        case 'uid-no-disponible':
          errorMessage = 'No se pudo identificar correctamente al usuario.';
          break;

        default:
          errorMessage = e.message ?? 'No se pudo completar el registro.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.redAccent,
        ),
      );
    } catch (error) {
      debugPrint('[REGISTRO] Error inesperado: $error');

      // Si Authentication creó la cuenta pero falló el guardado del perfil,
      // intentamos eliminarla para no dejar una cuenta incompleta.
      try {
        await usuarioFirebase?.delete();
      } catch (deleteError) {
        debugPrint(
          '[REGISTRO] No se pudo eliminar la cuenta incompleta: '
          '$deleteError',
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo guardar el perfil. Inténtalo nuevamente.',
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
    nombreController.dispose();
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
                    height: 120,
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    'Crear cuenta',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 30),
                  TextField(
                    controller: nombreController,
                    enabled: !isLoading,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      hintText: 'Nombre completo',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(
                        Icons.person_outline,
                        color: AppColors.lilaOscuro,
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: emailController,
                    enabled: !isLoading,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
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
                  const SizedBox(height: 15),
                  TextField(
                    controller: passwordController,
                    enabled: !isLoading,
                    obscureText: !isPasswordVisible,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => register(),
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
                  const SizedBox(height: 10),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'La contraseña debe incluir 8 caracteres, mayúscula, '
                      'minúscula, número y símbolo.',
                      style: TextStyle(color: Colors.white, fontSize: 13),
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
                        onPressed: register,
                        child: const Text(
                          'Registrarse',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: isLoading ? null : () => Navigator.pop(context),
                    child: const Text(
                      '¿Ya tienes cuenta? Inicia sesión',
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
