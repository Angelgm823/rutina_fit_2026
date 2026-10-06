import 'package:rutina_fit/utils/format.dart';

/// Cómo se registra cada serie: peso en kg, resistencia de liga (1–3) o tiempo (plancha...).
enum Kind { weight, band, timed }

Kind kindOf(String name, String equipment, String unit) {
  final n = name.toLowerCase();
  if (unit == 'seg' || n.contains('plancha')) return Kind.timed;
  final text = '${equipment.toLowerCase()} $n';
  if (text.contains('liga') || text.contains('banda')) return Kind.band;
  return Kind.weight;
}

/// Texto de una serie: "20 kg × 8", "Resistencia 2 × 12" o "40 s".
String setText(Kind k, num w, int reps, [String unit = 'reps']) => switch (k) {
      Kind.timed => '$reps s',
      Kind.band => w == 0 ? '$reps reps' : 'Resistencia ${fmt(w)} × $reps',
      Kind.weight => w == 0 ? '$reps $unit' : '${fmt(w)} kg × $reps',
    };

class Ex {
  final int id;
  final String name, category, sub, reps, tip, unit, equipment, descr;
  final bool custom;
  const Ex({
    required this.id,
    required this.name,
    required this.category,
    required this.sub,
    required this.reps,
    required this.tip,
    required this.unit,
    required this.custom,
    this.equipment = '',
    this.descr = '',
  });

  Kind get kind => kindOf(name, equipment, unit);

  factory Ex.fromMap(Map<String, Object?> m) => Ex(
        id: m['id'] as int,
        name: m['name'] as String,
        category: (m['category'] as String?) ?? 'Superior',
        sub: (m['sub'] as String?) ?? '',
        reps: (m['reps'] as String?) ?? '8–12',
        tip: (m['tip'] as String?) ?? '',
        unit: (m['unit'] as String?) ?? 'reps',
        custom: m['custom'] == 1,
        equipment: (m['equipment'] as String?) ?? '',
        descr: (m['descr'] as String?) ?? '',
      );
}

const baseSets = 2;

const cardioGroup = 'Cardio';

/// Grupo muscular -> categoría (para los filtros Superior / Inferior).
/// Un grupo nuevo que agregues a tu base se cuenta como Superior; cámbialo aquí si no lo es.
const groups = <String, String>{
  'Pecho': 'Superior',
  'Espalda': 'Superior',
  'Brazos': 'Superior',
  'Hombros': 'Superior',
  'Abdomen': 'Superior',
  'Piernas y glúteos': 'Inferior',
};

const categories = ['Superior', 'Inferior'];

String categoryOf(String group) => group == cardioGroup ? 'Cardio' : (groups[group] ?? 'Superior');

const _groupNames = {
  'pecho': 'Pecho',
  'espalda': 'Espalda',
  'brazos': 'Brazos',
  'hombros': 'Hombros',
  'piernas_y_gluteos': 'Piernas y glúteos',
  'abdomen': 'Abdomen',
  'cardio': 'Cardio',
};

/// 'piernas_y_gluteos' -> 'Piernas y glúteos'
String groupLabel(String raw) {
  final key = raw.trim().toLowerCase();
  final known = _groupNames[key];
  if (known != null) return known;
  final s = key.replaceAll('_', ' ');
  return s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
