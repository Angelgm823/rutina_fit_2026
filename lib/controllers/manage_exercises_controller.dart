import 'package:flutter/foundation.dart';
import 'package:rutina_fit/database/db.dart';

/// Un ejercicio con todos sus campos (incluido si está eliminado), para la pantalla de gestión.
class ManagedEx {
  final int id;
  final String name, category, sub, reps, tip, unit, equipment, descr;
  final bool custom, active, deleted;
  const ManagedEx({
    required this.id,
    required this.name,
    required this.category,
    required this.sub,
    required this.reps,
    required this.tip,
    required this.unit,
    required this.equipment,
    required this.descr,
    required this.custom,
    required this.active,
    required this.deleted,
  });

  factory ManagedEx.fromMap(Map<String, Object?> m) => ManagedEx(
        id: m['id'] as int,
        name: m['name'] as String,
        category: (m['category'] as String?) ?? 'Superior',
        sub: (m['sub'] as String?) ?? '',
        reps: (m['reps'] as String?) ?? '8–12',
        tip: (m['tip'] as String?) ?? '',
        unit: (m['unit'] as String?) ?? 'reps',
        equipment: (m['equipment'] as String?) ?? '',
        descr: (m['descr'] as String?) ?? '',
        custom: m['custom'] == 1,
        active: m['active'] == 1,
        deleted: m['deleted'] == 1,
      );
}

/// Estado y lógica de la pantalla "Gestionar ejercicios": editar, eliminar (soft) y borrar
/// definitivamente. No conoce widgets: la vista decide cómo confirmar cada acción.
class ManageExercisesController extends ChangeNotifier {
  List<ManagedEx> all = [];
  bool loaded = false;
  bool _disposed = false;

  Future<void> load() async {
    final rows = await Db.allExercises();
    if (_disposed) return;
    all = [for (final r in rows) ManagedEx.fromMap(r)];
    loaded = true;
    notifyListeners();
  }

  Future<void> update(
    int id, {
    required String name,
    required String group,
    required String reps,
    required String unit,
    required String equipment,
    required String descr,
    required String tip,
  }) async {
    await Db.updateExercise(id, name: name, group: group, reps: reps, unit: unit, equipment: equipment, descr: descr, tip: tip);
    await load();
  }

  Future<void> softDelete(int id) async {
    await Db.softDeleteExercise(id);
    await load();
  }

  Future<void> restore(int id) async {
    await Db.restoreExercise(id);
    await load();
  }

  Future<void> hardDelete(int id) async {
    await Db.hardDeleteExercise(id);
    await load();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
