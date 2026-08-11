import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/cart_provider.dart';
import 'providers/order_provider.dart';
import 'providers/user_provider.dart';
import 'screens/login_page.dart';
import 'services/order_ticket_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => CartProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => OrderProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => UserProvider(),
        ),
      ],
      child: const MyApp(),
    ),
  );

  // ------------------------------------------------------------
  // RECUPERACIÓN DE TICKETS MX06
  //
  // CHICHEJ inicia normalmente.
  // Dos segundos después revisa si existe algún pedido
  // entregado cuyo comprobante todavía no fue impreso.
  //
  // Esto NO bloquea el inicio de la aplicación.
  // ------------------------------------------------------------

  Future.delayed(
    const Duration(seconds: 2),
    () async {
      await OrderTicketService.instance
          .recoverPendingTickets();
    },
  );
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ChiChej',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        useMaterial3: true,
      ),
      home: const LoginPage(),
    );
  }
}