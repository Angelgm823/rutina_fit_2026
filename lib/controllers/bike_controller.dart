import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show HapticFeedback, SystemSound, SystemSoundType;
import 'package:rutina_fit/database/db.dart';
import 'package:rutina_fit/services/notifications.dart';
import 'package:rutina_fit/widgets/day_picker.dart' show dayKey;

/// Estado y lógica de una sesión de cardio: cuenta regresiva desde el tiempo elegido,
/// minutos a mano y guardado.
class BikeController extends ChangeNotifier {
  final String name;
  BikeController(this.name);

  int total = 0; // segundos elegidos (0 = aún sin elegir)
  int _pausedRemaining = 0; // segundos que quedaban cuando se pausó
  bool _finished = false; // llegó a 0 solo, sin pasar por pausa
  DateTime? _end; // hora en que termina: exacta aunque la app esté en segundo plano
  Timer? _ticker;
  String manual = ''; // minutos escritos a mano (si no usaste el cronómetro)
  String date = dayKey(DateTime.now()); // puedes cambiarlo para registrar días pasados

  bool _disposed = false;

  bool get running => _end != null;

  /// true si salir perdería progreso (corriendo, pausado a medias o recién cumplido sin guardar).
  bool get hasProgress => running || _pausedRemaining > 0 || _finished;

  /// Segundos que faltan: mientras corre, pausado con tiempo pendiente, cumplido (0) o el total si no empezó.
  int get remaining {
    final end = _end;
    if (end != null) {
      final ms = end.difference(DateTime.now()).inMilliseconds;
      return ms <= 0 ? 0 : (ms / 1000).ceil();
    }
    if (_finished) return 0;
    return _pausedRemaining > 0 ? _pausedRemaining : total;
  }

  int get _elapsedSecs => total - remaining;
  bool get canSave => _elapsedSecs > 0 || (int.tryParse(manual) ?? 0) > 0;

  String get clock {
    final s = remaining;
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

  /// Elige (o cambia) el tiempo total; solo mientras no corre.
  void setTotal(int secs) {
    if (running) return;
    total = secs;
    _pausedRemaining = 0;
    _finished = false;
    _notify();
  }

  void start() {
    if (running || total <= 0) return;
    final secsLeft = _pausedRemaining > 0 ? _pausedRemaining : total;
    _pausedRemaining = 0;
    _finished = false;
    _end = DateTime.now().add(Duration(seconds: secsLeft));
    _ticker?.cancel();
    _notify();
    _notifyRunning();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (t) {
      if (remaining > 0) {
        _notify();
        return;
      }
      t.cancel();
      _end = null;
      _finished = true;
      _notify();
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
    });
  }

  void pause() {
    if (!running) return;
    _ticker?.cancel();
    _pausedRemaining = remaining;
    _end = null;
    _notify();
    _cancelAlerts();
  }

  /// Contador en la barra de notificaciones y aviso programado para cuando termine.
  void _notifyRunning() {
    final end = _end;
    if (end == null) return;
    TimerAlerts.showRunning(TimerAlerts.cardioRunning, name, 'Cuenta regresiva en marcha', end: end);
    TimerAlerts.scheduleDone(
      TimerAlerts.cardioDone,
      end,
      '¡Tiempo cumplido!',
      '$name: terminaste tu sesión de cardio.',
    );
  }

  void _cancelAlerts() => TimerAlerts.cancel([TimerAlerts.cardioRunning, TimerAlerts.cardioDone]);

  void reset() {
    _ticker?.cancel();
    _cancelAlerts();
    manual = '';
    total = 0;
    _pausedRemaining = 0;
    _finished = false;
    _end = null;
    _notify();
  }

  /// Guarda la sesión y reinicia. Devuelve los segundos guardados (0 = nada que guardar).
  Future<int> save() async {
    var secs = _elapsedSecs;
    if (secs <= 0) secs = (int.tryParse(manual) ?? 0) * 60;
    if (secs <= 0) return 0;
    final id = '$date ${DateTime.now().toIso8601String().substring(11, 19)}'; // día elegido + hora actual
    await Db.saveBike(id, secs, name);
    if (!_disposed) reset();
    return secs;
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    if (running) _cancelAlerts();
    super.dispose();
  }
}
