import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // Importante
import 'package:provider/provider.dart';
import 'providers/cart_provider.dart';
import 'providers/order_provider.dart';
import 'providers/user_provider.dart';
import 'screens/login_page.dart';
import 'firebase_options.dart'; // Importa la configuración de Firebasej

// 1. Es necesario marcar main como async
void main() async {
  // 2. Vincula los widgets de Flutter con el motor de ejecución
  WidgetsFlutterBinding.ensureInitialized();
  
  // 3. Inicializa Firebase antes de arrancar la app
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ChiChej',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple, // Ajusta a tus colores
        useMaterial3: true,
      ),
      home: LoginPage(),
    );
  }
}