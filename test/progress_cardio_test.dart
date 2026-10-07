import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rutina_fit/database/db.dart';
import 'package:rutina_fit/screens/progress_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  testWidgets('progreso muestra cardio aunque no haya sesiones de fuerza, y recarga al arrastrar', (t) async {
    await t.runAsync(() async {
      // Carpeta propia: las pruebas corren en paralelo y no deben compartir rutina.db.
      await databaseFactory.setDatabasesPath(Directory('.dart_tool/test_db/progress').absolute.path);
      await databaseFactory.deleteDatabase('${await getDatabasesPath()}/rutina.db');
    });
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: Progress())));
    Future<void> settle() async {
      for (var i = 0; i < 10; i++) {
        await t.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
        await t.pump(const Duration(milliseconds: 100));
      }
    }

    await settle();
    expect(find.textContaining('Guarda una sesión'), findsOneWidget);

    // Se guarda una sesión de bicicleta mientras la pantalla está abierta...
    await t.runAsync(() => Db.saveBike('${DateTime.now().toIso8601String().substring(0, 10)} 08:00:00', 600, 'Bicicleta estática'));
    // ...y el usuario arrastra hacia abajo para recargar.
    await t.fling(find.byType(ListView), const Offset(0, 400), 1000);
    await settle();

    expect(find.textContaining('Guarda una sesión'), findsNothing);
    expect(find.text('Cardio: minutos por sesión'), findsOneWidget);
    expect(find.text('Peso máximo por sesión'), findsNothing);
  });
}
