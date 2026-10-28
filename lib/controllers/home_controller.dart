import 'package:flutter/foundation.dart';
import 'package:rutina_fit/services/service.dart';

/// Estado y lógica de la pantalla de inicio: pestaña activa, exportar e importar.
/// No conoce widgets: devuelve el mensaje a mostrar y la vista decide cómo.
class HomeController extends ChangeNotifier {
  int tab = 0;
  int gen = 0; // cambia tras importar un respaldo para recargar las pantallas

  static const titles = ['Entrenar', 'Historial', 'Progreso', 'Tops'];
  String get title => titles[tab];
  bool get canDownload => tab == 1;

  void selectTab(int i) {
    if (i == tab) return;
    tab = i;
    notifyListeners();
  }

  /// Devuelve el mensaje para mostrar, o null si el usuario canceló.
  Future<String?> exportReport(String kind) async {
    try {
      final report = await buildReport();
      if (report.isEmpty) return 'Aún no hay sesiones para exportar.';
      final name = kind == 'pdf' ? await exportPdf(report) : await exportImage(report);
      return name == null ? null : 'Guardado: $name';
    } catch (e) {
      return 'No se pudo exportar: $e';
    }
  }

  Future<String?> exportBackupFile() async {
    try {
      final name = await exportBackup();
      return name == null ? null : 'Respaldo guardado: $name';
    } catch (e) {
      return 'Error con el respaldo: $e';
    }
  }

  Future<String?> importBackupFile() async {
    try {
      final res = await importBackup();
      if (res == null) return null;
      final (gym, bike, routines) = res;
      gen++;
      notifyListeners();
      return 'Respaldo importado: $gym sesiones de fuerza, $bike de cardio y $routines rutinas.';
    } catch (e) {
      return e is FormatException ? e.message : 'Error con el respaldo: $e';
    }
  }
}
