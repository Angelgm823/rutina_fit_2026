import 'package:flutter_test/flutter_test.dart';
import 'package:rutina_fit/models/exercises.dart';

void main() {
  test('ejercicios con liga piden resistencia', () {
    for (final n in [
      'Aperturas con ligas de resistencia',
      'Remo horizontal con ligas de resistencia',
      'Extensión de tríceps con liga sobre la cabeza',
      'Paso lateral con mini-banda / liga de resistencia',
      'Crunch con resistencia de liga',
    ]) {
      expect(kindOf(n, 'Ligas de resistencia', 'reps'), Kind.band, reason: n);
      expect(kindOf(n, '', 'reps'), Kind.band, reason: n);
    }
    expect(kindOf('Plancha abdominal', 'Peso corporal', 'seg'), Kind.timed);
    expect(kindOf('Press de banca', 'Barra recta', 'reps'), Kind.weight);
  });
}
