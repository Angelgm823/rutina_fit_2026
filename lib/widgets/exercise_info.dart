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
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (c) => ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * 0.8),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(ex.name, style: Theme.of(c).textTheme.titleLarge),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 4, children: [
              if (ex.sub.isNotEmpty) Chip(label: Text(ex.sub), visualDensity: VisualDensity.compact),
              if (ex.equipment.isNotEmpty) Chip(label: Text(ex.equipment), visualDensity: VisualDensity.compact),
              if (ex.category != 'Cardio') Chip(label: Text('${ex.reps} ${ex.unit}'), visualDensity: VisualDensity.compact),
            ]),
            const SizedBox(height: 16),
            Text('Cómo se hace', style: Theme.of(c).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              ex.descr.isEmpty ? 'Este ejercicio todavía no tiene descripción.' : ex.descr,
              style: ex.descr.isEmpty ? const TextStyle(color: cSlate) : null,
            ),
          ]),
        ),
      ),
    ),
  );
}