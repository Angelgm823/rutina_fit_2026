import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rutina_fit/controllers/history_controller.dart';
import 'package:rutina_fit/controllers/progress_controller.dart';
import 'package:rutina_fit/database/db.dart';
import 'package:rutina_fit/models/exercises.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  TestWidgetsFlutterBinding.ensureInitialized();
  // Base propia: los archivos de test corren en paralelo y otros usan rutina.db.
  setUpAll(() async => databaseFactory.setDatabasesPath(
      (await Directory.systemTemp.createTemp('progress_history_test')).path));

  group('ProgressController', () {
    test('etiquetas: hora solo si hay dos sesiones el mismo día', () {
      final d = [
        Pt(DateTime(2026, 9, 29, 8, 5), 1),
        Pt(DateTime(2026, 9, 29, 19, 30), 1),
        Pt(DateTime(2026, 10, 1, 7), 1),
      ];
      expect(ProgressController.labels(d), ['29/9 08:05', '29/9 19:30', '1/10']);
    });

    test('solo muestra las últimas sesiones', () {
      final d = [for (var i = 0; i < 30; i++) Pt(DateTime(2026, 1, 1 + i), i.toDouble())];
      final shown = ProgressController.lastSessions(d);
      expect(shown, hasLength(ProgressController.maxSessions));
      expect(shown.last.y, 29);
    });

    test('resumen: total y promedio', () {
      final st = Stats.of([Pt(DateTime(2026), 10), Pt(DateTime(2026), 20)]);
      expect(st.sessions, 2);
      expect(st.total, 30);
      expect(st.average, 15);
    });

    test('filtra por año y trimestre; no pasa del año actual', () {
      final c = ProgressController()
        ..cardio = [Pt(DateTime(2025, 2, 1), 10), Pt(DateTime(2025, 8, 1), 20)]
        ..year = 2025;
      c.setQuarter(1);
      expect(c.cardioInPeriod.single.y, 10);
      expect(c.period, 'T1 · Ene–Mar 2025');
      c.setQuarter(0);
      expect(c.cardioInPeriod, hasLength(2));
      expect(c.period, 'Año 2025');

      c.year = DateTime.now().year;
      expect(c.canNextYear, isFalse);
      c.nextYear();
      expect(c.year, DateTime.now().year);
      c.prevYear();
      expect(c.year, DateTime.now().year - 1);
      expect(c.canNextYear, isTrue);
    });
  });

  test('HistoryController: fuerza y cardio con sus textos y el detalle de la sesión', () async {
    final ex = (await Db.exercises()).firstWhere((e) => e.kind == Kind.weight);
    await Db.save('2026-01-06', 'Pecho', ex.name, 0, 20, 8, true);
    await Db.save('2026-01-06', 'Pecho', ex.name, 1, 0, 0, false);
    await Db.finish('2026-01-06', 'Pecho', '2026-01-06 10:00:00');
    await Db.saveBike('2026-01-07 08:00:00', 600, 'Bicicleta estática');

    final c = HistoryController();
    expect(c.loaded, isFalse);
    await c.load();
    expect(c.loaded, isTrue);
    expect(c.items, hasLength(2));

    final bike = c.items.first; // lo más reciente primero
    expect(bike.cardio, isTrue);
    expect(bike.title, '2026-01-07 08:00 · Bicicleta estática');
    expect(bike.subtitle, '10 min 0 s');

    final gym = c.items.last;
    expect(gym.cardio, isFalse);
    expect(gym.subtitle, '1 de 1 series completadas');
    expect(await c.sessionDetail(gym), ['${ex.name} · serie 1: 20 kg × 8']);
    c.dispose();
  });
}
