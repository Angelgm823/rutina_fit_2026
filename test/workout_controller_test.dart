import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rutina_fit/controllers/workout_controller.dart';
import 'package:rutina_fit/database/db.dart';
import 'package:rutina_fit/models/exercises.dart';
import 'package:rutina_fit/screens/workout_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  TestWidgetsFlutterBinding.ensureInitialized();
  // Base propia: los archivos de test corren en paralelo y otros usan rutina.db.
  setUpAll(() async => databaseFactory.setDatabasesPath(
      (await Directory.systemTemp.createTemp('workout_test')).path));

  /// Base limpia con una rutina "Pecho" de un ejercicio con peso.
  Future<(int, Ex)> seed() async {
    final d = await Db.db;
    for (final t in ['logs', 'bike', 'routine_exercises', 'routines']) {
      await d.delete(t);
    }
    final ex = (await Db.exercises()).firstWhere((e) => e.kind == Kind.weight);
    await Db.saveRoutine(null, 'Pecho', [ex.id]);
    final id = (await Db.routines()).first['id'] as int;
    return (id, ex);
  }

  test('marcar series, guardar y volver a la rutina limpia', () async {
    final (id, ex) = await seed();
    final c = WorkoutController(id, 'Pecho');
    await c.load();
    await c.changeDate('2020-01-06'); // sesión de un día pasado

    expect(c.loading, isFalse);
    expect(c.rows[ex.name], hasLength(baseSets));
    expect(c.anyDone, isFalse);

    c.addSet(ex);
    c.setWeight(ex, 0, '20');
    c.setReps(ex, 0, '8');
    c.toggle(ex, 0, true);
    expect(c.anyDone, isTrue);
    expect(c.rest, greaterThan(0), reason: 'marcar una serie inicia el descanso');

    expect(await c.finish(), 1);
    expect(c.rest, 0);
    expect(c.rows[ex.name], hasLength(baseSets), reason: 'quita las series extra');
    expect(c.rows[ex.name]!.every((s) => s.w.isEmpty && !s.done), isTrue);
    c.dispose();

    // Hoy aparece como "última vez" lo de ese día.
    final today = WorkoutController(id, 'Pecho');
    await today.load();
    expect(today.hints[ex.name], 'Última vez: 20 kg × 8');
    today.dispose();
  });

  test('sin series marcadas no guarda', () async {
    final (id, _) = await seed();
    final c = WorkoutController(id, 'Pecho');
    await c.load();
    expect(await c.finish(), 0);
    c.dispose();
  });

  testWidgets('la vista refleja lo que escribe el usuario y lo limpia al guardar', (t) async {
    late int id;
    late Ex ex;
    await t.runAsync(() async => (id, ex) = await seed());
    await t.pumpWidget(MaterialApp(home: Workout(id, 'Pecho')));
    Future<void> settle() async {
      for (var i = 0; i < 10; i++) {
        await t.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await t.pump(const Duration(milliseconds: 50));
      }
    }

    await settle();
    expect(find.text(ex.name), findsOneWidget);
    await t.enterText(find.byType(TextField).first, '25');
    await t.tap(find.byType(Checkbox).first);
    await t.pump();
    await t.tap(find.text('Guardar'));
    await settle();
    expect(find.text('Progreso guardado: 1 series.'), findsOneWidget);
    expect(find.widgetWithText(TextField, '25'), findsNothing);

    await t.pumpWidget(const SizedBox()); // cierra la pantalla: cancela timers
  });
}
