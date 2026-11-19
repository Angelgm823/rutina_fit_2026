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
  String cat = 'Todos', sub = 'Todas', query = '', location = 'Todos';
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

  List<Ex> get _filtered {
    final q = query.trim().toLowerCase();
    return [
      for (final e in all)
        if ((cat == 'Todos' || e.category == cat) &&
            (sub == 'Todas' || e.sub == sub) &&
            (location == 'Todos' || (location == 'GYM' && e.locationId == 1) || (location == 'CASA' && e.locationId == 2)) &&
            (q.isEmpty || e.name.toLowerCase().contains(q) || e.equipment.toLowerCase().contains(q)))
          e,
    ];
  }

  List<Ex> get shownCasa => [for (final e in _filtered) if (e.locationId == 2) e];
  List<Ex> get shownGym => [for (final e in _filtered) if (e.locationId == 1) e];

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
    final descr = TextEditingController();
    var subSel = sub != 'Todas' ? sub : groups.keys.first;
    var unit = 'reps';
    var locationId = 1; // 1=GYM, 2=CASA
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
              const SizedBox(height: 12),
              SegmentedButton<int>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 1, label: Text('GYM')),
                  ButtonSegment(value: 2, label: Text('CASA')),
                ],
                selected: {locationId},
                onSelectionChanged: (v) => set(() => locationId = v.first),
              ),
              const SizedBox(height: 12),
              TextField(controller: reps, decoration: const InputDecoration(labelText: 'Repeticiones sugeridas')),
              const SizedBox(height: 12),
              DropdownButton<String>(
                isExpanded: true,
                value: unit,
                items: const [
                  DropdownMenuItem(value: 'reps', child: Text('Se mide en repeticiones')),
                  DropdownMenuItem(value: 'seg', child: Text('Se mide en tiempo (segundos)')),
                ],
                onChanged: (v) => set(() => unit = v ?? unit),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descr,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Cómo se hace (opcional)',
                  alignLabelWithHint: true,
                ),
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
      final id = await Db.addExercise(name.text.trim(), subSel,
          reps.text.trim().isEmpty ? '8–12' : reps.text.trim(), unit, descr.text.trim(), locationId);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Elegir ejercicios'),
        actions: [IconButton(icon: const Icon(Icons.add), tooltip: 'Nuevo ejercicio', onPressed: _newExercise)],
      ),
      body: SafeArea(
        bottom: false,
        child: loading
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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 'Todos', label: Text('Todos')),
                    ButtonSegment(value: 'GYM', label: Text('GYM')),
                    ButtonSegment(value: 'CASA', label: Text('CASA')),
                  ],
                  selected: {location},
                  onSelectionChanged: (v) => setState(() => location = v.first),
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
                  Text('${shownCasa.length + shownGym.length} ejercicios', style: const TextStyle(fontSize: 12)),
                ]),
              ),
              Expanded(
                child: shownCasa.isEmpty && shownGym.isEmpty
                    ? const Center(child: Text('No hay ejercicios con esos filtros.'))
                    : ListView(
                        children: [
                          // Sección CASA
                          if (shownCasa.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                              child: Row(children: [
                                Icon(Icons.home, size: 18, color: Theme.of(c).colorScheme.primary),
                                const SizedBox(width: 8),
                                Text('CASA (${shownCasa.length})',
                                    style: Theme.of(c).textTheme.labelLarge),
                              ]),
                            ),
                            ...shownCasa.map((e) {
                              final eq = e.equipment;
                              return CheckboxListTile(
                                value: order.contains(e.id),
                                controlAffinity: ListTileControlAffinity.leading,
                                secondary: ExerciseInfoButton(e),
                                onChanged: (v) => _toggle(e, v ?? false),
                                title: Text(e.name),
                                subtitle: Text('${e.sub}${eq.isEmpty ? '' : ' · $eq'}${e.custom ? ' · Mío' : ''}'),
                              );
                            }),
                          ],
                          // Sección GYM
                          if (shownGym.isNotEmpty) ...[
                            if (shownCasa.isNotEmpty) const Divider(height: 24),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                              child: Row(children: [
                                Icon(Icons.fitness_center, size: 18, color: Theme.of(c).colorScheme.primary),
                                const SizedBox(width: 8),
                                Text('GYM (${shownGym.length})',
                                    style: Theme.of(c).textTheme.labelLarge),
                              ]),
                            ),
                            ...shownGym.map((e) {
                              final eq = e.equipment;
                              return CheckboxListTile(
                                value: order.contains(e.id),
                                controlAffinity: ListTileControlAffinity.leading,
                                secondary: ExerciseInfoButton(e),
                                onChanged: (v) => _toggle(e, v ?? false),
                                title: Text(e.name),
                                subtitle: Text('${e.sub}${eq.isEmpty ? '' : ' · $eq'}${e.custom ? ' · Mío' : ''}'),
                              );
                            }),
                          ],
                        ],
                      ),
              ),
            ]),
            ),
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