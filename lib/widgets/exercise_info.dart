import 'package:flutter/material.dart';
import 'package:rutina_fit/models/exercises.dart';
import 'package:rutina_fit/theme/app_theme.dart';

/// Botón "i" que abre la ficha del ejercicio (grupo, equipo y cómo se hace).
class ExerciseInfoButton extends StatelessWidget {
  final Ex ex;
  const ExerciseInfoButton(this.ex, {super.key});

  @override
  Widget build(BuildContext context) => IconButton(
        icon: const Icon(Icons.info_outline),
        tooltip: 'Cómo se hace',
        onPressed: () => showExerciseInfo(context, ex),
      );
}

void showExerciseInfo(BuildContext context, Ex ex) {
  showDialog(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(ex.name),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Wrap(spacing: 8, runSpacing: 4, alignment: WrapAlignment.center, children: [
            if (ex.sub.isNotEmpty) Chip(label: Text(ex.sub), visualDensity: VisualDensity.compact),
            if (ex.equipment.isNotEmpty) Chip(label: Text(ex.equipment), visualDensity: VisualDensity.compact),
            if (ex.category != 'Cardio') Chip(label: Text('${ex.reps} ${ex.unit}'), visualDensity: VisualDensity.compact),
          ]),
          const SizedBox(height: 20),
          Text('Instrucciones', style: Theme.of(c).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(
            ex.descr.isEmpty ? 'Este ejercicio todavía no tiene descripción.' : ex.descr,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: ex.descr.isEmpty ? cSlate : null,
            ),
          ),
        ]),
      ),
      actions: [
        FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Entendido')),
      ],
    ),
  );
}