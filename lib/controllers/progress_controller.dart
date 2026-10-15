import 'package:flutter/foundation.dart';
import 'package:rutina_fit/database/db.dart';

/// Resumen de una gráfica: sesiones, total y promedio por sesión.
class Stats {
  final int sessions;
  final double total;
  const Stats(this.sessions, this.total);
  factory Stats.of(List<Pt> d) => Stats(d.length, d.fold<double>(0, (s, pt) => s + pt.y));
  double get average => sessions == 0 ? 0 : total / sessions;
}

/// Datos de la pantalla de progreso: series de fuerza y cardio, filtradas por año y trimestre.
class ProgressController extends ChangeNotifier {
  static const maxSessions = 24; // sesiones visibles como máximo en cada gráfica
  static const _qNames = ['Año completo', 'T1 · Ene–Mar', 'T2 · Abr–Jun', 'T3 · Jul–Sep', 'T4 · Oct–Dic'];

  bool loaded = false;
  List<Pt> strength = []; // ejercicios hechos por sesión
  List<Pt> cardio = []; // minutos de cardio por sesión

  // Periodo: año + trimestre (0 = año completo). Por defecto, el trimestre actual.
  int year = DateTime.now().year;
  int quarter = (DateTime.now().month - 1) ~/ 3 + 1;

  bool _disposed = false;

  String get period => quarter == 0 ? 'Año $year' : '${_qNames[quarter]} $year';
  bool get canNextYear => year < DateTime.now().year;
  bool get isEmpty => strength.isEmpty && cardio.isEmpty;

  // Solo se muestran las gráficas que tienen datos en el periodo elegido.
  List<Pt> get strengthInPeriod => _inPeriod(strength);
  List<Pt> get cardioInPeriod => _inPeriod(cardio);

  List<Pt> _inPeriod(List<Pt> all) =>
      all.where((pt) => pt.x.year == year && (quarter == 0 || (pt.x.month - 1) ~/ 3 + 1 == quarter)).toList();

  /// Carga (o recarga al arrastrar hacia abajo) las gráficas.
  Future<void> load() async {
    final s = await Db.strengthSeries();
    final b = await Db.bikeSeries();
    if (_disposed) return;
    strength = s;
    cardio = b;
    loaded = true;
    notifyListeners();
  }

  void prevYear() {
    year--;
    notifyListeners();
  }

  void nextYear() {
    if (!canNextYear) return;
    year++;
    notifyListeners();
  }

  void setQuarter(int q) {
    quarter = q;
    notifyListeners();
  }

  /// Las últimas [maxSessions] sesiones del periodo.
  static List<Pt> lastSessions(List<Pt> d) => d.length > maxSessions ? d.sublist(d.length - maxSessions) : d;

  /// Una etiqueta por sesión: "29/9" (con hora si hay dos el mismo día).
  static List<String> labels(List<Pt> d) {
    String base(Pt pt) => '${pt.x.day}/${pt.x.month}';
    String two(int n) => n.toString().padLeft(2, '0');
    final count = <String, int>{};
    for (final pt in d) {
      count[base(pt)] = (count[base(pt)] ?? 0) + 1;
    }
    return [for (final pt in d) count[base(pt)]! > 1 ? '${base(pt)} ${two(pt.x.hour)}:${two(pt.x.minute)}' : base(pt)];
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
