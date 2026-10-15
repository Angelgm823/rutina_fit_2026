import 'package:flutter/material.dart';
import 'package:rutina_fit/screens/history_screen.dart';
import 'package:rutina_fit/screens/progress_screen.dart';
import 'package:rutina_fit/screens/routines.dart';
import 'package:rutina_fit/services/service.dart';
import 'package:rutina_fit/widgets/theme_picker.dart';

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int tab = 0;
  int _gen = 0; // cambia tras importar un respaldo para recargar las pantallas

  Future<void> _export(String kind) async {
    final msg = ScaffoldMessenger.of(context);
    try {
      final report = await buildReport();
      if (report.isEmpty) {
        msg.showSnackBar(const SnackBar(content: Text('Aún no hay sesiones para exportar.')));
        return;
      }
      final name = kind == 'pdf' ? await exportPdf(report) : await exportImage(report);
      if (name == null) return;
      msg.showSnackBar(SnackBar(content: Text('Guardado: $name')));
    } catch (e) {
      msg.showSnackBar(SnackBar(content: Text('No se pudo exportar: $e')));
    }
  }

  Future<void> _backup(String action) async {
    final msg = ScaffoldMessenger.of(context);
    try {
      if (action == 'export') {
        final name = await exportBackup();
        if (name == null) return;
        msg.showSnackBar(SnackBar(content: Text('Respaldo guardado: $name')));
        return;
      }
      final res = await importBackup();
      if (res == null) return;
      final (gym, bike, routines) = res;
      setState(() => _gen++);
      msg.showSnackBar(SnackBar(
          content: Text('Respaldo importado: $gym sesiones de fuerza, $bike de cardio y $routines rutinas.')));
    } catch (e) {
      msg.showSnackBar(SnackBar(content: Text(e is FormatException ? e.message : 'Error con el respaldo: $e')));
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(
          title: Text(['Entrenar', 'Historial', 'Progreso'][tab]),
          actions: [
            if (tab == 1)
              PopupMenuButton<String>(
                icon: const Icon(Icons.download),
                tooltip: 'Descargar historial',
                onSelected: _export,
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'pdf', child: Text('Descargar PDF')),
                  PopupMenuItem(value: 'img', child: Text('Descargar imagen')),
                ],
              ),
            PopupMenuButton<String>(
              tooltip: 'Más opciones',
              onSelected: (v) => v == 'theme' ? showThemePicker(context) : _backup(v),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'theme',
                  child: ListTile(leading: Icon(Icons.palette_outlined), title: Text('Tema')),
                ),
                PopupMenuItem(
                  value: 'export',
                  child: ListTile(leading: Icon(Icons.save_alt), title: Text('Exportar respaldo')),
                ),
                PopupMenuItem(
                  value: 'import',
                  child: ListTile(leading: Icon(Icons.restore), title: Text('Importar respaldo')),
                ),
              ],
            ),
          ],
        ),
        body: KeyedSubtree(
          key: ValueKey(_gen),
          child: [const RoutinesScreen(), const History(), const Progress()][tab],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (i) => setState(() => tab = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.fitness_center), label: 'Entrenar'),
            NavigationDestination(icon: Icon(Icons.history), label: 'Historial'),
            NavigationDestination(icon: Icon(Icons.show_chart), label: 'Progreso'),
          ],
        ),
      );
}