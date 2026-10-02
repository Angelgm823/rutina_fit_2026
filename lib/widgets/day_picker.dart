import 'package:flutter/material.dart';
import 'package:rutina_fit/theme/app_theme.dart';

const _dias = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];

/// '2026-09-29'
String dayKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Fila de días (hoy y los anteriores) para elegir en qué fecha hiciste la sesión.
class DayPicker extends StatelessWidget {
  final String selected; // 'yyyy-MM-dd'
  final ValueChanged<String> onChanged;
  final int days;
  const DayPicker({super.key, required this.selected, required this.onChanged, this.days = 30});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final selDate = DateTime.tryParse(selected);
    final inList = selDate != null &&
        !selDate.isAfter(DateTime(now.year, now.month, now.day)) &&
        DateTime(now.year, now.month, now.day).difference(selDate).inDays < days;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(
        padding: EdgeInsets.only(left: 4, bottom: 4),
        child: Text('¿Qué día fue?', style: TextStyle(color: cSlate, fontSize: 12)),
      ),
      SizedBox(
        height: 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: days + 1 + (inList ? 0 : 1),
          separatorBuilder: (_, _) => const SizedBox(width: 6),
          itemBuilder: (c, i) {
            // Primer elemento extra cuando la fecha elegida no está en la lista
            if (!inList && i == 0 && selDate != null) {
              return ChoiceChip(
                label: Text('${selDate.day}/${selDate.month}/${selDate.year}'),
                selected: true,
                showCheckmark: false,
                onSelected: (_) {},
              );
            }
            final chipIndex = inList ? i : i - 1;
            // Último elemento: botón para abrir el calendario
            if (chipIndex == days) {
              return ActionChip(
                avatar: const Icon(Icons.calendar_month, size: 18),
                label: const Text('Calendario'),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selDate ?? now,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(now.year, now.month, now.day),
                  );
                  if (picked != null) onChanged(dayKey(picked));
                },
              );
            }
            final d = DateTime(now.year, now.month, now.day - chipIndex);
            final key = dayKey(d);
            final label = chipIndex == 0 ? 'Hoy' : (chipIndex == 1 ? 'Ayer' : '${_dias[d.weekday - 1]} ${d.day}');
            return ChoiceChip(
              label: Text(label),
              selected: key == selected,
              showCheckmark: false,
              onSelected: (_) => onChanged(key),
            );
          },
        ),
      ),
    ]);
  }
}