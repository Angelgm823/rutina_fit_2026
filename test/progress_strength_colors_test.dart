import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rutina_fit/controllers/progress_controller.dart';
import 'package:rutina_fit/database/db.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  TestWidgetsFlutterBinding.ensureInitialized();
  // Base propia: los archivos de test corren en paralelo y otros usan rutina.db.
  setUpAll(() async => databaseFactory.setDatabasesPath(
      (await Directory.systemTemp.createTemp('progress_colors_test')).path));

  test('el color de un ejercicio propio se decide por el periodo visible, no por el histórico', () async {
    // Un ejercicio del catálogo con mucho volumen en 2025, y uno propio reciente que en el
    // trimestre actual se entrena más que cualquier otro: debe conseguir color también.
    await Db.save('2025-03-01', 'Rutina', 'Plancha abdominal', 0, 0, 30, true);
    await Db.addExercise('Remo con liga propio', 'Espalda', '8-12', 'reps');
    await Db.save('2026-10-05', 'Rutina', 'Remo con liga propio', 0, 10, 12, true);
    await Db.save('2026-10-05', 'Rutina', 'Plancha abdominal', 1, 0, 5, true);

    final c = ProgressController()
      ..year = 2026
      ..quarter = 4;
    await c.load();

    expect(c.strengthCategories, contains('Remo con liga propio'),
        reason: 'el ejercicio propio domina el trimestre visible, no debería caer en "Otros"');

    // Al mirar 2025 (donde ese ejercicio propio no existía) vuelve a decidirse con esos datos.
    c.year = 2025;
    c.setQuarter(0);
    expect(c.strengthCategories, isNot(contains('Remo con liga propio')));
    expect(c.strengthCategories, contains('Plancha abdominal'));
  });
}
