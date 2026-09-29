import 'package:flutter/material.dart';
import 'package:rutina_fit/database/db.dart';
import 'package:rutina_fit/utils/format.dart';

class History extends StatelessWidget {
  const History({super.key});
  @override
  Widget build(BuildContext c) => FutureBuilder<List<Map<String, Object?>>>(
        future: Db.timeline(),
        builder: (c, s) {
          final rows = s.data ?? [];
          if (rows.isEmpty) {
            return const Center(child: Text('Aún no hay sesiones. Marca tu primera serie.'));
          }
          return ListView(children: [
            for (final r in rows)
              r['type'] == 'bike'
                  ? ListTile(
                      leading: const Icon(Icons.directions_bike),
                      title: Text('${shortDate(r['date'] as String)} · Bicicleta'),
                      subtitle: Text(fmtMins(r['seconds'] as int)),
                    )
                  : ListTile(
                      leading: const Icon(Icons.fitness_center),
                      title: Text('${shortDate(r['date'] as String)} · Rutina ${r['routine']}'),
                      subtitle: Text('${r['done']} de ${r['total']} series completadas'),
                      onTap: () => showSessionDetail(c, r['date'] as String, r['routine'] as String),
                    ),
          ]);
        },
      );
}


Future<void> showSessionDetail(BuildContext c, String d, String r) async {
  final rows = (await Db.day(d, r)).where((x) => x['done'] == 1).toList();
  if (!c.mounted) return;
  showModalBottomSheet(
    context: c,
    builder: (_) => ListView(padding: const EdgeInsets.all(16), children: [
      for (final x in rows)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text('${x['exercise']} · serie ${(x['set_no'] as int) + 1}: '
              '${fmt(x['weight'] as num)} kg × ${x['reps']}'),
        ),
    ]),
  );
}