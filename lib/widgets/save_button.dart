import 'package:flutter/material.dart';
import 'package:rutina_fit/theme/app_theme.dart';

/// Botón de guardar: gris mientras falta algo, verde cuando ya se puede guardar.
class SaveButton extends StatelessWidget {
  final VoidCallback? onPressed; // null = desactivado
  final String label;
  final bool expand;
  const SaveButton({super.key, required this.onPressed, this.label = 'Guardar', this.expand = false});

  @override
  Widget build(BuildContext c) {
    final b = FilledButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.save),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: cGo,
        foregroundColor: Colors.white,
        disabledBackgroundColor: cSteel,
        disabledForegroundColor: cSlate,
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: b) : b;
  }
}
