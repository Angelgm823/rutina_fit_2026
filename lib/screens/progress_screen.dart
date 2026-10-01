import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart'
    show
        SfCartesianChart,
        LineSeries,
        ColumnSeries,
        CategoryAxis,
        NumericAxis,
        AxisTitle,
        AxisLine,
        MajorGridLines,
        MarkerSettings,
        TooltipBehavior,
        ChartTitle,
        ChartAlignment,
        DataLabelSettings;
import 'package:rutina_fit/database/db.dart';
import 'package:rutina_fit/theme/app_theme.dart';
import 'package:rutina_fit/utils/format.dart';

const _maxSessions = 24; // sesiones visibles como máximo en cada gráfica

class Progress extends StatefulWidget {
  const Progress({super.key});
  @override
  State<Progress> createState() => _ProgressState();
}

class _ProgressState extends State<Progress> {
  List<String> names = [];
  String ex = '';

  @override
  void initState() {
    super.initState();
    Db.exercises().then((l) {
      if (!mounted) return;
      setState(() {
        names = [for (final e in l) e.name];
        ex = names.isEmpty ? '' : names.first;
      });
    });
  }

  // Periodo: año + trimestre (0 = año completo). Por defecto, el trimestre actual.
  int year = DateTime.now().year;
  int quarter = (DateTime.now().month - 1) ~/ 3 + 1;

  static const _qNames = ['Año completo', 'T1 · Ene–Mar', 'T2 · Abr–Jun', 'T3 · Jul–Sep', 'T4 · Oct–Dic'];
  String get period => quarter == 0 ? 'Año $year' : '${_qNames[quarter]} $year';

  String _n1(double v) => fmt(double.parse(v.toStringAsFixed(1)));

  /// Una etiqueta por sesión: "29/9" (con hora si hay dos el mismo día).
  List<String> _labels(List<Pt> d) {
    String base(Pt pt) => '${pt.x.day}/${pt.x.month}';
    String two(int n) => n.toString().padLeft(2, '0');
    final count = <String, int>{};
    for (final pt in d) {
      count[base(pt)] = (count[base(pt)] ?? 0) + 1;
    }
    return [
      for (final pt in d)
        count[base(pt)]! > 1 ? '${base(pt)} ${two(pt.x.hour)}:${two(pt.x.minute)}' : base(pt),
    ];
  }

  Widget _stat(String value, String caption) => Expanded(
        child: Column(children: [
          Text(value, style: Theme.of(context).textTheme.titleMedium),
          Text(caption, style: const TextStyle(color: cSlate, fontSize: 12)),
        ]),
      );

  Widget _block(List<Pt>? all, {required bool line, required String unit}) {
    if (all == null) {
      return const SizedBox(height: 240, child: Center(child: CircularProgressIndicator()));
    }
    final d = all
        .where((pt) => pt.x.year == year && (quarter == 0 || (pt.x.month - 1) ~/ 3 + 1 == quarter))
        .toList();
    if (d.isEmpty) {
      return SizedBox(height: 200, child: Center(child: Text('Sin datos en $period.')));
    }
    final shown = d.length > _maxSessions ? d.sublist(d.length - _maxSessions) : d;
    final labels = _labels(shown);
    final top = shown.map((pt) => pt.y).reduce((a, b) => a > b ? a : b);
    const axisText = TextStyle(color: cSlate);

    // Resumen encima de la gráfica
    final List<Widget> stats;
    if (line) {
      final best = d.map((pt) => pt.y).reduce((a, b) => a > b ? a : b);
      final change = d.last.y - d.first.y;
      stats = [
        _stat('${_n1(best)} kg', 'Mejor peso'),
        _stat('${change >= 0 ? '+' : ''}${_n1(change)} kg', 'Cambio'),
        _stat('${d.length}', 'Sesiones'),
      ];
    } else {
      final total = d.fold<double>(0, (s, pt) => s + pt.y);
      stats = [
        _stat('${d.length}', 'Sesiones'),
        _stat('${_n1(total)} min', 'Total'),
        _stat('${_n1(total / d.length)} min', 'Promedio'),
      ];
    }

    return Column(children: [
      Row(children: stats),
      SizedBox(
        height: 250,
        child: SfCartesianChart(
          plotAreaBorderWidth: 0,
          title: ChartTitle(
            text: shown.length < d.length ? '$period · últimas $_maxSessions sesiones' : period,
            textStyle: axisText,
            alignment: ChartAlignment.near,
          ),
          tooltipBehavior: TooltipBehavior(enable: true),
          primaryXAxis: CategoryAxis(
            labelStyle: axisText,
            labelRotation: shown.length > 5 ? -45 : 0,
            axisLine: const AxisLine(color: cSteel),
            majorGridLines: const MajorGridLines(width: 0),
          ),
          primaryYAxis: NumericAxis(
            minimum: 0,
            maximum: (top * 1.25).ceilToDouble(),
            labelStyle: axisText,
            title: AxisTitle(text: unit, textStyle: axisText),
            axisLine: const AxisLine(width: 0),
            majorGridLines: const MajorGridLines(color: cSteel, width: 0.5),
          ),
          series: [
            if (line)
              LineSeries<Pt, String>(
                dataSource: shown,
                xValueMapper: (pt, i) => labels[i],
                yValueMapper: (pt, _) => pt.y,
                dataLabelMapper: (pt, _) => fmt(pt.y),
                dataLabelSettings: const DataLabelSettings(isVisible: true, textStyle: TextStyle(color: cMist, fontSize: 11)),
                color: cMist,
                width: 3,
                markerSettings: const MarkerSettings(isVisible: true, height: 8, width: 8, color: cMist),
              )
            else
              ColumnSeries<Pt, String>(
                dataSource: shown,
                xValueMapper: (pt, i) => labels[i],
                yValueMapper: (pt, _) => pt.y,
                dataLabelMapper: (pt, _) => _n1(pt.y),
                dataLabelSettings: const DataLabelSettings(isVisible: true, textStyle: TextStyle(color: cMist, fontSize: 11)),
                color: cSlate,
                width: 0.4,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
          ],
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext c) {
    if (names.isEmpty) return const Center(child: CircularProgressIndicator());
    final t = Theme.of(c).textTheme;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton(onPressed: () => setState(() => year--), icon: const Icon(Icons.chevron_left)),
        Text('$year', style: t.titleLarge),
        IconButton(
          onPressed: year >= DateTime.now().year ? null : () => setState(() => year++),
          icon: const Icon(Icons.chevron_right),
        ),
      ]),
      SegmentedButton<int>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: 0, label: Text('Año')),
          ButtonSegment(value: 1, label: Text('T1')),
          ButtonSegment(value: 2, label: Text('T2')),
          ButtonSegment(value: 3, label: Text('T3')),
          ButtonSegment(value: 4, label: Text('T4')),
        ],
        selected: {quarter},
        onSelectionChanged: (v) => setState(() => quarter = v.first),
      ),
      const SizedBox(height: 20),
      Text('Peso máximo por sesión', style: t.titleMedium),
      DropdownButton<String>(
        isExpanded: true,
        value: ex,
        dropdownColor: cNight,
        items: [for (final n in names) DropdownMenuItem(value: n, child: Text(n))],
        onChanged: (v) => setState(() => ex = v ?? ex),
      ),
      const SizedBox(height: 8),
      FutureBuilder<List<Pt>>(
        future: Db.weightSeries(ex),
        builder: (c, s) => _block(s.data, line: true, unit: 'kg'),
      ),
      const SizedBox(height: 28),
      Text('Bicicleta: minutos por sesión', style: t.titleMedium),
      const SizedBox(height: 8),
      FutureBuilder<List<Pt>>(
        future: Db.bikeSeries(),
        builder: (c, s) => _block(s.data, line: false, unit: 'min'),
      ),
    ]);
  }
}