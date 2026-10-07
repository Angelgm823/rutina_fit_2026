import 'dart:async';
import 'dart:math' show max;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rutina_fit/database/db.dart';
import 'package:rutina_fit/models/exercises.dart';
import 'package:rutina_fit/services/notifications.dart';
import 'package:rutina_fit/utils/format.dart';
import 'package:rutina_fit/widgets/day_picker.dart';
import 'package:rutina_fit/widgets/exercise_info.dart';
import 'package:rutina_fit/widgets/save_button.dart';

class SetRow {
  final w = TextEditingController();
  final r = TextEditingController();
  bool done = false;
}

class Workout extends StatefulWidget {
  final int routineId;
  final String routine;
  const Workout(this.routineId, this.routine, {super.key});
  @override
  State<Workout> createState() => _WorkoutState();
}

class _WorkoutState extends State<Workout> {
  String date = dayKey(DateTime.now()); // día de la sesión; puedes cambiarlo para registrar días pasados
  final rows = <String, List<SetRow>>{};
  final hints = <String, String>{};
  int restTotal = 90;
  DateTime? restEnd; // hora en que termina el descanso: sigue siendo exacta aunque la app esté en segundo plano
  Timer? timer;
  bool loading = true;

  // Cronómetro de la serie en curso (ejercicios por tiempo, como la plancha).
  SetRow? clockRow;
  DateTime? clockStart;
  Timer? clockTicker;

  List<Ex> exs = [];

  /// Liga: resistencia (1–3) en lugar del peso. Plancha y similares: cronómetro.
  bool _band(Ex e) => e.kind == Kind.band;
  bool _timed(Ex e) => e.kind == Kind.timed;

  /// Segundos de descanso que faltan (0 = sin descanso).
  int get rest {
    if (restEnd == null) return 0;
    final ms = restEnd!.difference(DateTime.now()).inMilliseconds;
    return ms <= 0 ? 0 : (ms / 1000).ceil();
  }

  bool get _anyDone => rows.values.any((l) => l.any((s) => s.done));

  String _hint(Ex e, Map<String, Object?> l) =>
      'Última vez: ${setText(e.kind, l['weight'] as num, l['reps'] as int, e.unit)}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    exs = await Db.routineExercises(widget.routineId);
    final saved = await Db.day(date, widget.routine);
    for (final e in exs) {
      final mine = saved.where((x) => x['exercise'] == e.name).toList();
      final n = mine.fold<int>(baseSets, (m, x) => max(m, (x['set_no'] as int) + 1));
      final list = List.generate(n, (_) => SetRow());
      for (final x in mine) {
        final s = list[x['set_no'] as int];
        final w = (x['weight'] as num).toDouble();
        final r = x['reps'] as int;
        s.w.text = w == 0 ? '' : fmt(w);
        s.r.text = r == 0 ? '' : '$r';
        s.done = x['done'] == 1;
      }
      rows[e.name] = list;
      final l = await Db.last(e.name, date);
      if (l != null) hints[e.name] = _hint(e, l);
    }
    if (mounted) setState(() => loading = false);
  }

  /// Cambia el día de la sesión y carga lo que hubiera guardado en ese día.
  Future<void> _changeDate(String d) async {
    if (d == date) return;
    _stopClock();
    final old = [for (final l in rows.values) ...l];
    setState(() {
      date = d;
      loading = true;
    });
    rows.clear();
    hints.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final s in old) {
        s.w.dispose();
        s.r.dispose();
      }
    });
    await _load();
  }

  void _save(Ex e, int i) {
    final s = rows[e.name]![i];
    Db.save(
      date,
      widget.routine,
      e.name,
      i,
      double.tryParse(s.w.text.replaceAll(',', '.')) ?? 0,
      int.tryParse(s.r.text) ?? 0,
      s.done,
    );
  }

  void _toggle(Ex e, int i, bool v) {
    setState(() => rows[e.name]![i].done = v);
    _save(e, i);
    if (v) _startRest();
  }

  /// Inicia o detiene el cronómetro de una serie; al detenerlo guarda los segundos y la marca hecha.
  void _clock(Ex e, int i) {
    final s = rows[e.name]![i];
    if (clockRow == s) {
      _stopClock();
      if ((int.tryParse(s.r.text) ?? 0) > 0) _toggle(e, i, true);
      return;
    }
    _stopClock();
    _stopRest();
    setState(() {
      clockRow = s;
      clockStart = DateTime.now();
      s.r.text = '0';
    });
    clockTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => s.r.text = '${DateTime.now().difference(clockStart!).inSeconds}');
    });
  }

  void _stopClock() {
    clockTicker?.cancel();
    clockTicker = null;
    if (clockRow != null && mounted) setState(() => clockRow = null);
    clockRow = null;
  }

  void _startRest() {
    timer?.cancel();
    setState(() => restEnd = DateTime.now().add(Duration(seconds: restTotal)));
    _notifyRest();
    timer = Timer.periodic(const Duration(milliseconds: 250), (t) {
      if (rest > 0) {
        setState(() {});
        return;
      }
      t.cancel();
      setState(() => restEnd = null);
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
      'Descanso · ${widget.routine}',
      'Toca para volver a la rutina',
      end: end,
    );
    TimerAlerts.scheduleDone(
      TimerAlerts.restDone,
      end,
      '¡Descanso terminado!',
      'Sigue con tu siguiente serie de ${widget.routine}.',
    );
  }

  void _addRest(int secs) {
    setState(() => restEnd = restEnd?.add(Duration(seconds: secs)));
    _notifyRest();
  }

  void _stopRest() {
    timer?.cancel();
    if (restEnd != null && mounted) setState(() => restEnd = null);
    restEnd = null;
    TimerAlerts.cancel([TimerAlerts.restRunning, TimerAlerts.restDone]);
  }

  Future<void> _finish() async {
    final done = rows.values.expand((l) => l).where((s) => s.done).length;
    if (done == 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Marca al menos una serie para guardar.')));
      return;
    }
    final id = '$date ${DateTime.now().toIso8601String().substring(11, 19)}'; // día elegido + hora actual
    await Db.finish(date, widget.routine, id);

    final newHints = <String, String>{};
    for (final e in exs) {
      final l = await Db.last(e.name, date);
      if (l != null) newHints[e.name] = _hint(e, l);
    }
    if (!mounted) return;

    final removed = <SetRow>[];
    _stopRest();
    _stopClock();
    setState(() {
      for (final l in rows.values) {
        while (l.length > baseSets) {
          removed.add(l.removeLast());
        }
        for (final s in l) {
          s.w.clear();
          s.r.clear();
          s.done = false;
        }
      }
      hints
        ..clear()
        ..addAll(newHints);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final s in removed) {
        s.w.dispose();
        s.r.dispose();
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Progreso guardado: $done series.')));
  }

  @override
  void dispose() {
    timer?.cancel();
    clockTicker?.cancel();
    if (restEnd != null) TimerAlerts.cancel([TimerAlerts.restRunning, TimerAlerts.restDone]);
    for (final l in rows.values) {
      for (final s in l) {
        s.w.dispose();
        s.r.dispose();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(
      title: Text(widget.routine),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: SaveButton(onPressed: loading || !_anyDone ? null : _finish),
        ),
      ],
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(12),
            children: [
              DayPicker(selected: date, onChanged: _changeDate),
              const SizedBox(height: 12),
              for (final e in exs) _card(e),
            ],
          ),
    bottomNavigationBar: _restBar(),
  );

  Widget _card(Ex e) {
    final list = rows[e.name]!;
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.name, style: theme.textTheme.titleMedium),
                      Text([e.reps, if (e.equipment.isNotEmpty) e.equipment].join(' · ')),
                      if (hints[e.name] != null)
                        Text(hints[e.name]!, style: TextStyle(color: theme.colorScheme.primary)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ExerciseInfoButton(e),
              ],
            ),
            const SizedBox(height: 4),
            for (var i = 0; i < list.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Checkbox(value: list[i].done, onChanged: (v) => _toggle(e, i, v ?? false)),
                    Text('Serie ${i + 1}'),
                    const SizedBox(width: 12),
                    if (_timed(e)) ...[
                      Expanded(child: _field(list[i].r, 'seg', e, i)),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        onPressed: () => _clock(e, i),
                        icon: Icon(clockRow == list[i] ? Icons.stop : Icons.play_arrow),
                        tooltip: clockRow == list[i] ? 'Detener' : 'Iniciar cronómetro',
                      ),
                    ] else ...[
                      if (_band(e)) _level(list[i], e, i) else Expanded(child: _field(list[i].w, 'kg', e, i)),
                      const SizedBox(width: 8),
                      Expanded(child: _field(list[i].r, e.unit, e, i)),
                    ],
                  ],
                ),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => setState(() => list.add(SetRow())),
                icon: const Icon(Icons.add),
                label: const Text('Serie'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController t, String label, Ex e, int i) => TextField(
    controller: t,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(labelText: label, isDense: true, border: const OutlineInputBorder()),
    onChanged: (_) => _save(e, i),
  );

  /// Selector de resistencia de la liga (1 = suave, 3 = fuerte); se guarda en la columna de peso.
  Widget _level(SetRow s, Ex e, int i) => SegmentedButton<int>(
    segments: const [
      ButtonSegment(value: 1, label: Text('1')),
      ButtonSegment(value: 2, label: Text('2')),
      ButtonSegment(value: 3, label: Text('3')),
    ],
    selected: {if (int.tryParse(s.w.text) case final n? when n >= 1 && n <= 3) n},
    emptySelectionAllowed: true,
    showSelectedIcon: false,
    style: const ButtonStyle(visualDensity: VisualDensity.compact),
    onSelectionChanged: (v) {
      setState(() => s.w.text = v.isEmpty ? '' : '${v.first}');
      _save(e, i);
    },
  );

  Widget _restBar() {
    final theme = Theme.of(context);
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: theme.colorScheme.surfaceContainerHigh,
        child: rest > 0
            ? Row(
                children: [
                  Text(
                    '${rest ~/ 60}:${(rest % 60).toString().padLeft(2, '0')}',
                    style: theme.textTheme.headlineMedium,
                  ),
                  const Spacer(),
                  TextButton(onPressed: () => _addRest(15), child: const Text('+15 s')),
                  TextButton(onPressed: _stopRest, child: const Text('Saltar')),
                ],
              )
            : Row(
                children: [
                  const Icon(Icons.timer_outlined),
                  const SizedBox(width: 8),
                  for (final s in [60, 90, 120])
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text('$s s'),
                        showCheckmark: false,
                        visualDensity: VisualDensity.compact,
                        selected: restTotal == s,
                        onSelected: (_) => setState(() => restTotal = s),
                      ),
                    ),
                  const Spacer(),
                  FilledButton(onPressed: _startRest, child: const Text('Iniciar')),
                ],
              ),
      ),
    );
  }
}
