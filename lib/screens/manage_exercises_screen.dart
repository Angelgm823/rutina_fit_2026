import 'package:flutter/material.dart';
import 'package:rutina_fit/controllers/manage_exercises_controller.dart';
import 'package:rutina_fit/models/exercises.dart';

final _subOptions = [...groups.keys, cardioGroup];

/// Lista completa de ejercicios (propios y de catálogo) con edición, eliminación reversible
/// (soft delete) y borrado definitivo de la base de datos.
class ManageExercisesScreen extends StatefulWidget {
  const ManageExercisesScreen({super.key});
  @override
  State<ManageExercisesScreen> createState() => _ManageExercisesScreenState();
}

class _ManageExercisesScreenState extends State<ManageExercisesScreen> {
  final ctrl = ManageExercisesController();
  String filter = 'Activos'; // Activos | Eliminados | Todos
  String query = '';

  @override
  void initState() {
    super.initState();
    ctrl.load();
  }

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  List<ManagedEx> get _shown {
    final q = query.trim().toLowerCase();
    return [
      for (final e in ctrl.all)
        if ((filter == 'Todos' || (filter == 'Eliminados') == e.deleted) &&
            (q.isEmpty || e.name.toLowerCase().contains(q) || e.sub.toLowerCase().contains(q)))
          e,
    ];
  }

  Future<void> _edit(ManagedEx e) async {
    final name = TextEditingController(text: e.name);
    final reps = TextEditingController(text: e.reps);
    final equipment = TextEditingController(text: e.equipment);
    final descr = TextEditingController(text: e.descr);
    var subSel = _subOptions.contains(e.sub) ? e.sub : _subOptions.first;
    var unit = e.unit == 'seg' ? 'seg' : 'reps';
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('Editar ejercicio'),
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
                items: [for (final s in _subOptions) DropdownMenuItem(value: s, child: Text(s))],
                onChanged: (v) => set(() => subSel = v ?? subSel),
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
              TextField(controller: equipment, decoration: const InputDecoration(labelText: 'Equipo')),
              const SizedBox(height: 12),
              TextField(
                controller: descr,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Cómo se hace', alignLabelWithHint: true),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Guardar')),
          ],
        ),
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    try {
      await ctrl.update(
        e.id,
        name: name.text.trim(),
        group: subSel,
        reps: reps.text.trim().isEmpty ? '8–12' : reps.text.trim(),
        unit: unit,
        equipment: equipment.text.trim(),
        descr: descr.text.trim(),
        tip: e.tip,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Ya existe un ejercicio con ese nombre.')));
      }
    }
  }

  Future<void> _softDelete(ManagedEx e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('¿Eliminar "${e.name}"?'),
        content: const Text(
            'Se ocultará de las rutinas nuevas y del selector. Puedes restaurarlo cuando quieras desde "Eliminados".'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok == true) await ctrl.softDelete(e.id);
  }

  Future<void> _restore(ManagedEx e) => ctrl.restore(e.id);

  Future<void> _hardDelete(ManagedEx e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('¿Borrar "${e.name}" definitivamente?'),
        content: const Text('Esta acción no se puede deshacer: se borra de tu base de datos y se quita de las '
            'rutinas que lo usen. Las sesiones que ya guardaste conservan el nombre en tu historial, pero ya no '
            'podrás volver a seleccionarlo.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(c).colorScheme.error),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Borrar definitivamente'),
          ),
        ],
      ),
    );
    if (ok == true) await ctrl.hardDelete(e.id);
  }

  @override
  Widget build(BuildContext c) => ListenableBuilder(
        listenable: ctrl,
        builder: (c, _) {
          final list = _shown;
          return Scaffold(
            appBar: AppBar(title: const Text('Gestionar ejercicios')),
            body: !ctrl.loaded
                ? const Center(child: CircularProgressIndicator())
                : Column(children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: SegmentedButton<String>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(value: 'Activos', label: Text('Activos')),
                          ButtonSegment(value: 'Eliminados', label: Text('Eliminados')),
                          ButtonSegment(value: 'Todos', label: Text('Todos')),
                        ],
                        selected: {filter},
                        onSelectionChanged: (v) => setState(() => filter = v.first),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: TextField(
                        onChanged: (v) => setState(() => query = v),
                        decoration: const InputDecoration(
                          hintText: 'Buscar ejercicio',
                          prefixIcon: Icon(Icons.search),
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    Expanded(
                      child: list.isEmpty
                          ? const Center(child: Text('No hay ejercicios con esos filtros.'))
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: list.length,
                              itemBuilder: (c, i) {
                                final e = list[i];
                                return Card(
                                  child: ListTile(
                                    title: Text(e.name),
                                    subtitle: Text(
                                        '${e.sub}${e.equipment.isEmpty ? '' : ' · ${e.equipment}'}${e.custom ? ' · Mío' : ''}'),
                                    trailing: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
                                      if (e.deleted) const Padding(
                                        padding: EdgeInsets.only(right: 4),
                                        child: Chip(label: Text('Eliminado'), visualDensity: VisualDensity.compact),
                                      ),
                                      PopupMenuButton<String>(
                                        onSelected: (v) => switch (v) {
                                          'edit' => _edit(e),
                                          'delete' => _softDelete(e),
                                          'restore' => _restore(e),
                                          _ => _hardDelete(e),
                                        },
                                        itemBuilder: (_) => [
                                          if (!e.deleted) const PopupMenuItem(value: 'edit', child: Text('Editar')),
                                          if (!e.deleted) const PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                                          if (e.deleted) const PopupMenuItem(value: 'restore', child: Text('Restaurar')),
                                          const PopupMenuItem(value: 'hard', child: Text('Borrar definitivamente')),
                                        ],
                                      ),
                                    ]),
                                  ),
                                );
                              },
                            ),
                    ),
                  ]),
          );
        },
      );
}
