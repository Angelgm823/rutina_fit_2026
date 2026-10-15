import 'dart:async';
import 'dart:math' show max;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show HapticFeedback, SystemSound, SystemSoundType;
import 'package:rutina_fit/database/db.dart';
import 'package:rutina_fit/models/exercises.dart';
import 'package:rutina_fit/services/notifications.dart';
import 'package:rutina_fit/utils/format.dart';
import 'package:rutina_fit/widgets/day_picker.dart' show dayKey;

/// Una serie tal como la escribió el usuario (texto crudo, se interpreta al guardar).
class SetData {
  String w = '';
  String r = '';
  bool done = false;
}

/// Estado y lógica de una sesión de rutina: series, descanso, cronómetro y guardado.
/// La vista solo dibuja y reenvía eventos.
class WorkoutController extends ChangeNotifier {
  final int routineId;
  final String routine;
  WorkoutController(this.routineId, this.routine);

  String date = dayKey(DateTime.now()); // día de la sesión; puedes cambiarlo para registrar días pasados
  final rows = <String, List<SetData>>{};
  final hints = <String, String>{};
  List<Ex> exs = [];
  bool loading = true;

  int restTotal = 90;
  DateTime? restEnd; // hora en que termina el descanso: sigue siendo exacta aunque la app esté en segundo plano
  Timer? _restTicker;

  // Cronómetro de la serie en curso (ejercicios por tiempo, como la plancha).
  SetData? clockRow;
  DateTime? _clockStart;
  Timer? _clockTicker;

  bool _disposed = false;

  /// Segundos de descanso que faltan (0 = sin descanso).
  int get rest {
    if (restEnd == null) return 0;
    final ms = restEnd!.difference(DateTime.now()).inMilliseconds;
    return ms <= 0 ? 0 : (ms / 1000).ceil();
  }

  bool get anyDone => rows.values.any((l) => l.any((s) => s.done));

  /// Resistencia de la liga (1–3) guardada en el campo de peso, o null si no hay.
  int? level(SetData s) => switch (int.tryParse(s.w)) {
        final n? when n >= 1 && n <= 3 => n,
        _ => null,
      };

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  String _hint(Ex e, Map<String, Object?> l) =>
      'Última vez: ${setText(e.kind, l['weight'] as num, l['reps'] as int, e.unit)}';

  Future<void> load() async {
    exs = await Db.routineExercises(routineId);
    final saved = await Db.day(date, routine);
    for (final e in exs) {
      final mine = saved.where((x) => x['exercise'] == e.name).toList();
      final n = mine.fold<int>(baseSets, (m, x) => max(m, (x['set_no'] as int) + 1));
      final list = List.generate(n, (_) => SetData());
      for (final x in mine) {
        final s = list[x['set_no'] as int];
        final w = (x['weight'] as num).toDouble();
        final r = x['reps'] as int;
        s.w = w == 0 ? '' : fmt(w);
        s.r = r == 0 ? '' : '$r';
        s.done = x['done'] == 1;
      }
      rows[e.name] = list;
      final l = await Db.last(e.name, date);
      if (l != null) hints[e.name] = _hint(e, l);
    }
    loading = false;
    _notify();
  }

  /// Cambia el día de la sesión y carga lo que hubiera guardado en ese día.
  Future<void> changeDate(String d) async {
    if (d == date) return;
    _stopClock();
    date = d;
    loading = true;
    rows.clear();
    hints.clear();
    _notify();
    await load();
  }

  void _save(Ex e, int i) {
    final s = rows[e.name]![i];
    Db.save(
      date,
      routine,
      e.name,
      i,
      double.tryParse(s.w.replaceAll(',', '.')) ?? 0,
      int.tryParse(s.r) ?? 0,
      s.done,
    );
  }

  /// Texto escrito por el usuario: no redibuja, el campo ya lo muestra.
  void setWeight(Ex e, int i, String v) {
    rows[e.name]![i].w = v;
    _save(e, i);
  }

  void setReps(Ex e, int i, String v) {
    rows[e.name]![i].r = v;
    _save(e, i);
  }

  void setLevel(Ex e, int i, int? v) {
    rows[e.name]![i].w = v == null ? '' : '$v';
    _notify();
    _save(e, i);
  }

  void addSet(Ex e) {
    rows[e.name]!.add(SetData());
    _notify();
  }

  void toggle(Ex e, int i, bool v) {
    rows[e.name]![i].done = v;
    _notify();
    _save(e, i);
    if (v) startRest();
  }

  /// Inicia o detiene el cronómetro de una serie; al detenerlo guarda los segundos y la marca hecha.
  void toggleClock(Ex e, int i) {
    final s = rows[e.name]![i];
    if (clockRow == s) {
      _stopClock();
      if ((int.tryParse(s.r) ?? 0) > 0) toggle(e, i, true);
      return;
    }
    _stopClock();
    stopRest();
    clockRow = s;
    _clockStart = DateTime.now();
    s.r = '0';
    _notify();
    _clockTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      s.r = '${DateTime.now().difference(_clockStart!).inSeconds}';
      _notify();
    });
  }

  void _stopClock() {
    _clockTicker?.cancel();
    _clockTicker = null;
    if (clockRow == null) return;
    clockRow = null;
    _notify();
  }

  void setRestTotal(int s) {
    restTotal = s;
    _notify();
  }

  void startRest() {
    _restTicker?.cancel();
    restEnd = DateTime.now().add(Duration(seconds: restTotal));
    _notify();
    _notifyRest();
    _restTicker = Timer.periodic(const Duration(milliseconds: 250), (t) {
      if (rest > 0) {
        _notify();
        return;
      }
      t.cancel();
      restEnd = null;
      _notify();
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
    });
  }

  /// Contador en la barra de notificaciones y aviso programado para cuando termine.
  void _notifyRest() {
    final end = restEnd;
    if (end == null) return;
    TimerAlerts.showRunning(
      TimerAlerts.restRunning,
      'Descanso · $routine',
      'Toca para volver a la rutina',
      end: end,
    );
    TimerAlerts.scheduleDone(
      TimerAlerts.restDone,
      end,
      '¡Descanso terminado!',
      'Sigue con tu siguiente serie de $routine.',
    );
  }

  void addRest(int secs) {
    restEnd = restEnd?.add(Duration(seconds: secs));
    _notify();
    _notifyRest();
  }

  void stopRest() {
    _restTicker?.cancel();
    if (restEnd != null) {
      restEnd = null;
      _notify();
    }
    TimerAlerts.cancel([TimerAlerts.restRunning, TimerAlerts.restDone]);
  }

  /// Cierra la sesión y deja la rutina lista para la siguiente.
  /// Devuelve cuántas series se guardaron (0 = ninguna marcada, no guarda nada).
  Future<int> finish() async {
    final done = rows.values.expand((l) => l).where((s) => s.done).length;
    if (done == 0) return 0;
    final id = '$date ${DateTime.now().toIso8601String().substring(11, 19)}'; // día elegido + hora actual
    await Db.finish(date, routine, id);

    final newHints = <String, String>{};
    for (final e in exs) {
      final l = await Db.last(e.name, date);
      if (l != null) newHints[e.name] = _hint(e, l);
    }
    if (_disposed) return done;

    stopRest();
    _stopClock();
    for (final l in rows.values) {
      l.length = l.length.clamp(0, baseSets);
      for (final s in l) {
        s
          ..w = ''
          ..r = ''
          ..done = false;
      }
    }
    hints
      ..clear()
      ..addAll(newHints);
    _notify();
    return done;
  }

  @override
  void dispose() {
    _disposed = true;
    _restTicker?.cancel();
    _clockTicker?.cancel();
    if (restEnd != null) TimerAlerts.cancel([TimerAlerts.restRunning, TimerAlerts.restDone]);
    super.dispose();
  }
}
