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

  Future<void> _openEditor(Map<String, Object?>? alarm) async {
    final alarmId = alarm?['id'] as int?;
    final routineId = alarm?['routine_id'] as int?;
    final routineName = alarm?['routine_name'] as String?;

    if (routineId == null || routineName == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AlarmEditor(
          id: alarmId,
          routineId: routineId,
          routineName: routineName,
          alarmTime: alarm?['alarm_time'] as String?,
          daysRaw: alarm?['days'] as String?,
        ),
      ),
    );
    if (mounted) _reload();
  }

  Future<void> _delete(int id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('¿Eliminar alarma de "$name"?'),
        content: const Text('No recibirás más notificaciones para esta rutina.'),
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
                    _AlarmCard(
                      alarm: alarm,
                      onEdit: () => _openEditor(alarm),
                      onDelete: () => _delete(alarm['id'] as int, alarm['routine_name'] as String),
                      onToggle: (enabled) => _toggleAlarm(alarm['id'] as int, enabled),
                    ),
                  const SizedBox(height: 4),
                  FilledButton.icon(
                    onPressed: () async {
                      final routines = await Db.routines();
                      if (mounted) {
                        final selected = await showDialog<Map<String, Object?>>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Selecciona una rutina'),
                            content: SizedBox(
                              width: double.maxFinite,
                              child: ListView(
                                shrinkWrap: true,
                                children: [
                                  for (final routine in routines)
                                    ListTile(
                                      title: Text(routine['name'] as String),
                                      onTap: () {
                                        Navigator.pop(context, routine);
                                      },
                                    ),
                                ],
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancelar'),
                              ),
                            ],
                          ),
                        );
                        if (selected != null && mounted) {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AlarmEditor(
                                routineId: selected['id'] as int,
                                routineName: selected['name'] as String,
                              ),
                            ),
                          );
                          if (mounted) _reload();
                        }
                      }
                    },
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
    final alarmTime = alarm['alarm_time'] as String;
    final routineName = alarm['routine_name'] as String;
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
          title: Text(routineName),
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
