import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import '../utils/colors.dart';
import 'main_navigation.dart';
import '../providers/user_provider.dart';
import '../models/user_model.dart';

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

  Future<void> register(BuildContext context) async {
    if (nombreController.text.trim().isEmpty || 
        emailController.text.trim().isEmpty || 
        passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Completa todos los campos")),
      );
      return;
    }

    if (passwordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("La contraseña debe tener al menos 6 caracteres")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      // 1. Crear usuario en Firebase Auth
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      String uid = userCredential.user!.uid;
      String nombreUsuario = nombreController.text.trim();

      // 2. Guardar datos en Realtime Database (Incluyendo el ROL)
      DatabaseReference ref = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: "https://chichej-2026-default-rtdb.firebaseio.com"
      ).ref("usuarios/$uid");

      await ref.set({
        "nombre": nombreUsuario,
        "email": emailController.text.trim(),
        "rol": "cliente", // <-- ¡Aquí asignamos el rol por defecto!
        "fechaRegistro": DateTime.now().toIso8601String(),
      });

      // 3. Guardar en el Provider de la app
      if (mounted) {
        UserModel user = UserModel(
          nombre: nombreUsuario,
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );
        
        Provider.of<UserProvider>(context, listen: false).setUser(user);
        
        // 4. Navegar a la pantalla principal
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const MainNavigation()),
          (Route<dynamic> route) => false, // Elimina las pantallas anteriores del historial
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = "Error al registrarse";
      if (e.code == 'weak-password') {
        errorMessage = "La contraseña es muy débil.";
      } else if (e.code == 'email-already-in-use') {
        errorMessage = "Este correo ya está registrado.";
      } else if (e.code == 'invalid-email') {
        errorMessage = "El formato del correo es inválido.";
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.redAccent)
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error de conexión: $e"), backgroundColor: Colors.redAccent)
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
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
            colors: [AppColors.lilaOscuro, AppColors.lilaMedio, AppColors.lilaClaro],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 30.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/logochichej.png', height: 120),
                  const SizedBox(height: 30),
                  
                  const Text(
                    "Crear Cuenta",
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 30),

                  // Campo Nombre
                  TextField(
                    controller: nombreController,
                    decoration: InputDecoration(
                      hintText: "Nombre completo",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(Icons.person_outline, color: AppColors.lilaOscuro),
                    ),
                  ),
                  const SizedBox(height: 15),
                  
                  // Campo Email
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: "Correo",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(Icons.email_outlined, color: AppColors.lilaOscuro),
                    ),
                  ),
                  const SizedBox(height: 15),
                  
                  // Campo Contraseña con Ojo
                  TextField(
                    controller: passwordController,
                    obscureText: !isPasswordVisible,
                    decoration: InputDecoration(
                      hintText: "Contraseña",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(Icons.lock_outline, color: AppColors.lilaOscuro),
                      suffixIcon: IconButton(
                        icon: Icon(
                          isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                          color: AppColors.lilaOscuro,
                        ),
                        onPressed: () => setState(() => isPasswordVisible = !isPasswordVisible),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Botón Registrarse
                  isLoading
                      ? const CircularProgressIndicator(color: AppColors.dorado)
                      : SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.dorado,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)
                              ),
                            ),
                            onPressed: () => register(context),
                            child: const Text(
                              "Registrarse", 
                              style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)
                            ),
                          ),
                        ),
                  
                  const SizedBox(height: 20),

                  // Volver al Login
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text(
                      "¿Ya tienes cuenta? Inicia sesión", 
                      style: TextStyle(color: Colors.white70, fontSize: 15)
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