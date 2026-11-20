import 'package:flutter/material.dart';
import 'package:rutina_fit/database/db.dart';
import 'package:rutina_fit/screens/alarm_editor_screen.dart';
import 'package:rutina_fit/services/exercise_alarms.dart';

class AlarmsScreen extends StatefulWidget {
  const AlarmsScreen({super.key});

  @override
  State<AlarmsScreen> createState() => _AlarmsScreenState();
}

class _AlarmsScreenState extends State<AlarmsScreen> {
  late Future<List<Map<String, Object?>>> future = Db.getAlarms();

  void _reload() => setState(() {
    future = Db.getAlarms();
  });

  Future<void> _openEditor([Map<String, Object?>? alarm]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AlarmEditor(
          id: alarm?['id'] as int?,
          name: alarm?['name'] as String?,
          alarmTime: alarm?['alarm_time'] as String?,
          daysRaw: alarm?['days'] as String?,
        ),
      ),
    );
    if (mounted) _reload();
  }

  Future<void> _delete(int id, String alarmName) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('¿Eliminar alarma "$alarmName"?'),
        content: const Text('No recibirás más notificaciones de esta alarma.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Eliminar')),
        ],
      ),
    );

    if (ok == true) {
      await Db.deleteAlarm(id);
      await ExerciseAlarms.cancelAlarm(id);
      _reload();
    }
  }

  Future<void> _toggleAlarm(int id, bool enabled) async {
    await Db.toggleAlarm(id, enabled);
    if (enabled) {
      final alarm = await Db.getAlarm(id);
      if (alarm != null) {
        final alarmTime = alarm['alarm_time'] as String;
        final routineName = alarm['routine_name'] as String;
        await ExerciseAlarms.scheduleAlarm(id, alarmTime, routineName);
      }
    } else {
      await ExerciseAlarms.cancelAlarm(id);
    }
    _reload();
  }

  @override
  Widget build(BuildContext c) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alarmas de ejercicio'),
      ),
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<List<Map<String, Object?>>>(
          future: future,
          builder: (c, s) {
            final rows = s.data ?? [];
            return RefreshIndicator(
              onRefresh: () async {
                _reload();
                await future;
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (s.hasData && rows.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Aún no tienes alarmas. Crea la primera y recibirás notificaciones 30 minutos antes y 5 minutos después de tu hora de entrenamiento.'),
                      ),
                    ),
                  for (final alarm in rows)
                    if (alarm['id'] != null && alarm['name'] != null)
                      _AlarmCard(
                        alarm: alarm,
                        onEdit: () => _openEditor(alarm),
                        onDelete: () => _delete(alarm['id'] as int, alarm['name'] as String),
                        onToggle: (enabled) => _toggleAlarm(alarm['id'] as int, enabled),
                      ),
                  const SizedBox(height: 4),
                  FilledButton.icon(
                    onPressed: () => _openEditor(),
                    icon: const Icon(Icons.add),
                    label: const Text('Nueva alarma'),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AlarmCard extends StatelessWidget {
  final Map<String, Object?> alarm;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Function(bool) onToggle;

  const _AlarmCard({
    required this.alarm,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = (alarm['enabled'] as int?) ?? 1;
    final isEnabled = enabled == 1;
    final alarmTime = (alarm['alarm_time'] as String?) ?? '--:--';
    final alarmName = (alarm['name'] as String?) ?? 'Sin nombre';
    final daysStr = alarm['days'] as String?;
    final daysList = Db.parseDays(daysStr);

    final diaLabels = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    final daysDisplay = daysList.isEmpty
        ? 'Todos los días'
        : daysList.map((d) => diaLabels[d - 1]).join(', ');

    return Card(
      child: Opacity(
        opacity: isEnabled ? 1.0 : 0.6,
        child: ListTile(
          leading: Switch(
            value: isEnabled,
            onChanged: onToggle,
          ),
          title: Text(alarmName),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(alarmTime),
              Text(daysDisplay, style: const TextStyle(fontSize: 12)),
            ],
          ),
          trailing: PopupMenuButton<String>(
            onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Editar')),
              PopupMenuItem(value: 'delete', child: Text('Eliminar')),
            ],
          ),
        ),
      ),
    );
  }
}
