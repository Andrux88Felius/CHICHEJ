import 'dart:async';

import 'package:chichej/screens/splash_page.dart';
import 'package:chichej/services/music_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('CHICHEJ muestra su pantalla inicial', (tester) async {
    final initialization = Completer<void>();

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => MusicService(),
        child: MaterialApp(
          home: SplashPage(
            onInitialize: () => initialization.future,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(SplashPage), findsOneWidget);
    expect(find.text('Preparando CHICHEJ...'), findsOneWidget);
  });
}
