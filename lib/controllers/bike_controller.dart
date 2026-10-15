import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show HapticFeedback, SystemSound, SystemSoundType;
import 'package:rutina_fit/database/db.dart';
import 'package:rutina_fit/services/notifications.dart';
import 'package:rutina_fit/widgets/day_picker.dart' show dayKey;

/// Estado y lógica de una sesión de cardio: cronómetro, meta, minutos a mano y guardado.
class BikeController extends ChangeNotifier {
  final String name;
  BikeController(this.name);

  Duration acc = Duration.zero;
  DateTime? startedAt;
  Timer? _ticker;
  String manual = ''; // minutos escritos a mano (si no usaste el cronómetro)
  String date = dayKey(DateTime.now()); // puedes cambiarlo para registrar días pasados
  int goal = 0; // meta en minutos (0 = sin meta); al llegar, avisa con una notificación
  bool goalReached = false;

  bool _disposed = false;

  bool get running => startedAt != null;
  Duration get elapsed => acc + (startedAt == null ? Duration.zero : DateTime.now().difference(startedAt!));
  bool get canSave => elapsed > Duration.zero || (int.tryParse(manual) ?? 0) > 0;

  String get clock {
    final s = elapsed.inSeconds;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void setDate(String d) {
    date = d;
    _notify();
  }

  void setManual(String v) {
    manual = v;
    _notify(); // activa o desactiva el botón Guardar
  }

  void toggle() {
    if (running) {
      _ticker?.cancel();
      acc = elapsed;
      startedAt = null;
      _notify();
      _cancelAlerts();
    } else {
      startedAt = DateTime.now();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
      _notify();
      _notifyRunning();
    }
  }

  /// La hora sale de startedAt, así que el tiempo es exacto aunque la app haya estado en segundo plano.
  void _tick() {
    if (goal > 0 && !goalReached && elapsed.inSeconds >= goal * 60) {
      goalReached = true;
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
    }
    _notify();
  }

  /// Contador en la barra de notificaciones y, si hay meta, aviso programado para cuando la alcances.
  void _notifyRunning() {
    if (startedAt == null) return;
    final from = DateTime.now().subtract(elapsed);
    TimerAlerts.showRunning(
      TimerAlerts.cardioRunning,
      name,
      goal > 0 ? 'Meta: $goal min' : 'Cronómetro en marcha',
      start: from,
    );
    TimerAlerts.cancel([TimerAlerts.cardioDone]);
    if (goal > 0 && !goalReached) {
      TimerAlerts.scheduleDone(
        TimerAlerts.cardioDone,
        from.add(Duration(minutes: goal)),
        '¡Meta alcanzada!',
        '$name: llevas $goal min. Guarda tu sesión cuando termines.',
      );
    }
  }

  void setGoal(int m) {
    goal = m;
    goalReached = m > 0 && elapsed.inSeconds >= m * 60;
    _notify();
    _notifyRunning();
  }

  void _cancelAlerts() => TimerAlerts.cancel([TimerAlerts.cardioRunning, TimerAlerts.cardioDone]);

  void reset() {
    _ticker?.cancel();
    _cancelAlerts();
    manual = '';
    acc = Duration.zero;
    startedAt = null;
    goalReached = false;
    _notify();
  }

  /// Guarda la sesión y reinicia. Devuelve los segundos guardados (0 = nada que guardar).
  Future<int> save() async {
    var secs = elapsed.inSeconds;
    if (secs == 0) secs = (int.tryParse(manual) ?? 0) * 60;
    if (secs == 0) return 0;
    final id = '$date ${DateTime.now().toIso8601String().substring(11, 19)}'; // día elegido + hora actual
    await Db.saveBike(id, secs, name);
    if (!_disposed) reset();
    return secs;
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    if (startedAt != null) _cancelAlerts();
    super.dispose();
  }
}
