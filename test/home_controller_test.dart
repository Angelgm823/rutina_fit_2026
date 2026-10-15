import 'package:flutter_test/flutter_test.dart';
import 'package:rutina_fit/controllers/home_controller.dart';

void main() {
  test('cambiar de pestaña actualiza título y botón de descarga', () {
    final c = HomeController();
    var notified = 0;
    c.addListener(() => notified++);

    expect(c.title, 'Entrenar');
    expect(c.canDownload, isFalse);

    c.selectTab(1);
    expect(c.title, 'Historial');
    expect(c.canDownload, isTrue);
    expect(notified, 1);

    c.selectTab(1); // misma pestaña: no redibuja
    expect(notified, 1);
  });
}
