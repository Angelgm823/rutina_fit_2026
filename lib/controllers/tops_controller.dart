import 'package:flutter/foundation.dart';
import 'package:rutina_fit/database/db.dart';
import 'package:rutina_fit/models/exercises.dart';

/// Una marca personal: peso (o resistencia) y repeticiones, con la fecha en que se logró.
class TopEntry {
  final String date;
  final double weight;
  final int reps;
  const TopEntry({required this.date, required this.weight, required this.reps});
}

/// Una sesión de cardio para el ranking: duración y, si se guardó, el nombre del ejercicio.
class CardioEntry {
  final String date;
  final int seconds;
  final String exercise;
  const CardioEntry({required this.date, required this.seconds, required this.exercise});
}

/// Top 3 de cardio (sesiones más largas) y top 3 de peso de cada ejercicio con registros.
class TopsController extends ChangeNotifier {
  bool loaded = false;
  List<CardioEntry> cardio = [];
  List<(Ex, List<TopEntry>)> weights = [];

  bool _disposed = false;
  bool get isEmpty => cardio.isEmpty && weights.isEmpty;

  /// Carga (o recarga al arrastrar hacia abajo) los rankings.
  Future<void> load() async {
    final bikeRows = await Db.topCardio();
    final weightRows = await Db.topWeights();
    final exs = await Db.byName();
    if (_disposed) return;

    cardio = [
      for (final r in bikeRows)
        CardioEntry(
          date: r['date'] as String,
          seconds: r['seconds'] as int,
          exercise: (r['exercise'] as String?) ?? 'Bicicleta estática',
        ),
    ];

    weights = [
      for (final e in weightRows.entries)
        (
          exs[e.key] ??
              Ex(id: 0, name: e.key, category: 'Superior', sub: '', reps: '8–12', tip: '', unit: 'reps', custom: false),
          [
            for (final r in e.value)
              TopEntry(date: r['date'] as String, weight: (r['weight'] as num).toDouble(), reps: r['reps'] as int),
          ],
        ),
    ];

    loaded = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
