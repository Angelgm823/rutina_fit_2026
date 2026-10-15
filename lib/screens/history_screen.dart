import 'package:flutter/material.dart';
import 'package:rutina_fit/controllers/history_controller.dart';

class History extends StatefulWidget {
  const History({super.key});
  @override
  State<History> createState() => _HistoryState();
}

class _HistoryState extends State<History> {
  final ctrl = HistoryController();

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

  Future<void> _showDetail(HistoryItem it) async {
    final lines = await ctrl.sessionDetail(it);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      builder: (_) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final l in lines)
            Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(l)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext c) => ListenableBuilder(
    listenable: ctrl,
    builder: (c, _) {
      if (!ctrl.loaded) return const Center(child: CircularProgressIndicator());
      return RefreshIndicator(
        onRefresh: ctrl.load,
        child: ListView(
          children: ctrl.items.isEmpty
              ? const [
                  SizedBox(height: 200),
                  Center(child: Text('Aún no hay sesiones. Marca tu primera serie.')),
                ]
              : [
                  for (final it in ctrl.items)
                    ListTile(
                      leading: Icon(it.cardio ? Icons.directions_bike : Icons.fitness_center),
                      title: Text(it.title),
                      subtitle: Text(it.subtitle),
                      onTap: it.cardio ? null : () => _showDetail(it),
                    ),
                ],
        ),
      );
    },
  );
}
