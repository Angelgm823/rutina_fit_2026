import 'package:flutter/material.dart';
import 'package:rutina_fit/database/db.dart';
import 'package:rutina_fit/models/exercises.dart';
import 'package:rutina_fit/utils/format.dart';

class History extends StatefulWidget {
  const History({super.key});
  @override
  State<History> createState() => _HistoryState();
}

class _HistoryState extends State<History> {
  late Future<List<Map<String, Object?>>> future = Db.timeline();

  Future<void> _reload() async {
    final f = Db.timeline();
    setState(() {
      future = f;
    });
    await f;
  }

  @override
  Widget build(BuildContext c) => FutureBuilder<List<Map<String, Object?>>>(
    future: future,
    builder: (c, s) {
      final rows = s.data ?? [];
      if (rows.isEmpty) {
        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            children: const [
              SizedBox(height: 200),
              Center(child: Text('Aún no hay sesiones. Marca tu primera serie.')),
            ],
          ),
        );
      }
      return RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          children: [
            for (final r in rows)
              r['type'] == 'bike'
                  ? ListTile(
                      leading: const Icon(Icons.directions_bike),
                      title: Text('${shortDate(r['date'] as String)} · ${r['exercise'] ?? 'Bicicleta estática'}'),
                      subtitle: Text(fmtMins(r['seconds'] as int)),
                    )
                  : ListTile(
                      leading: const Icon(Icons.fitness_center),
                      title: Text('${shortDate(r['date'] as String)} · ${r['routine']}'),
                      subtitle: Text('${r['done']} de ${r['total']} series completadas'),
                      onTap: () => showSessionDetail(c, r['date'] as String, r['routine'] as String),
                    ),
          ],
        ),
      );
    },
  );
}

Future<void> showSessionDetail(BuildContext c, String d, String r) async {
  final rows = (await Db.day(d, r)).where((x) => x['done'] == 1).toList();
  final exs = await Db.byName();
  if (!c.mounted) return;
  showModalBottomSheet(
    context: c,
    builder: (_) => ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final x in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              '${x['exercise']} · serie ${(x['set_no'] as int) + 1}: '
              '${_set(exs[x['exercise']], x)}',
            ),
          ),
      ],
    ),
  );
}

String _set(Ex? e, Map<String, Object?> x) => setText(
  e?.kind ?? kindOf(x['exercise'] as String, '', 'reps'),
  x['weight'] as num,
  x['reps'] as int,
  e?.unit ?? 'reps',
);
