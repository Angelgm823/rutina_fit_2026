import 'package:flutter/material.dart';
import 'package:rutina_fit/controllers/workout_controller.dart';
import 'package:rutina_fit/models/exercises.dart';
import 'package:rutina_fit/services/rest_time_service.dart';
import 'package:rutina_fit/widgets/countdown_timer.dart';
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
      body: SafeArea(
        bottom: false,
        child: ctrl.loading
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
          // Plancha y similares: solo el reloj para fijar los minutos y el cronómetro. Sin campo de texto.
          if (e.kind == Kind.timed) ...[
            Expanded(
              child: Text(
                running
                    ? (s.goal > 0 ? CountdownTimer.fmt(ctrl.clockRemaining) : '${s.r} s')
                    : (s.goal > 0 ? CountdownTimer.fmt(s.goal) : 'Sin meta'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(width: 4),
            if (!running)
              IconButton(
                onPressed: () => _pickGoal(e, i, s),
                icon: Icon(s.goal > 0 ? Icons.timer : Icons.timer_outlined),
                tooltip: s.goal > 0 ? 'Meta: ${CountdownTimer.fmt(s.goal)}' : 'Poner meta de tiempo',
              ),
            const SizedBox(width: 4),
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

  /// Diálogo para fijar (o quitar) la meta de tiempo de una serie cronometrada.
  Future<void> _pickGoal(Ex e, int i, SetData s) async {
    var val = s.goal;
    await showDialog(
      context: context,
      builder: (c) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 100),
        child: StatefulBuilder(
          builder: (c, setSheetState) => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Meta de tiempo', style: Theme.of(c).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Déjalo en 0 para aguantar sin límite.',
                  style: Theme.of(c).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                CountdownTimer(
                  total: val,
                  remaining: val,
                  running: false,
                  maxSeconds: 300,
                  onTotalChanged: (v) => setSheetState(() => val = v),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(c),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          ctrl.setGoal(e, i, val);
                          Navigator.pop(c);
                        },
                        child: const Text('Listo'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
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

  String _formatRestTime(int seconds) {
    if (seconds >= 60) {
      final mins = seconds ~/ 60;
      final secs = seconds % 60;
      return secs > 0 ? '${mins}m ${secs}s' : '${mins}m';
    }
    return '${seconds}s';
  }

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
                    _formatRestTime(rest),
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
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final s in [60, 90, 120])
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(_formatRestTime(s)),
                                showCheckmark: false,
                                visualDensity: VisualDensity.compact,
                                selected: ctrl.restTotal == s,
                                onSelected: (_) => ctrl.setRestTotal(s),
                              ),
                            ),
                          for (final customTime in RestTimeService.getCustomTimes())
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: GestureDetector(
                                onLongPress: () => _showCustomTimeMenu(customTime),
                                child: ChoiceChip(
                                  label: Text(_formatRestTime(customTime.seconds)),
                                  showCheckmark: false,
                                  visualDensity: VisualDensity.compact,
                                  selected: ctrl.restTotal == customTime.seconds,
                                  onSelected: (_) => ctrl.setRestTotal(customTime.seconds),
                                ),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ActionChip(
                              label: const Text('+'),
                              onPressed: _showAddRestTimeDialog,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: ctrl.startRest, child: const Text('Iniciar')),
                ],
              ),
      ),
    );
  }

  Future<void> _showAddRestTimeDialog() async {
    final controller = TextEditingController();
    String unit = 's'; // 's' para segundos, 'm' para minutos

    final result = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Nuevo tiempo de descanso'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Número',
                  border: const OutlineInputBorder(),
                  suffixIcon: Padding(
                    padding: const EdgeInsets.all(4),
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(label: Text('s'), value: 's'),
                        ButtonSegment(label: Text('m'), value: 'm'),
                      ],
                      selected: {unit},
                      onSelectionChanged: (Set<String> newSelection) {
                        setState(() => unit = newSelection.first);
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final value = int.tryParse(controller.text);
                if (value == null || value <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Por favor ingresa un número válido'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                  return;
                }
                final seconds = unit == 'm' ? value * 60 : value;
                if (seconds > 1800) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('El máximo es 30 minutos (1800 segundos)'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                  return;
                }
                Navigator.pop(context, seconds);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      await RestTimeService.addCustomTime(result);
      setState(() {});
      ctrl.setRestTotal(result);
    }
  }

  Future<void> _showCustomTimeMenu(dynamic customTime) async {
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${_formatRestTime(customTime.seconds)} de descanso'),
        content: const Text('¿Qué deseas hacer?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'edit'),
            child: const Text('Editar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'delete'),
            child: const Text('Eliminar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );

    if (action == 'edit') {
      await _showEditRestTimeDialog(customTime);
    } else if (action == 'delete') {
      await _showDeleteConfirmDialog(customTime);
    }
  }

  Future<void> _showEditRestTimeDialog(dynamic customTime) async {
    final isMinutes = customTime.seconds >= 60 && customTime.seconds % 60 == 0;
    String unit = isMinutes ? 'm' : 's';
    final displayValue = isMinutes ? (customTime.seconds ~/ 60) : customTime.seconds;
    final controller = TextEditingController(text: displayValue.toString());

    final result = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Editar tiempo de descanso'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Número',
                  border: const OutlineInputBorder(),
                  suffixIcon: Padding(
                    padding: const EdgeInsets.all(4),
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(label: Text('s'), value: 's'),
                        ButtonSegment(label: Text('m'), value: 'm'),
                      ],
                      selected: {unit},
                      onSelectionChanged: (Set<String> newSelection) {
                        setState(() => unit = newSelection.first);
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final value = int.tryParse(controller.text);
                if (value == null || value <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Por favor ingresa un número válido'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                  return;
                }
                final seconds = unit == 'm' ? value * 60 : value;
                if (seconds > 1800) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('El máximo es 30 minutos (1800 segundos)'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                  return;
                }
                Navigator.pop(context, seconds);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      await RestTimeService.updateCustomTime(customTime.id, result);
      setState(() {});
      ctrl.setRestTotal(result);
    }
  }

  Future<void> _showDeleteConfirmDialog(dynamic customTime) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar tiempo de descanso'),
        content: Text('¿Eliminar ${_formatRestTime(customTime.seconds)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await RestTimeService.deleteCustomTime(customTime.id);
      setState(() {});
      if (ctrl.restTotal == customTime.seconds) {
        ctrl.setRestTotal(90);
      }
    }
  }
}
