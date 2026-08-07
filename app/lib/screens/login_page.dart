import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart'; // La línea amarilla desaparecerá porque ahora sí lo usaremos
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import '../utils/colors.dart';
import 'register_page.dart';
import 'main_navigation.dart';
import '../providers/user_provider.dart';
import '../models/user_model.dart';

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

  Future<void> login(BuildContext context, {bool isGuest = false}) async {
    if (isGuest) {
      UserModel guestUser = UserModel(
        nombre: "Invitado",
        email: "invitado@chichej.com",
        password: "",
      );
      Provider.of<UserProvider>(context, listen: false).setUser(guestUser);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainNavigation()),
      );
      return;
    }

    if (emailController.text.trim().isEmpty || passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Completa todos los campos")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      String uid = userCredential.user!.uid;
      String nombreUsuario = "Usuario";
      String rolUsuario = "cliente"; // Valor por defecto
      String avatarUsuario = "assets/avatares/invitado.png"; // Valor por

      try {
        // AQUÍ ESTÁ LA MAGIA: Forzamos la URL explícita para que no falle en la web
        DatabaseReference ref = FirebaseDatabase.instanceFor(
          app: Firebase.app(),
          databaseURL: "https://chichej-2026-default-rtdb.firebaseio.com"
        ).ref("usuarios/$uid");
        
        DataSnapshot snapshot = await ref.get();
        
        if (snapshot.exists) {
          Map<dynamic, dynamic> data = snapshot.value as Map;
          nombreUsuario = data['nombre'] ?? "Usuario";
          rolUsuario = data['rol'] ?? "cliente";
          avatarUsuario = data['avatarPath'] ?? "assets/avatares/invitado.png";
        }
      } catch (dbError) {
        debugPrint("Fallo de lectura en DB Web: $dbError");
      }

      if (mounted) {
        UserModel user = UserModel(
          uid: uid,
          nombre: nombreUsuario,
          email: emailController.text.trim(),
          password: "",
          avatarPath: avatarUsuario,
          rol: rolUsuario,
        );
        debugPrint("-------------------------");
        debugPrint("UID: ${user.uid}");
        debugPrint("Nombre: ${user.nombre}");
        debugPrint("Rol: ${user.rol}");
        debugPrint("Avatar: ${user.avatarPath}");
        debugPrint("-------------------------");
        Provider.of<UserProvider>(context, listen: false).setUser(user);
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainNavigation()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = "Error al iniciar sesión";
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        errorMessage = "Usuario no encontrado o credenciales inválidas.";
      } else if (e.code == 'wrong-password') {
        errorMessage = "Contraseña incorrecta.";
      } else if (e.code == 'invalid-email') {
        errorMessage = "Formato de correo inválido.";
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.redAccent)
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
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
                  Image.asset('assets/logochichej.png', height: 150),
                  const SizedBox(height: 40),
                  
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
                  const SizedBox(height: 20),
                  
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
                            onPressed: () => login(context),
                            child: const Text(
                              "Iniciar sesión", 
                              style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)
                            ),
                          ),
                        ),
                  
                  const SizedBox(height: 20),

                  TextButton.icon(
                    onPressed: () => login(context, isGuest: true),
                    icon: const Icon(Icons.person_outline, color: Colors.white),
                    label: const Text(
                      "Ingresar como Invitado", 
                      style: TextStyle(color: Colors.white, fontSize: 16)
                    ),
                  ),

                  const SizedBox(height: 10),

                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterPage())),
                    child: const Text(
                      "¿No tienes cuenta? Regístrate", 
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