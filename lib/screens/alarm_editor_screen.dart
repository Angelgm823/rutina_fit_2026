import 'package:flutter/material.dart';
import 'package:rutina_fit/database/db.dart';
import 'package:rutina_fit/services/exercise_alarms.dart';
import 'package:rutina_fit/widgets/save_button.dart';

const _diaLabels = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

class AlarmEditor extends StatefulWidget {
  final int? id;
  final String? name;
  final String? alarmTime;
  final String? daysRaw;

  const AlarmEditor({
    super.key,
    this.id,
    this.name,
    this.alarmTime,
    this.daysRaw,
  });

  @override
  State<AlarmEditor> createState() => _AlarmEditorState();
}

class _AlarmEditorState extends State<AlarmEditor> {
  late final nameCtrl = TextEditingController(text: widget.name ?? '');
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
    nameCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    super.dispose();
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

  bool get canSave => !loading && nameCtrl.text.trim().isNotEmpty;

  Future<void> _save() async {
    final msg = ScaffoldMessenger.of(context);
    final name = nameCtrl.text.trim();
    if (name.isEmpty) {
      msg.showSnackBar(const SnackBar(content: Text('Ingresa un nombre para la alarma.')));
      return;
    }

    setState(() => loading = true);

    try {
      final alarmTime = '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';
      String? daysStr;
      if (days.isNotEmpty) {
        final daysList = days.toList()..sort();
        daysStr = daysList.join(',');
      }

      if (widget.id == null) {
        final id = await Db.createAlarm(name, alarmTime, daysStr);
        await ExerciseAlarms.scheduleAlarm(id, alarmTime, name);
      } else {
        await Db.updateAlarm(widget.id!, name, alarmTime, daysStr);
        await ExerciseAlarms.cancelAlarm(widget.id!);
        await ExerciseAlarms.scheduleAlarm(widget.id!, alarmTime, name);
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
          child: SaveButton(onPressed: canSave ? _save : null),
        ),
      ],
    ),
    body: SafeArea(
      bottom: false,
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: nameCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de la alarma (ej. Entrenar en casa)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                        _NotificationInfo(time: _time, label: '15 minutos antes', message: 'Casi es hora de hacer ejercicio preparate'),
                        const SizedBox(height: 8),
                        _NotificationInfo(
                          time: _time,
                          label: 'A la hora exacta',
                          message: 'Es hora de hacer ejercicio',
                          buttons: ['⏰ Posponer 5 min', '✕ Cancelar'],
                        ),
                        const SizedBox(height: 8),
                        _NotificationInfo(
                          time: _time,
                          label: '5 minutos después',
                          message: 'Vas tarde para hacer ejercicio',
                          buttons: ['⏰ Posponer 10 min'],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    ),
  );
}

class _NotificationInfo extends StatelessWidget {
  final TimeOfDay time;
  final String label;
  final String message;
  final List<String>? buttons;

  const _NotificationInfo({
    required this.time,
    required this.label,
    required this.message,
    this.buttons,
  });

  @override
  Widget build(BuildContext context) {
    final hour = time.hour;
    final minute = time.minute;

    DateTime notifyTime = DateTime.now().copyWith(hour: hour, minute: minute);

    if (label.contains('15 minutos antes')) {
      notifyTime = notifyTime.subtract(const Duration(minutes: 15));
    } else if (label.contains('exacta')) {
      // A la hora exacta, sin cambios
    } else if (label.contains('después')) {
      notifyTime = notifyTime.add(const Duration(minutes: 5));
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
          if (buttons != null && buttons!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final button in buttons!)
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withAlpha(30),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Theme.of(context).primaryColor.withAlpha(80),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      button,
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
