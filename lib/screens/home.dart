import 'package:flutter/material.dart';
import 'package:rutina_fit/controllers/home_controller.dart';
import 'package:rutina_fit/screens/history_screen.dart';
import 'package:rutina_fit/screens/progress_screen.dart';
import 'package:rutina_fit/screens/routines.dart';
import 'package:rutina_fit/widgets/theme_picker.dart';

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final ctrl = HomeController();

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  /// Corre una acción del controller y muestra su mensaje.
  Future<void> _run(Future<String?> Function() action) async {
    final msg = ScaffoldMessenger.of(context);
    final text = await action();
    if (text != null) msg.showSnackBar(SnackBar(content: Text(text)));
  }

  void _onMenu(String v) => switch (v) {
        'theme' => showThemePicker(context),
        'export' => _run(ctrl.exportBackupFile),
        _ => _run(ctrl.importBackupFile),
      };

  @override
  Widget build(BuildContext c) => ListenableBuilder(
        listenable: ctrl,
        builder: (c, _) => Scaffold(
          appBar: AppBar(
            title: Text(ctrl.title),
            actions: [
              if (ctrl.canDownload)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.download),
                  tooltip: 'Descargar historial',
                  onSelected: (k) => _run(() => ctrl.exportReport(k)),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'pdf', child: Text('Descargar PDF')),
                    PopupMenuItem(value: 'img', child: Text('Descargar imagen')),
                  ],
                ),
              PopupMenuButton<String>(
                tooltip: 'Más opciones',
                onSelected: _onMenu,
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
            key: ValueKey(ctrl.gen),
            child: [const RoutinesScreen(), const History(), const Progress()][ctrl.tab],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: ctrl.tab,
            onDestinationSelected: ctrl.selectTab,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.fitness_center), label: 'Entrenar'),
              NavigationDestination(icon: Icon(Icons.history), label: 'Historial'),
              NavigationDestination(icon: Icon(Icons.show_chart), label: 'Progreso'),
            ],
          ),
        ),
      );
}
