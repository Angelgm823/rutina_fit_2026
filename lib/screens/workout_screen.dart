import 'package:flutter/material.dart';
import 'package:rutina_fit/controllers/workout_controller.dart';
import 'package:rutina_fit/models/exercises.dart';
import 'package:rutina_fit/widgets/day_picker.dart';
import 'package:rutina_fit/widgets/exercise_info.dart';
import 'package:rutina_fit/widgets/save_button.dart';

class Workout extends StatefulWidget {
  final int routineId;
  final String routine;
  const Workout(this.routineId, this.routine, {super.key});
  @override
  State<Workout> createState() => _WorkoutState();
}

class _WorkoutState extends State<Workout> {
  late final ctrl = WorkoutController(widget.routineId, widget.routine);

  /// Campos de texto de cada serie (peso, reps). Son estado de UI: viven aquí, no en el controller.
  final _fields = <SetData, (TextEditingController, TextEditingController)>{};

  @override
  void initState() {
    super.initState();
    ctrl.addListener(_syncFields);
    ctrl.load();
  }

  (TextEditingController, TextEditingController) _fieldsOf(SetData s) =>
      _fields[s] ??= (TextEditingController(text: s.w), TextEditingController(text: s.r));

  /// Lleva a los campos lo que cambió el controller (cronómetro, liga, limpiar al guardar)
  /// y libera los de series que ya no existen.
  void _syncFields() {
    final live = {for (final l in ctrl.rows.values) ...l};
    final gone = [for (final s in _fields.keys) if (!live.contains(s)) s];
    final removed = [for (final s in gone) _fields.remove(s)!];
    _fields.forEach((s, f) {
      if (f.$1.text != s.w) f.$1.text = s.w;
      if (f.$2.text != s.r) f.$2.text = s.r;
    });
    if (removed.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final (w, r) in removed) {
        w.dispose();
        r.dispose();
      }
    });
  }

  Future<void> _finish() async {
    final msg = ScaffoldMessenger.of(context);
    final done = await ctrl.finish();
    msg.showSnackBar(SnackBar(
        content: Text(done == 0 ? 'Marca al menos una serie para guardar.' : 'Progreso guardado: $done series.')));
  }

  @override
  void dispose() {
    ctrl.removeListener(_syncFields);
    ctrl.dispose();
    for (final (w, r) in _fields.values) {
      w.dispose();
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => ListenableBuilder(
    listenable: ctrl,
    builder: (c, _) => Scaffold(
      appBar: AppBar(
        title: Text(widget.routine),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SaveButton(onPressed: ctrl.loading || !ctrl.anyDone ? null : _finish),
          ),
        ],
      ),
      body: ctrl.loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                DayPicker(
                  selected: ctrl.date,
                  onChanged: ctrl.changeDate,
                  routineDays: ctrl.days.toSet(),
                ),
                if (ctrl.dayMismatch) _mismatchBanner(),
                const SizedBox(height: 12),
                for (final e in ctrl.exs) _card(e),
              ],
            ),
      bottomNavigationBar: _restBar(),
    ),
  );

  /// Aviso cuando el día elegido no es uno de los días fijos de esta rutina.
  Widget _mismatchBanner() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.error.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.error),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: theme.colorScheme.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Este ejercicio no corresponde al día actual',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(Ex e) {
    final list = ctrl.rows[e.name]!;
    final hint = ctrl.hints[e.name];
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
                      if (hint != null) Text(hint, style: TextStyle(color: theme.colorScheme.primary)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ExerciseInfoButton(e),
              ],
            ),
            const SizedBox(height: 4),
            for (var i = 0; i < list.length; i++) _setRow(e, i, list[i]),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => ctrl.addSet(e),
                icon: const Icon(Icons.add),
                label: const Text('Serie'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _setRow(Ex e, int i, SetData s) {
    final (w, r) = _fieldsOf(s);
    final running = ctrl.clockRow == s;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Checkbox(value: s.done, onChanged: (v) => ctrl.toggle(e, i, v ?? false)),
          Text('Serie ${i + 1}'),
          const SizedBox(width: 12),
          // Plancha y similares: cronómetro. Liga: resistencia (1–3) en lugar del peso.
          if (e.kind == Kind.timed) ...[
            Expanded(child: _field(r, 'seg', (v) => ctrl.setReps(e, i, v))),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              onPressed: () => ctrl.toggleClock(e, i),
              icon: Icon(running ? Icons.stop : Icons.play_arrow),
              tooltip: running ? 'Detener' : 'Iniciar cronómetro',
            ),
          ] else ...[
            if (e.kind == Kind.band)
              _level(e, i, s)
            else
              Expanded(child: _field(w, 'kg', (v) => ctrl.setWeight(e, i, v))),
            const SizedBox(width: 8),
            Expanded(child: _field(r, e.unit, (v) => ctrl.setReps(e, i, v))),
          ],
        ],
      ),
    );
  }

  Widget _field(TextEditingController t, String label, ValueChanged<String> onChanged) => TextField(
    controller: t,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(labelText: label, isDense: true, border: const OutlineInputBorder()),
    onChanged: onChanged,
  );

  /// Selector de resistencia de la liga (1 = suave, 3 = fuerte); se guarda en la columna de peso.
  Widget _level(Ex e, int i, SetData s) => SegmentedButton<int>(
    segments: const [
      ButtonSegment(value: 1, label: Text('1')),
      ButtonSegment(value: 2, label: Text('2')),
      ButtonSegment(value: 3, label: Text('3')),
    ],
    selected: {?ctrl.level(s)},
    emptySelectionAllowed: true,
    showSelectedIcon: false,
    style: const ButtonStyle(visualDensity: VisualDensity.compact),
    onSelectionChanged: (v) => ctrl.setLevel(e, i, v.isEmpty ? null : v.first),
  );

  Widget _restBar() {
    final theme = Theme.of(context);
    final rest = ctrl.rest;
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
                  TextButton(onPressed: () => ctrl.addRest(15), child: const Text('+15 s')),
                  TextButton(onPressed: ctrl.stopRest, child: const Text('Saltar')),
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
                        selected: ctrl.restTotal == s,
                        onSelected: (_) => ctrl.setRestTotal(s),
                      ),
                    ),
                  const Spacer(),
                  FilledButton(onPressed: ctrl.startRest, child: const Text('Iniciar')),
                ],
              ),
      ),
    );
  }
}
