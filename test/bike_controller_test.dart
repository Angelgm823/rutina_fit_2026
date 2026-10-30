import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rutina_fit/controllers/bike_controller.dart';
import 'package:rutina_fit/database/db.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  TestWidgetsFlutterBinding.ensureInitialized();
  // Base propia: los archivos de test corren en paralelo y otros usan rutina.db.
  setUpAll(() async => databaseFactory.setDatabasesPath(
      (await Directory.systemTemp.createTemp('bike_test')).path));

  test('minutos a mano: habilita guardar, guarda y reinicia', () async {
    final c = BikeController('Bicicleta estática');
    expect(c.canSave, isFalse);

    c.setManual('25');
    expect(c.canSave, isTrue);

    c.setDate('2020-01-06');
    expect(await c.save(), 25 * 60);
    expect(c.manual, isEmpty);
    expect(c.canSave, isFalse);
    expect((await Db.bikeSeries()).single.x.year, 2020);
    c.dispose();
  });

  test('cuenta regresiva: pausar conserva lo que falta y guarda lo transcurrido', () async {
    final c = BikeController('Bicicleta estática');
    c.setTotal(2);
    c.start();
    expect(c.running, isTrue);
    await Future.delayed(const Duration(milliseconds: 1100));
    c.pause();
    expect(c.running, isFalse);
    expect(c.remaining, 1);
    expect(c.clock, '0:01');

    c.setDate('2020-01-06');
    expect(await c.save(), 1);
    expect(c.total, 0);
    expect(await c.save(), 0, reason: 'sin tiempo no guarda');
    c.dispose();
  });

  test('cuenta regresiva: al llegar a 0 sola, guardar sigue activo con los minutos programados', () async {
    final c = BikeController('Bicicleta estática');
    c.setTotal(1);
    c.start();
    await Future.delayed(const Duration(milliseconds: 1300));
    expect(c.running, isFalse);
    expect(c.remaining, 0);
    expect(c.canSave, isTrue, reason: 'debe seguir activo al terminar, no desactivarse');

    c.setDate('2020-01-06');
    expect(await c.save(), 1);
    c.dispose();
  });
}
