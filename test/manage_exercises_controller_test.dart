import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rutina_fit/controllers/manage_exercises_controller.dart';
import 'package:rutina_fit/database/db.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  TestWidgetsFlutterBinding.ensureInitialized();
  // Base propia: los archivos de test corren en paralelo y otros usan rutina.db.
  setUpAll(() async => databaseFactory.setDatabasesPath(
      (await Directory.systemTemp.createTemp('manage_exercises_test')).path));

  test('editar cambia todos los campos y el ejercicio sigue visible en el selector', () async {
    final id = await Db.addExercise('Press banca', 'Pecho', '8-12', 'reps');
    final ctrl = ManageExercisesController();
    await ctrl.load();

    await ctrl.update(id,
        name: 'Press banca inclinado',
        group: 'Hombros',
        reps: '6-10',
        unit: 'reps',
        equipment: 'Barra',
        descr: 'Sube y baja controlado.',
        tip: '');
    final e = ctrl.all.firstWhere((e) => e.id == id);
    expect(e.name, 'Press banca inclinado');
    expect(e.sub, 'Hombros');
    expect(e.equipment, 'Barra');
    expect(e.descr, 'Sube y baja controlado.');
    expect((await Db.exercises()).any((x) => x.id == id), isTrue);
  });

  test('soft delete oculta del selector pero se puede restaurar', () async {
    final id = await Db.addExercise('Curl martillo', 'Brazos', '8-12', 'reps');
    final ctrl = ManageExercisesController();
    await ctrl.load();

    await ctrl.softDelete(id);
    expect(ctrl.all.firstWhere((e) => e.id == id).deleted, isTrue);
    expect((await Db.exercises()).any((x) => x.id == id), isFalse, reason: 'oculto tras eliminar');

    await ctrl.restore(id);
    expect(ctrl.all.firstWhere((e) => e.id == id).deleted, isFalse);
    expect((await Db.exercises()).any((x) => x.id == id), isTrue, reason: 'visible tras restaurar');
  });

  test('borrado definitivo lo quita de la base y de las rutinas que lo usaban', () async {
    final id = await Db.addExercise('Remo con liga', 'Espalda', '8-12', 'reps');
    await Db.saveRoutine(null, 'Espalda y brazos', [id]);
    final ctrl = ManageExercisesController();
    await ctrl.load();

    await ctrl.hardDelete(id);
    expect(ctrl.all.any((e) => e.id == id), isFalse);

    final rows = await Db.routines();
    final r = rows.firstWhere((r) => r['name'] == 'Espalda y brazos');
    expect(r['n'], 0, reason: 'la rutina pierde el ejercicio borrado, no queda huérfano');
  });
}
