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
  bool loaded = false;

  List<Pt> strength = []; // ejercicios hechos por sesión
  List<Pt> cardio = []; // minutos de cardio por sesión

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Carga (o recarga al arrastrar hacia abajo) las gráficas.
  Future<void> _load() async {
    final s = await Db.strengthSeries();
    final b = await Db.bikeSeries();
    if (!mounted) return;
    setState(() {
      strength = s;
      cardio = b;
      loaded = true;
    });
  }

  // Periodo: año + trimestre (0 = año completo). Por defecto, el trimestre actual.
  int year = DateTime.now().year;
  int quarter = (DateTime.now().month - 1) ~/ 3 + 1;

  static const _qNames = ['Año completo', 'T1 · Ene–Mar', 'T2 · Abr–Jun', 'T3 · Jul–Sep', 'T4 · Oct–Dic'];
  String get period => quarter == 0 ? 'Año $year' : '${_qNames[quarter]} $year';

  List<Pt> _inPeriod(List<Pt> all) =>
      all.where((pt) => pt.x.year == year && (quarter == 0 || (pt.x.month - 1) ~/ 3 + 1 == quarter)).toList();

  String _n1(double v) => fmt(double.parse(v.toStringAsFixed(1)));

  /// Una etiqueta por sesión: "29/9" (con hora si hay dos el mismo día).
  List<String> _labels(List<Pt> d) {
    String base(Pt pt) => '${pt.x.day}/${pt.x.month}';
    String two(int n) => n.toString().padLeft(2, '0');
    final count = <String, int>{};
    for (final pt in d) {
      count[base(pt)] = (count[base(pt)] ?? 0) + 1;
    }
    return [for (final pt in d) count[base(pt)]! > 1 ? '${base(pt)} ${two(pt.x.hour)}:${two(pt.x.minute)}' : base(pt)];
  }

  Widget _stat(String value, String caption) => Expanded(
        child: Column(
          children: [
            Text(value, style: Theme.of(context).textTheme.titleMedium),
            Text(caption, style: TextStyle(color: cSlate, fontSize: 12)),
          ],
        ),
      );

  /// Tarjeta que separa cada sección de la pantalla.
  Widget _section(IconData icon, String title, String subtitle, List<Widget> children) => Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
        decoration: BoxDecoration(
          color: cNight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cSteel.withValues(alpha: 0.6)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 20, color: cAccent),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
          ]),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(color: cSlate, fontSize: 12)),
          const SizedBox(height: 12),
          ...children,
        ]),
      );

  /// Gráfica de un periodo con datos (d no vacía).
  Widget _chart(
    List<Pt> d, {
    required bool line,
    required String unit,
    required List<Widget> stats,
    required Color color,
    required String Function(double) label,
    double? max,
    double? interval,
  }) {
    final shown = d.length > _maxSessions ? d.sublist(d.length - _maxSessions) : d;
    final labels = _labels(shown);
    final top = shown.map((pt) => pt.y).reduce((a, b) => a > b ? a : b);
    final axisText = TextStyle(color: cSlate);
    final dataLabels = DataLabelSettings(
      isVisible: shown.length <= 12, // con muchas sesiones las etiquetas se enciman
      textStyle: TextStyle(color: cMist, fontSize: 11),
    );

    return Column(
      children: [
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
              axisLine: AxisLine(color: cSteel),
              majorGridLines: const MajorGridLines(width: 0),
            ),
            primaryYAxis: NumericAxis(
              minimum: 0,
              maximum: max ?? (top * 1.25).ceilToDouble(),
              interval: interval,
              labelStyle: axisText,
              title: AxisTitle(text: unit, textStyle: axisText),
              axisLine: const AxisLine(width: 0),
              majorGridLines: MajorGridLines(color: cSteel, width: 0.5),
            ),
            series: [
              if (line)
                LineSeries<Pt, String>(
                  dataSource: shown,
                  xValueMapper: (pt, i) => labels[i],
                  yValueMapper: (pt, _) => pt.y,
                  dataLabelMapper: (pt, _) => label(pt.y),
                  dataLabelSettings: dataLabels,
                  color: color,
                  width: 3,
                  markerSettings: MarkerSettings(isVisible: true, height: 8, width: 8, color: color),
                )
              else
                ColumnSeries<Pt, String>(
                  dataSource: shown,
                  xValueMapper: (pt, i) => labels[i],
                  yValueMapper: (pt, _) => pt.y,
                  dataLabelMapper: (pt, _) => label(pt.y),
                  dataLabelSettings: dataLabels,
                  color: color,
                  width: 0.4,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Fuerza: ejercicios hechos por sesión.
  Widget _strengthSection(List<Pt> d) {
    final total = d.fold<double>(0, (s, pt) => s + pt.y);
    return _section(Icons.fitness_center, 'Fuerza: ejercicios por sesión', 'Ejercicios con al menos una serie hecha', [
      _chart(
        d,
        line: false,
        unit: 'ejercicios',
        color: cAccent,
        label: (v) => fmt(v),
        interval: 1,
        stats: [
          _stat('${d.length}', 'Sesiones'),
          _stat(fmt(total), 'Ejercicios'),
          _stat(_n1(total / d.length), 'Por sesión'),
        ],
      ),
    ]);
  }

  /// Cardio: minutos por sesión.
  Widget _cardioSection(List<Pt> d) {
    final total = d.fold<double>(0, (s, pt) => s + pt.y);
    return _section(Icons.directions_bike, 'Cardio: minutos por sesión', 'Bicicleta, caminadora y otros', [
      _chart(
        d,
        line: false,
        unit: 'min',
        color: cMist.withValues(alpha: 0.7),
        label: (v) => _n1(v),
        stats: [
          _stat('${d.length}', 'Sesiones'),
          _stat('${_n1(total)} min', 'Total'),
          _stat('${_n1(total / d.length)} min', 'Promedio'),
        ],
      ),
    ]);
  }

  @override
  Widget build(BuildContext c) {
    if (!loaded) return const Center(child: CircularProgressIndicator());
    final t = Theme.of(c).textTheme;
    if (strength.isEmpty && cardio.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: const [
            SizedBox(height: 120),
            Text('Guarda una sesión para ver tu progreso.', textAlign: TextAlign.center),
          ],
        ),
      );
    }

    // Solo se muestran las gráficas que tienen datos en el periodo elegido.
    final s = _inPeriod(strength);
    final cc = _inPeriod(cardio);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(onPressed: () => setState(() => year--), icon: const Icon(Icons.chevron_left)),
              Text('$year', style: t.titleLarge),
              IconButton(
                onPressed: year >= DateTime.now().year ? null : () => setState(() => year++),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
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
          if (s.isEmpty && cc.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 80),
              child: Text('Sin entrenamientos en $period.', textAlign: TextAlign.center, style: TextStyle(color: cSlate)),
            ),
          if (s.isNotEmpty) _strengthSection(s),
          if (cc.isNotEmpty) _cardioSection(cc),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
