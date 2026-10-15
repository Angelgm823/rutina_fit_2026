import 'package:flutter/material.dart';
import 'package:rutina_fit/theme/app_theme.dart';

/// Hoja inferior para elegir el tema de colores.
Future<void> showThemePicker(BuildContext context) => showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const _ThemePicker(),
    );

class _ThemePicker extends StatelessWidget {
  const _ThemePicker();

  @override
  Widget build(BuildContext c) => ValueListenableBuilder<AppPalette>(
        valueListenable: themeNotifier,
        builder: (c, current, _) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Tema', style: Theme.of(c).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text('Elige los colores de la app.', style: TextStyle(color: cSlate)),
              const SizedBox(height: 12),
              _group('Oscuros'),
              for (final p in palettes.where((p) => !p.light)) _tile(p, p.id == current.id),
              const SizedBox(height: 8),
              _group('Claros'),
              for (final p in palettes.where((p) => p.light)) _tile(p, p.id == current.id),
            ]),
          ),
        ),
      );

  Widget _group(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 2),
        child: Text(title.toUpperCase(),
            style: TextStyle(color: cSlate, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
      );

  Widget _tile(AppPalette p, bool selected) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: p.night,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setTheme(p),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: selected ? p.accent : p.steel, width: selected ? 2 : 1),
              ),
              child: Row(children: [
                for (final col in [p.ink, p.steel, p.mist, p.accent])
                  Container(
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: col,
                      shape: BoxShape.circle,
                      border: Border.all(color: p.steel),
                    ),
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(p.name,
                      style: TextStyle(color: p.mist, fontSize: 16, fontWeight: FontWeight.w600)),
                ),
                if (selected) Icon(Icons.check_circle, color: p.accent),
              ]),
            ),
          ),
        ),
      );
}
