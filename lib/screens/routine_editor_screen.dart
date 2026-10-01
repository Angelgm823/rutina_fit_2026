import 'package:flutter/material.dart';
import 'package:rutina_fit/database/db.dart';
import 'package:rutina_fit/models/exercises.dart';
import 'package:rutina_fit/screens/exercise_picker_screen.dart';

class RoutineEditor extends StatefulWidget {
  final int? id;
  final String? name;
  const RoutineEditor({super.key, this.id, this.name});
  @override
  State<RoutineEditor> createState() => _RoutineEditorState();
}

class _RoutineEditorState extends State<RoutineEditor> {
  late final name = TextEditingController(text: widget.name ?? '');
  List<Ex> chosen = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.id != null) chosen = await Db.routineExercises(widget.id!);
    if (mounted) setState(() => loading = false);
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final r = await Navigator.push<List<Ex>>(
      context,
      MaterialPageRoute(builder: (_) => ExercisePicker(selected: chosen)),
    );
    if (r != null) setState(() => chosen = r);
  }

  Future<void> _save() async {
    final msg = ScaffoldMessenger.of(context);
    final n = name.text.trim();
    if (n.isEmpty) {
      msg.showSnackBar(
        const SnackBar(content: Text('Ponle un nombre a la rutina.')),
      );
      return;
    }
    if (chosen.isEmpty) {
      msg.showSnackBar(
        const SnackBar(content: Text('Agrega al menos un ejercicio.')),
      );
      return;
    }
    try {
      await Db.saveRoutine(widget.id, n, [for (final e in chosen) e.id]);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      final dup = e.toString().contains('UNIQUE');
      msg.showSnackBar(
        SnackBar(
          content: Text(
            dup
                ? 'Ya tienes una rutina con ese nombre.'
                : 'No se pudo guardar: $e',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(
      title: Text(widget.id == null ? 'Nueva rutina' : 'Editar rutina'),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('Guardar'),
          ),
        ),
      ],
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: name,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Nombre (ej. Lunes pecho)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              Expanded(
                child: chosen.isEmpty
                    ? const Center(
                        child: Text(
                          'Aún no hay ejercicios.\nToca "Agregar ejercicios".',
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ReorderableListView(
                        onReorderItem: (a, b) => setState(() {
                          chosen.insert(b, chosen.removeAt(a));
                        }),
                        children: [
                          for (final e in chosen)
                            ListTile(
                              key: ValueKey(e.id),
                              title: Text(e.name),
                              subtitle: Text('${e.sub} · ${e.reps} ${e.unit}'),
                              trailing: IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () =>
                                    setState(() => chosen.remove(e)),
                              ),
                            ),
                        ],
                      ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (chosen.length > 1)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Mantén presionado un ejercicio para cambiar su orden.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      OutlinedButton.icon(
                        onPressed: _add,
                        icon: const Icon(Icons.add),
                        label: const Text('Agregar ejercicios'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
  );
}
