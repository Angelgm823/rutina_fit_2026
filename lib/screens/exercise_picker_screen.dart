import 'package:flutter/material.dart';
import 'package:rutina_fit/database/db.dart';
import 'package:rutina_fit/models/exercises.dart';

class ExercisePicker extends StatefulWidget {
  final List<Ex> selected;
  const ExercisePicker({super.key, required this.selected});
  @override
  State<ExercisePicker> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends State<ExercisePicker> {
  List<Ex> all = [];
  late final List<int> order = [for (final e in widget.selected) e.id]; // orden de selección
  String cat = 'Todos', sub = 'Todas';
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    all = await Db.exercises();
    if (mounted) setState(() => loading = false);
  }

  List<String> get subs => [
        for (final s in subcategories.entries)
          if (cat == 'Todos' || s.value == cat) s.key,
      ];

  List<Ex> get shown => [
        for (final e in all)
          if ((cat == 'Todos' || e.category == cat) && (sub == 'Todas' || e.sub == sub)) e,
      ];

  void _toggle(Ex e, bool on) => setState(() {
        if (on) {
          order.add(e.id);
        } else {
          order.remove(e.id);
        }
      });

  Future<void> _newExercise() async {
    final name = TextEditingController();
    final reps = TextEditingController(text: '8–12');
    var subSel = sub != 'Todas' ? sub : subcategories.keys.first;
    var unit = 'reps';
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('Nuevo ejercicio'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: name,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              const SizedBox(height: 12),
              DropdownButton<String>(
                isExpanded: true,
                value: subSel,
                items: [for (final s in subcategories.keys) DropdownMenuItem(value: s, child: Text('$s (${subcategories[s]})'))],
                onChanged: (v) => set(() => subSel = v ?? subSel),
              ),
              TextField(controller: reps, decoration: const InputDecoration(labelText: 'Repeticiones sugeridas')),
              const SizedBox(height: 12),
              DropdownButton<String>(
                isExpanded: true,
                value: unit,
                items: const [
                  DropdownMenuItem(value: 'reps', child: Text('Se mide en repeticiones')),
                  DropdownMenuItem(value: 'seg', child: Text('Se mide en segundos')),
                ],
                onChanged: (v) => set(() => unit = v ?? unit),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Crear')),
          ],
        ),
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    try {
      final id = await Db.addExercise(
          name.text.trim(), subSel, reps.text.trim().isEmpty ? '8–12' : reps.text.trim(), unit);
      await _load();
      setState(() => order.add(id));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Ya existe un ejercicio con ese nombre.')));
      }
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(
          title: const Text('Elegir ejercicios'),
          actions: [IconButton(icon: const Icon(Icons.add), tooltip: 'Nuevo ejercicio', onPressed: _newExercise)],
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 'Todos', label: Text('Todos')),
                      ButtonSegment(value: 'Superior', label: Text('Superior')),
                      ButtonSegment(value: 'Inferior', label: Text('Inferior')),
                    ],
                    selected: {cat},
                    onSelectionChanged: (v) => setState(() {
                      cat = v.first;
                      sub = 'Todas';
                    }),
                  ),
                ),
                SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      for (final s in ['Todas', ...subs])
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                          child: ChoiceChip(
                            label: Text(s),
                            selected: sub == s,
                            showCheckmark: false,
                            onSelected: (_) => setState(() => sub = s),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(children: [
                    for (final e in shown)
                      CheckboxListTile(
                        value: order.contains(e.id),
                        onChanged: (v) => _toggle(e, v ?? false),
                        title: Text(e.name),
                        subtitle: Text('${e.sub} · ${e.reps} ${e.unit}${e.custom ? ' · Mío' : ''}'),
                      ),
                  ]),
                ),
              ]),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: FilledButton(
              onPressed: () => Navigator.pop(context, [
                for (final id in order) ...all.where((e) => e.id == id),
              ]),
              child: Text('Listo (${order.length})'),
            ),
          ),
        ),
      );
}