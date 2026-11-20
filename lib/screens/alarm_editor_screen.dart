import 'package:flutter/material.dart';
import 'package:rutina_fit/database/db.dart';
import 'package:rutina_fit/services/exercise_alarms.dart';
import 'package:rutina_fit/widgets/save_button.dart';

const _diaLabels = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

class AlarmEditor extends StatefulWidget {
  final int? id;
  final String routineName;
  final int routineId;
  final String? alarmTime;
  final String? daysRaw;

  const AlarmEditor({
    super.key,
    this.id,
    required this.routineName,
    required this.routineId,
    this.alarmTime,
    this.daysRaw,
  });

  @override
  State<AlarmEditor> createState() => _AlarmEditorState();
}

class _AlarmEditorState extends State<AlarmEditor> {
  late TimeOfDay _time;
  Set<int> days = {};
  bool loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.alarmTime != null) {
      final parts = widget.alarmTime!.split(':');
      _time = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } else {
      _time = TimeOfDay.now();
    }
    days = Db.parseDays(widget.daysRaw).toSet();
  }

  void _toggleDay(int d, bool on) => setState(() {
    if (on) {
      days.add(d);
    } else {
      days.remove(d);
    }
  });

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
    );
    if (picked != null) {
      setState(() => _time = picked);
    }
  }

  Future<void> _save() async {
    final msg = ScaffoldMessenger.of(context);
    setState(() => loading = true);

    try {
      final alarmTime = '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';
      String? daysStr;
      if (days.isNotEmpty) {
        final daysList = days.toList()..sort();
        daysStr = daysList.join(',');
      }

      if (widget.id == null) {
        final id = await Db.createAlarm(widget.routineId, widget.routineName, alarmTime, daysStr);
        await ExerciseAlarms.scheduleAlarm(id, alarmTime, widget.routineName);
      } else {
        await Db.updateAlarm(widget.id!, alarmTime, daysStr);
        await ExerciseAlarms.cancelAlarm(widget.id!);
        await ExerciseAlarms.scheduleAlarm(widget.id!, alarmTime, widget.routineName);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      msg.showSnackBar(
        SnackBar(content: Text('No se pudo guardar la alarma: $e')),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(
      title: Text(widget.id == null ? 'Nueva alarma' : 'Editar alarma'),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: SaveButton(onPressed: loading ? null : _save),
        ),
      ],
    ),
    body: SafeArea(
      bottom: false,
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Rutina: ${widget.routineName}', style: Theme.of(c).textTheme.bodyMedium),
                          const SizedBox(height: 16),
                          const Text('Hora de la alarma', style: TextStyle(fontSize: 12)),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: _pickTime,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(color: Theme.of(c).dividerColor),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _time.format(c),
                                    style: Theme.of(c).textTheme.headlineSmall,
                                  ),
                                  const Icon(Icons.access_time),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text('Días de la semana (opcional)', style: TextStyle(fontSize: 12)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (var i = 0; i < _diaLabels.length; i++)
                                FilterChip(
                                  label: Text(_diaLabels[i]),
                                  showCheckmark: false,
                                  selected: days.contains(i + 1),
                                  onSelected: (v) => _toggleDay(i + 1, v),
                                ),
                            ],
                          ),
                          if (days.isNotEmpty)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text(
                                'La alarma se repetirá solo en estos días.',
                                style: TextStyle(fontSize: 11),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Notificaciones programadas:', style: TextStyle(fontSize: 12)),
                      const SizedBox(height: 8),
                      _NotificationInfo(time: _time, label: '30 minutos antes', message: 'Prepara esos musculos que es hora de entrenar'),
                      const SizedBox(height: 8),
                      _NotificationInfo(time: _time, label: '5 minutos después', message: 'El ejercicio de hoy no se va a hacer solo'),
                    ],
                  ),
                ),
              ],
            ),
    ),
  );
}

class _NotificationInfo extends StatelessWidget {
  final TimeOfDay time;
  final String label;
  final String message;

  const _NotificationInfo({
    required this.time,
    required this.label,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final hour = time.hour;
    final minute = time.minute;

    DateTime notifyTime;
    if (label.contains('30 minutos antes')) {
      notifyTime = DateTime.now().copyWith(hour: hour, minute: minute - 30);
      if (notifyTime.minute < 0) {
        notifyTime = notifyTime.subtract(const Duration(hours: 1)).copyWith(minute: notifyTime.minute + 60);
      }
    } else {
      notifyTime = DateTime.now().copyWith(hour: hour, minute: minute + 5);
      if (notifyTime.minute >= 60) {
        notifyTime = notifyTime.add(const Duration(hours: 1)).copyWith(minute: notifyTime.minute - 60);
      }
    }

    final timeStr = '${notifyTime.hour.toString().padLeft(2, '0')}:${notifyTime.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          Text('a las $timeStr', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 4),
          Text('💬 "$message"', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }
}
