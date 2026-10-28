import 'package:flutter/material.dart';
import 'package:rutina_fit/controllers/tops_controller.dart';
import 'package:rutina_fit/models/exercises.dart';
import 'package:rutina_fit/theme/app_theme.dart';
import 'package:rutina_fit/utils/format.dart';

class Tops extends StatefulWidget {
  const Tops({super.key});
  @override
  State<Tops> createState() => _TopsState();
}

class _TopsState extends State<Tops> {
  final ctrl = TopsController();

  @override
  void initState() {
    super.initState();
    ctrl.load();
  }

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  static const _medals = ['🥇', '🥈', '🥉'];
  String _rank(int i) => i < _medals.length ? _medals[i] : '${i + 1}.';

  Widget _row(int i, Widget middle, String trailing) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          SizedBox(width: 28, child: Text(_rank(i), style: const TextStyle(fontSize: 16))),
          Expanded(child: middle),
          Text(trailing, style: TextStyle(color: cSlate)),
        ]),
      );

  Widget _header(IconData icon, String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Icon(icon, size: 20, color: cAccent),
          const SizedBox(width: 8),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
        ]),
      );

  Widget _card(List<Widget> children) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
        decoration: BoxDecoration(
          color: cNight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cSteel.withValues(alpha: 0.6)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );

  Widget _cardioCard() => _card([
        _header(Icons.directions_bike, 'Top 3 · Cardio'),
        for (var i = 0; i < ctrl.cardio.length; i++)
          _row(i, Text('${ctrl.cardio[i].exercise} · ${shortDate(ctrl.cardio[i].date)}'), fmtMins(ctrl.cardio[i].seconds)),
      ]);

  Widget _weightCard((Ex, List<TopEntry>) group) {
    final (ex, entries) = group;
    return _card([
      Text(ex.name, style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 6),
      for (var i = 0; i < entries.length; i++)
        _row(i, Text(shortDate(entries[i].date)), setText(ex.kind, entries[i].weight, entries[i].reps, ex.unit)),
    ]);
  }

  @override
  Widget build(BuildContext c) => ListenableBuilder(
        listenable: ctrl,
        builder: (c, _) {
          if (!ctrl.loaded) return const Center(child: CircularProgressIndicator());
          if (ctrl.isEmpty) {
            return RefreshIndicator(
              onRefresh: ctrl.load,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: const [
                  SizedBox(height: 120),
                  Text('Guarda una sesión para ver tus mejores marcas.', textAlign: TextAlign.center),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: ctrl.load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (ctrl.cardio.isNotEmpty) _cardioCard(),
                if (ctrl.weights.isNotEmpty) _header(Icons.fitness_center, 'Top 3 · Peso por ejercicio'),
                for (final g in ctrl.weights) _weightCard(g),
              ],
            ),
          );
        },
      );
}
