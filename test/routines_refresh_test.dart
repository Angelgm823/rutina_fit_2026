import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rutina_fit/database/db.dart';
import 'package:rutina_fit/screens/routines.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  testWidgets('la lista se actualiza al agregar y eliminar', (t) async {
    await t.runAsync(() async {
      await databaseFactory.deleteDatabase('${await getDatabasesPath()}/rutina.db');
    });
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: RoutinesScreen())));
    Future<void> settle() async {
      for (var i = 0; i < 10; i++) {
        await t.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
        await t.pump(const Duration(milliseconds: 100));
      }
    }

    await settle();
    expect(find.textContaining('Aún no tienes rutinas'), findsOneWidget);

    // Crea una rutina como lo haría el editor y vuelve a la lista.
    await t.tap(find.text('Nueva rutina'));
    await settle();
    await t.runAsync(() async {
      final ex = (await Db.exercises()).first;
      await Db.saveRoutine(null, 'Pierna', [ex.id]);
    });
    t.state<NavigatorState>(find.byType(Navigator)).pop();
    await settle();
    expect(find.text('Pierna'), findsOneWidget, reason: 'tras agregar');

    // Elimina desde el menú.
    await t.tap(find.byType(PopupMenuButton<String>));
    await settle();
    await t.tap(find.text('Eliminar').last);
    await settle();
    await t.tap(find.widgetWithText(FilledButton, 'Eliminar'));
    await settle();
    expect(find.text('Pierna'), findsNothing, reason: 'tras eliminar');
  });
}
