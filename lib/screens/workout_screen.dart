import 'dart:async';
import 'dart:math' show max;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rutina_fit/database/db.dart';
import 'package:rutina_fit/models/exercises.dart';
import 'package:rutina_fit/utils/format.dart';
import 'package:rutina_fit/widgets/day_picker.dart';
import 'package:rutina_fit/widgets/exercise_info.dart';

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
  int restTotal = 90, rest = 0;
  Timer? timer;
  bool loading = true;

  List<Ex> exs = [];

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
      if (l != null) hints[e.name] = 'Última vez: ${fmt(l['weight'] as num)} kg × ${l['reps']}';
    }
    if (mounted) setState(() => loading = false);
  }

  /// Cambia el día de la sesión y carga lo que hubiera guardado en ese día.
  Future<void> _changeDate(String d) async {
    if (d == date) return;
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
    Db.save(date, widget.routine, e.name, i, double.tryParse(s.w.text.replaceAll(',', '.')) ?? 0,
        int.tryParse(s.r.text) ?? 0, s.done);
  }

  void _toggle(Ex e, int i, bool v) {
    setState(() => rows[e.name]![i].done = v);
    _save(e, i);
    if (v) _startRest();
  }

  void _startRest() {
    timer?.cancel();
    setState(() => rest = restTotal);
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (rest <= 1) {
        t.cancel();
        setState(() => rest = 0);
        HapticFeedback.heavyImpact();
        SystemSound.play(SystemSoundType.alert);
      } else {
        setState(() => rest--);
      }
    });
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
      if (l != null) newHints[e.name] = 'Última vez: ${fmt(l['weight'] as num)} kg × ${l['reps']}';
    }
    if (!mounted) return;

    final removed = <SetRow>[];
    timer?.cancel();
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
      rest = 0;
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
              child: FilledButton.icon(
                onPressed: loading ? null : _finish,
                icon: const Icon(Icons.save),
                label: const Text('Guardar'),
              ),
            ),
          ],
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(padding: const EdgeInsets.all(12), children: [
                DayPicker(selected: date, onChanged: _changeDate),
                const SizedBox(height: 12),
                for (final e in exs) _card(e),
              ]),
        bottomNavigationBar: _restBar(),
      );

  Widget _card(Ex e) {
    final list = rows[e.name]!;
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.name, style: theme.textTheme.titleMedium),
                Text([e.reps, if (e.equipment.isNotEmpty) e.equipment].join(' · ')),
                if (hints[e.name] != null)
                  Text(hints[e.name]!, style: TextStyle(color: theme.colorScheme.primary)),
              ]),
            ),
            const SizedBox(width: 8),
            ExerciseInfoButton(e),
          ]),
          const SizedBox(height: 4),
          for (var i = 0; i < list.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Checkbox(value: list[i].done, onChanged: (v) => _toggle(e, i, v ?? false)),
                Text('Serie ${i + 1}'),
                const SizedBox(width: 12),
                Expanded(child: _field(list[i].w, 'kg', e, i)),
                const SizedBox(width: 8),
                Expanded(child: _field(list[i].r, e.unit, e, i)),
              ]),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => setState(() => list.add(SetRow())),
              icon: const Icon(Icons.add),
              label: const Text('Serie'),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _field(TextEditingController t, String label, Ex e, int i) => TextField(
        controller: t,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, isDense: true, border: const OutlineInputBorder()),
        onChanged: (_) => _save(e, i),
      );

  Widget _restBar() {
    final theme = Theme.of(context);
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: theme.colorScheme.surfaceContainerHigh,
        child: rest > 0
            ? Row(children: [
                Text('${rest ~/ 60}:${(rest % 60).toString().padLeft(2, '0')}',
                    style: theme.textTheme.headlineMedium),
                const Spacer(),
                TextButton(onPressed: () => setState(() => rest += 15), child: const Text('+15 s')),
                TextButton(
                  onPressed: () {
                    timer?.cancel();
                    setState(() => rest = 0);
                  },
                  child: const Text('Saltar'),
                ),
              ])
            : Row(children: [
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
              ]),
      ),
    );
  }
}