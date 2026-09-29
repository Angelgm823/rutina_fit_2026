import 'package:flutter/material.dart';
import 'package:rutina_fit/models/exercises.dart';
import 'package:rutina_fit/screens/bike_screen.dart';
import 'package:rutina_fit/screens/history_screen.dart';
import 'package:rutina_fit/screens/progress_screen.dart';
import 'package:rutina_fit/screens/workout_screen.dart';
import 'package:rutina_fit/services/service.dart';

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int tab = 0;

  Future<void> _export(String kind) async {
    final msg = ScaffoldMessenger.of(context);
    try {
      final report = await buildReport();
      if (report.isEmpty) {
        msg.showSnackBar(const SnackBar(content: Text('Aún no hay sesiones para exportar.')));
        return;
      }
      final name = kind == 'pdf' ? await exportPdf(report) : await exportImage(report);
      msg.showSnackBar(SnackBar(content: Text('Guardado en Descargas: $name')));
    } catch (e) {
      msg.showSnackBar(SnackBar(content: Text('No se pudo exportar: $e')));
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
          ],
        ),
        body: tab == 0
            ? ListView(padding: const EdgeInsets.all(16), children: [
                for (final k in routines.keys)
                  Card(
                    child: ListTile(
                      title: Text('Rutina $k'),
                      subtitle: Text('${routines[k]!.length} ejercicios · cuerpo completo'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => Workout(k))),
                    ),
                  ),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.directions_bike),
                    title: const Text('Bicicleta estática'),
                    subtitle: const Text('Solo cardio · cronómetro'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const Bike())),
                  ),
                ),
              ])
            : tab == 1
                ? const History()
                : const Progress(),
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