import 'package:flutter/material.dart';
import 'package:rutina_fit/database/db.dart';
import 'package:rutina_fit/models/exercises.dart';
import 'package:rutina_fit/widgets/exercise_info.dart';

class ExercisePicker extends StatefulWidget {
  final List<Ex> selected;
  const ExercisePicker({super.key, required this.selected});
  @override
  State<ExercisePicker> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends State<ExercisePicker> {
  List<Ex> all = [];
  late final List<int> order = [for (final e in widget.selected) e.id]; // orden de selección
  String cat = 'Todos', sub = 'Todas', query = '';
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
        for (final s in groups.entries)
          if (cat == 'Todos' || s.value == cat) s.key,
      ];

  List<Ex> get shown {
    final q = query.trim().toLowerCase();
    return [
      for (final e in all)
        if ((cat == 'Todos' || e.category == cat) &&
            (sub == 'Todas' || e.sub == sub) &&
            (q.isEmpty || e.name.toLowerCase().contains(q) || e.equipment.toLowerCase().contains(q)))
          e,
    ];
  }

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
    var subSel = sub != 'Todas' ? sub : groups.keys.first;
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
                items: [for (final s in groups.keys) DropdownMenuItem(value: s, child: Text('$s (${groups[s]})'))],
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
  Widget build(BuildContext c) {
    final list = shown;
    return Scaffold(
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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: TextField(
                  onChanged: (v) => setState(() => query = v),
                  decoration: const InputDecoration(
                    hintText: 'Buscar (ej. remo, mancuernas, liga)',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  const Spacer(),
                  Text('${list.length} ejercicios', style: const TextStyle(fontSize: 12)),
                ]),
              ),
              Expanded(
                child: list.isEmpty
                    ? const Center(child: Text('No hay ejercicios con esos filtros.'))
                    : ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (c, i) {
                          final e = list[i];
                          final eq = e.equipment;
                          return CheckboxListTile(
                            value: order.contains(e.id),
                            controlAffinity: ListTileControlAffinity.leading,
                            secondary: ExerciseInfoButton(e),
                            onChanged: (v) => _toggle(e, v ?? false),
                            title: Text(e.name),
                            subtitle: Text('${e.sub}${eq.isEmpty ? '' : ' · $eq'}${e.custom ? ' · Mío' : ''}'),
                          );
                        },
                      ),
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
}