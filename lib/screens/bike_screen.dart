import 'package:flutter/material.dart';
import 'package:rutina_fit/controllers/bike_controller.dart';
import 'package:rutina_fit/widgets/day_picker.dart';
import 'package:rutina_fit/utils/format.dart';
import 'package:rutina_fit/widgets/save_button.dart';

class Bike extends StatefulWidget {
  final String name, descr;
  const Bike({super.key, this.name = 'Bicicleta estática', this.descr = ''});
  @override
  State<Bike> createState() => _BikeState();
}

class _BikeState extends State<Bike> {
  late final ctrl = BikeController(widget.name);
  late final manual = TextEditingController(text: ctrl.manual);

  @override
  void initState() {
    super.initState();
    ctrl.addListener(_syncManual);
  }

  /// Al reiniciar o guardar, el controller vacía los minutos: el campo lo refleja.
  void _syncManual() {
    if (manual.text != ctrl.manual) manual.text = ctrl.manual;
  }

  /// Al salir con el cronómetro en marcha se perdería el tiempo: pregunta primero.
  Future<void> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('¿Salir sin guardar?'),
        content: Text('El cronómetro lleva ${ctrl.clock}. Si sales, se perderá ese tiempo.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Seguir')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Salir')),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.pop(context);
  }

  Future<void> _save() async {
    final msg = ScaffoldMessenger.of(context);
    final secs = await ctrl.save();
    if (secs > 0) msg.showSnackBar(SnackBar(content: Text('${widget.name}: ${fmtMins(secs)} guardados')));
  }

  @override
  void dispose() {
    ctrl.removeListener(_syncManual);
    ctrl.dispose();
    manual.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => ListenableBuilder(listenable: ctrl, builder: _build);

  Widget _build(BuildContext c, Widget? _) {
    final theme = Theme.of(c);
    return PopScope(
      canPop: ctrl.elapsed == Duration.zero,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(widget.name, overflow: TextOverflow.ellipsis)),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            DayPicker(selected: ctrl.date, onChanged: ctrl.setDate),
            const SizedBox(height: 24),
            Center(child: Text(ctrl.clock, style: theme.textTheme.displayLarge)),
            const SizedBox(height: 8),
            Center(
              child: Text(
                widget.descr.isEmpty ? 'Ritmo en el que puedas hablar sin ahogarte' : widget.descr,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final m in [0, 10, 20, 30, 45])
                  ChoiceChip(
                    label: Text(m == 0 ? 'Sin meta' : '$m min'),
                    showCheckmark: false,
                    selected: ctrl.goal == m,
                    onSelected: (_) => ctrl.setGoal(m),
                  ),
              ],
            ),
            if (ctrl.goal > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  ctrl.goalReached ? '¡Meta de ${ctrl.goal} min alcanzada!' : 'Te avisaremos al llegar a ${ctrl.goal} min',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: ctrl.toggle,
                    icon: Icon(ctrl.running ? Icons.pause : Icons.play_arrow),
                    label: Text(ctrl.running ? 'Pausar' : (ctrl.acc == Duration.zero ? 'Iniciar' : 'Continuar')),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(onPressed: ctrl.reset, child: const Text('Reiniciar')),
              ],
            ),
            const SizedBox(height: 32),
            TextField(
              controller: manual,
              onChanged: ctrl.setManual,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Minutos (si no usaste el cronómetro)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SaveButton(onPressed: ctrl.canSave ? _save : null, label: 'Guardar sesión de cardio', expand: true),
          ],
        ),
      ),
    );
  }
}
