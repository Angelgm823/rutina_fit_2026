import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart' show SfCartesianChart, LineSeries, ColumnSeries, DateTimeAxis, NumericAxis, AxisTitle, AxisLine, MajorGridLines, MarkerSettings, TooltipBehavior;
import 'package:rutina_fit/database/db.dart';
import 'package:rutina_fit/models/exercises.dart';
import 'package:rutina_fit/theme/app_theme.dart';

class Progress extends StatefulWidget {
  const Progress({super.key});
  @override
  State<Progress> createState() => _ProgressState();
}

class _ProgressState extends State<Progress> {
  final names = <String>{for (final l in routines.values) for (final e in l) e.name}.toList();
  late String ex = names.first;

  Widget _chart(List<Pt>? d, {required bool line, required String unit}) {
    if (d == null) {
      return const SizedBox(height: 240, child: Center(child: CircularProgressIndicator()));
    }
    if (d.isEmpty) {
      return const SizedBox(height: 240, child: Center(child: Text('Sin datos todavía.')));
    }
    const label = TextStyle(color: cSlate);
    return SizedBox(
      height: 260,
      child: SfCartesianChart(
        plotAreaBorderWidth: 0,
        tooltipBehavior: TooltipBehavior(enable: true),
        primaryXAxis: DateTimeAxis(
          labelStyle: label,
          axisLine: const AxisLine(color: cSteel),
          majorGridLines: const MajorGridLines(width: 0),
        ),
        primaryYAxis: NumericAxis(
          labelStyle: label,
          title: AxisTitle(text: unit, textStyle: label),
          axisLine: const AxisLine(width: 0),
          majorGridLines: const MajorGridLines(color: cSteel, width: 0.5),
        ),
        series: [
          if (line)
            LineSeries<Pt, DateTime>(
              dataSource: d,
              xValueMapper: (pt, _) => pt.x,
              yValueMapper: (pt, _) => pt.y,
              color: cMist,
              width: 3,
              markerSettings: const MarkerSettings(isVisible: true, height: 8, width: 8, color: cMist),
            )
          else
            ColumnSeries<Pt, DateTime>(
              dataSource: d,
              xValueMapper: (pt, _) => pt.x,
              yValueMapper: (pt, _) => pt.y,
              color: cSlate,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext c) {
    final t = Theme.of(c).textTheme;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('Peso máximo por sesión', style: t.titleMedium),
      DropdownButton<String>(
        isExpanded: true,
        value: ex,
        dropdownColor: cNight,
        items: [for (final n in names) DropdownMenuItem(value: n, child: Text(n))],
        onChanged: (v) => setState(() => ex = v ?? ex),
      ),
      FutureBuilder<List<Pt>>(
        future: Db.weightSeries(ex),
        builder: (c, s) => _chart(s.data, line: true, unit: 'kg'),
      ),
      const SizedBox(height: 24),
      Text('Bicicleta: minutos por sesión', style: t.titleMedium),
      const SizedBox(height: 8),
      FutureBuilder<List<Pt>>(
        future: Db.bikeSeries(),
        builder: (c, s) => _chart(s.data, line: false, unit: 'min'),
      ),
    ]);
  }
}