import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/cart_provider.dart';
import 'providers/order_provider.dart';
import 'providers/user_provider.dart';
import 'screens/splash_page.dart';
import 'services/music_service.dart';
import 'services/order_ticket_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

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
        ChangeNotifierProvider(
          create: (_) => MusicService(),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

Future<void> _initializeApplication() async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
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

  Future<void>.delayed(
    const Duration(seconds: 2),
    () async {
      await OrderTicketService.instance.recoverPendingTickets();
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
      home: const SplashPage(
        onInitialize: _initializeApplication,
      ),
    );
  }
}
