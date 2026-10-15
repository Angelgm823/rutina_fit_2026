import 'package:flutter/foundation.dart';
import 'package:rutina_fit/database/db.dart';
import 'package:rutina_fit/models/exercises.dart';
import 'package:rutina_fit/utils/format.dart';

/// Una fila del historial, ya con sus textos listos para mostrar.
class HistoryItem {
  final bool cardio;
  final String title, subtitle;
  final String date, routine; // para abrir el detalle de una sesión de fuerza
  const HistoryItem({
    required this.cardio,
    required this.title,
    required this.subtitle,
    this.date = '',
    this.routine = '',
  });

  factory HistoryItem.fromRow(Map<String, Object?> r) => r['type'] == 'bike'
      ? HistoryItem(
          cardio: true,
          title: '${shortDate(r['date'] as String)} · ${r['exercise'] ?? 'Bicicleta estática'}',
          subtitle: fmtMins(r['seconds'] as int),
        )
      : HistoryItem(
          cardio: false,
          title: '${shortDate(r['date'] as String)} · ${r['routine']}',
          subtitle: '${r['done']} de ${r['total']} series completadas',
          date: r['date'] as String,
          routine: r['routine'] as String,
        );
}

/// Carga el historial de sesiones (fuerza y cardio) y el detalle de cada una.
class HistoryController extends ChangeNotifier {
  bool loaded = false;
  List<HistoryItem> items = [];

  bool _disposed = false;

  /// Carga (o recarga al arrastrar hacia abajo) el historial.
  Future<void> load() async {
    final rows = await Db.timeline();
    if (_disposed) return;
    items = [for (final r in rows) HistoryItem.fromRow(r)];
    loaded = true;
    notifyListeners();
  }

  /// Series hechas en una sesión de fuerza: "Press banca · serie 1: 20 kg × 8".
  Future<List<String>> sessionDetail(HistoryItem it) async {
    final rows = (await Db.day(it.date, it.routine)).where((x) => x['done'] == 1);
    final exs = await Db.byName();
    return [
      for (final x in rows) '${x['exercise']} · serie ${(x['set_no'] as int) + 1}: ${_set(exs[x['exercise']], x)}',
    ];
  }

  static String _set(Ex? e, Map<String, Object?> x) => setText(
        e?.kind ?? kindOf(x['exercise'] as String, '', 'reps'),
        x['weight'] as num,
        x['reps'] as int,
        e?.unit ?? 'reps',
      );

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
