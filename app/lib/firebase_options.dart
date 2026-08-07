import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return android;
    }
    throw UnsupportedError('Plataforma no soportada');
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBlEAKk8ipnVA__EStSCJQ0sZEXlQd0Mec',
    appId: '1:152737624623:web:3b3dc92078dd21484e4cda',
    messagingSenderId: '152737624623',
    projectId: 'chichej-2026',
    storageBucket: 'chichej-2026.firebasestorage.app',
    authDomain: 'chichej-2026.firebaseapp.com',
    // Opcional: Si quieres usar la base de datos en tiempo real, 
    // asegúrate de que esté configurada en tu provider o main.dart
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCQScUs6hcUhq4x9lnXwVsTuRnXo71jEdw',
    appId: '1:152737624623:android:1fb1cc656535e1944e4cda',
    messagingSenderId: '152737624623',
    projectId: 'chichej-2026',
    storageBucket: 'chichej-2026.firebasestorage.app',
  );
}