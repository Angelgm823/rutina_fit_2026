import 'dart:async';
import 'package:flutter/material.dart';
import 'package:rutina_fit/database/db.dart';
import 'package:rutina_fit/widgets/day_picker.dart';
import 'package:rutina_fit/utils/format.dart';

class Bike extends StatefulWidget {
  final String name, descr;
  const Bike({super.key, this.name = 'Bicicleta estática', this.descr = ''});
  @override
  State<Bike> createState() => _BikeState();
}

class _BikeState extends State<Bike> {
  Duration acc = Duration.zero;
  DateTime? startedAt;
  Timer? ticker;
  final manual = TextEditingController();
  String date = dayKey(DateTime.now()); // puedes cambiarlo para registrar días pasados

  bool get running => startedAt != null;
  Duration get elapsed =>
      acc + (startedAt == null ? Duration.zero : DateTime.now().difference(startedAt!));

  String get clock {
    final s = elapsed.inSeconds;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  void _toggle() {
    if (running) {
      ticker?.cancel();
      setState(() {
        acc = elapsed;
        startedAt = null;
      });
    } else {
      startedAt = DateTime.now();
      ticker = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
      setState(() {});
    }
  }

  void _reset() {
    ticker?.cancel();
    manual.clear();
    setState(() {
      acc = Duration.zero;
      startedAt = null;
    });
  }

  Future<void> _save() async {
    var secs = elapsed.inSeconds;
    if (secs == 0) secs = (int.tryParse(manual.text) ?? 0) * 60;
    if (secs == 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Inicia el cronómetro o escribe los minutos.')));
      return;
    }
    final id = '$date ${DateTime.now().toIso8601String().substring(11, 19)}'; // día elegido + hora actual
    await Db.saveBike(id, secs, widget.name);
    if (!mounted) return;
    _reset();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('${widget.name}: ${fmtMins(secs)} guardados')));
  }

  @override
  void dispose() {
    ticker?.cancel();
    manual.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final theme = Theme.of(c);
    return Scaffold(
      appBar: AppBar(title: Text(widget.name, overflow: TextOverflow.ellipsis)),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        DayPicker(selected: date, onChanged: (d) => setState(() => date = d)),
        const SizedBox(height: 24),
        Center(child: Text(clock, style: theme.textTheme.displayLarge)),
        const SizedBox(height: 8),
        Center(
          child: Text(widget.descr.isEmpty ? 'Ritmo en el que puedas hablar sin ahogarte' : widget.descr,
              textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
        ),
        const SizedBox(height: 32),
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: _toggle,
              icon: Icon(running ? Icons.pause : Icons.play_arrow),
              label: Text(running ? 'Pausar' : (acc == Duration.zero ? 'Iniciar' : 'Continuar')),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(onPressed: _reset, child: const Text('Reiniciar')),
        ]),
        const SizedBox(height: 32),
        TextField(
          controller: manual,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Minutos (si no usaste el cronómetro)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.tonalIcon(
          onPressed: _save,
          icon: const Icon(Icons.save),
          label: const Text('Guardar sesión de cardio'),
        ),
      ]),
    );
  }
}