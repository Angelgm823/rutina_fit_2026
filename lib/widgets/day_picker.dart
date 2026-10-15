import 'package:flutter/material.dart';
import 'package:rutina_fit/theme/app_theme.dart';

const _dias = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
const _diasLargos = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
const _meses = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

/// '2026-09-29'
String dayKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime _today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

/// Semana (7 días) para elegir en qué fecha hiciste la sesión; las flechas
/// muestran semanas anteriores y el botón de calendario cualquier fecha.
class DayPicker extends StatefulWidget {
  final String selected; // 'yyyy-MM-dd'
  final ValueChanged<String> onChanged;
  const DayPicker({super.key, required this.selected, required this.onChanged});

  @override
  State<DayPicker> createState() => _DayPickerState();
}

class _DayPickerState extends State<DayPicker> {
  int page = 0; // 0 = los últimos 7 días (terminando hoy), 1 = la semana anterior...

  DateTime get _sel => DateTime.tryParse(widget.selected) ?? _today();

  int _pageOf(DateTime d) {
    final diff = _today().difference(d).inDays;
    return diff < 0 ? 0 : diff ~/ 7;
  }

  @override
  void initState() {
    super.initState();
    page = _pageOf(_sel);
  }

  @override
  void didUpdateWidget(DayPicker old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) page = _pageOf(_sel);
  }

  String _title(DateTime d) {
    final diff = _today().difference(d).inDays;
    final fecha = '${_diasLargos[d.weekday - 1]} ${d.day} de ${_meses[d.month - 1]}'
        '${d.year == _today().year ? '' : ' de ${d.year}'}';
    if (diff == 0) return 'Hoy · $fecha';
    if (diff == 1) return 'Ayer · $fecha';
    return fecha[0].toUpperCase() + fecha.substring(1);
  }

  Future<void> _calendar() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _sel,
      firstDate: DateTime(2020),
      lastDate: _today(),
      helpText: 'Fecha de la sesión',
    );
    if (picked != null) widget.onChanged(dayKey(picked));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = _today();
    final end = today.subtract(Duration(days: 7 * page));
    final days = [for (var i = 6; i >= 0; i--) DateTime(end.year, end.month, end.day - i)];

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cSteel.withValues(alpha: 0.6)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Fecha de la sesión', style: TextStyle(color: cSlate, fontSize: 12)),
              const SizedBox(height: 2),
              Text(_title(_sel),
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis),
            ]),
          ),
          IconButton(
            onPressed: _calendar,
            icon: const Icon(Icons.calendar_month),
            tooltip: 'Elegir otra fecha',
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          _arrow(Icons.chevron_left, () => setState(() => page++), 'Semana anterior'),
          for (final d in days) Expanded(child: _day(d, today)),
          _arrow(Icons.chevron_right, page == 0 ? null : () => setState(() => page--), 'Semana siguiente'),
        ]),
      ]),
    );
  }

  Widget _arrow(IconData icon, VoidCallback? onTap, String tip) => IconButton(
        onPressed: onTap,
        icon: Icon(icon),
        tooltip: tip,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 28, minHeight: 56),
      );

  Widget _day(DateTime d, DateTime today) {
    final key = dayKey(d);
    final selected = key == widget.selected;
    final isToday = d == today;
    final fg = selected ? cOnAccent : cMist;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: selected ? cAccent : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => widget.onChanged(key),
          child: SizedBox(
            height: 60,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(_dias[d.weekday - 1].toUpperCase(),
                  style: TextStyle(fontSize: 10, letterSpacing: 0.5, color: selected ? cOnAccent : cSlate)),
              const SizedBox(height: 2),
              Text('${d.day}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: fg)),
              const SizedBox(height: 3),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isToday ? (selected ? cOnAccent : cMist) : Colors.transparent,
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
