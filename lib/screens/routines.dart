import 'package:flutter/material.dart';
import 'package:rutina_fit/database/db.dart';
import 'package:rutina_fit/models/exercises.dart';
import 'package:rutina_fit/screens/bike_screen.dart';
import 'package:rutina_fit/screens/routine_editor_screen.dart';
import 'package:rutina_fit/screens/workout_screen.dart';

class RoutinesScreen extends StatefulWidget {
  const RoutinesScreen({super.key});
  @override
  State<RoutinesScreen> createState() => _RoutinesScreenState();
}

class _RoutinesScreenState extends State<RoutinesScreen> {
  late Future<List<Map<String, Object?>>> future = Db.routines();

  // Con llaves: si el callback de setState devuelve un Future, Flutter lo rechaza y no redibuja.
  void _reload() => setState(() {
        future = Db.routines();
      });

  Future<void> _open(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (mounted) _reload();
  }

  Future<void> _delete(int id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('¿Eliminar "$name"?'),
        content: const Text('Las sesiones que ya guardaste se conservan en el historial.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok == true) {
      await Db.deleteRoutine(id);
      _reload();
    }
  }

  @override
  Widget build(BuildContext c) {
    final t = Theme.of(c).textTheme;
    return FutureBuilder<List<Map<String, Object?>>>(
      future: future,
      builder: (c, s) {
        final rows = s.data ?? [];
        return ListView(padding: const EdgeInsets.all(16), children: [
          Text('Mis rutinas', style: t.titleMedium),
          const SizedBox(height: 8),
          if (s.hasData && rows.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Aún no tienes rutinas. Crea la primera y elige los ejercicios que quieras.'),
              ),
            ),
          for (final r in rows)
            Card(
              child: ListTile(
                title: Text(r['name'] as String),
                subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${r['n']} ejercicios'),
                  FutureBuilder<List<String>>(
                    future: Db.routineDays(r['name'] as String),
                    builder: (c, s) => s.hasData && s.data!.isNotEmpty
                        ? Text(s.data!.join(' · '), style: const TextStyle(fontSize: 12))
                        : const SizedBox.shrink(),
                  ),
                ]),
                onTap: () => _open(Workout(r['id'] as int, r['name'] as String)),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) => v == 'edit'
                      ? _open(RoutineEditor(id: r['id'] as int, name: r['name'] as String))
                      : _delete(r['id'] as int, r['name'] as String),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Editar')),
                    PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 4),
          FilledButton.icon(
            onPressed: () => _open(const RoutineEditor()),
            icon: const Icon(Icons.add),
            label: const Text('Nueva rutina'),
          ),
          const SizedBox(height: 28),
          Text('Cardio', style: t.titleMedium),
          const SizedBox(height: 8),
          FutureBuilder<List<Ex>>(
            future: Db.cardio(),
            builder: (c, s) => Column(children: [
              for (final e in s.data ?? <Ex>[])
                Card(
                  child: ListTile(
                    leading: Icon(e.equipment.toLowerCase().contains('bicicleta') || e.name.toLowerCase().contains('bicicleta')
                        ? Icons.directions_bike
                        : (e.equipment.toLowerCase().contains('caminadora') || e.name.toLowerCase().contains('caminata') ? Icons.directions_walk : Icons.directions_run)),
                    title: Text(e.name),
                    subtitle: Text(e.equipment.isEmpty ? 'Cronómetro' : '${e.equipment} · cronómetro'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _open(Bike(name: e.name, descr: e.descr)),
                  ),
                ),
            ]),
          ),
        ]);
      },
    );
  }
}