import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rutina_fit/database/db.dart';
import 'package:rutina_fit/services/notifications.dart';
import 'package:rutina_fit/widgets/day_picker.dart';
import 'package:rutina_fit/utils/format.dart';
import 'package:rutina_fit/widgets/save_button.dart';

class Bike extends StatefulWidget {
  final String name, descr;
  const Bike({super.key, this.name = 'Bicicleta estática', this.descr = ''});
  @override
  State<Bike> createState() => _BikeState();
}

class _BikeState extends State<Bike> {
  Duration acc = Duration.zero;
  DateTime? startedAt;
  Timer? ticker;
  final manual = TextEditingController();
  String date = dayKey(DateTime.now()); // puedes cambiarlo para registrar días pasados
  int goal = 0; // meta en minutos (0 = sin meta); al llegar, avisa con una notificación
  bool goalReached = false;

  @override
  void initState() {
    super.initState();
    manual.addListener(() => setState(() {})); // activa o desactiva el botón Guardar
  }

  bool get canSave => elapsed > Duration.zero || (int.tryParse(manual.text) ?? 0) > 0;

  bool get running => startedAt != null;
  Duration get elapsed => acc + (startedAt == null ? Duration.zero : DateTime.now().difference(startedAt!));

  String get clock {
    final s = elapsed.inSeconds;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  void _toggle() {
    if (running) {
      ticker?.cancel();
      setState(() {
        acc = elapsed;
        startedAt = null;
      });
      _cancelAlerts();
    } else {
      startedAt = DateTime.now();
      ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
      setState(() {});
      _notify();
    }
  }

  /// La hora sale de startedAt, así que el tiempo es exacto aunque la app haya estado en segundo plano.
  void _tick() {
    if (goal > 0 && !goalReached && elapsed.inSeconds >= goal * 60) {
      goalReached = true;
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
    }
    setState(() {});
  }

  /// Contador en la barra de notificaciones y, si hay meta, aviso programado para cuando la alcances.
  void _notify() {
    if (startedAt == null) return;
    final from = DateTime.now().subtract(elapsed);
    TimerAlerts.showRunning(
      TimerAlerts.cardioRunning,
      widget.name,
      goal > 0 ? 'Meta: $goal min' : 'Cronómetro en marcha',
      start: from,
    );
    TimerAlerts.cancel([TimerAlerts.cardioDone]);
    if (goal > 0 && !goalReached) {
      TimerAlerts.scheduleDone(
        TimerAlerts.cardioDone,
        from.add(Duration(minutes: goal)),
        '¡Meta alcanzada!',
        '${widget.name}: llevas $goal min. Guarda tu sesión cuando termines.',
      );
    }
  }

  void _setGoal(int m) {
    setState(() {
      goal = m;
      goalReached = m > 0 && elapsed.inSeconds >= m * 60;
    });
    _notify();
  }

  void _cancelAlerts() => TimerAlerts.cancel([TimerAlerts.cardioRunning, TimerAlerts.cardioDone]);

  void _reset() {
    ticker?.cancel();
    manual.clear();
    _cancelAlerts();
    setState(() {
      acc = Duration.zero;
      startedAt = null;
      goalReached = false;
    });
  }

  /// Al salir con el cronómetro en marcha se perdería el tiempo: pregunta primero.
  Future<void> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('¿Salir sin guardar?'),
        content: Text('El cronómetro lleva $clock. Si sales, se perderá ese tiempo.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Seguir')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Salir')),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.pop(context);
  }

  Future<void> _save() async {
    var secs = elapsed.inSeconds;
    if (secs == 0) secs = (int.tryParse(manual.text) ?? 0) * 60;
    if (secs == 0) return;
    final id = '$date ${DateTime.now().toIso8601String().substring(11, 19)}'; // día elegido + hora actual
    await Db.saveBike(id, secs, widget.name);
    if (!mounted) return;
    _reset();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${widget.name}: ${fmtMins(secs)} guardados')));
  }

  @override
  void dispose() {
    ticker?.cancel();
    if (startedAt != null) _cancelAlerts();
    manual.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final theme = Theme.of(c);
    return PopScope(
      canPop: elapsed == Duration.zero,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(widget.name, overflow: TextOverflow.ellipsis)),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            DayPicker(selected: date, onChanged: (d) => setState(() => date = d)),
            const SizedBox(height: 24),
            Center(child: Text(clock, style: theme.textTheme.displayLarge)),
            const SizedBox(height: 8),
            Center(
              child: Text(
                widget.descr.isEmpty ? 'Ritmo en el que puedas hablar sin ahogarte' : widget.descr,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final m in [0, 10, 20, 30, 45])
                  ChoiceChip(
                    label: Text(m == 0 ? 'Sin meta' : '$m min'),
                    showCheckmark: false,
                    selected: goal == m,
                    onSelected: (_) => _setGoal(m),
                  ),
              ],
            ),
            if (goal > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  goalReached ? '¡Meta de $goal min alcanzada!' : 'Te avisaremos al llegar a $goal min',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _toggle,
                    icon: Icon(running ? Icons.pause : Icons.play_arrow),
                    label: Text(running ? 'Pausar' : (acc == Duration.zero ? 'Iniciar' : 'Continuar')),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(onPressed: _reset, child: const Text('Reiniciar')),
              ],
            ),
            const SizedBox(height: 32),
            TextField(
              controller: manual,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Minutos (si no usaste el cronómetro)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SaveButton(onPressed: canSave ? _save : null, label: 'Guardar sesión de cardio', expand: true),
          ],
        ),
      ),
    );
  }
}
