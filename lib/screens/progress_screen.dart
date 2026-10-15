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
import 'package:rutina_fit/controllers/progress_controller.dart';
import 'package:rutina_fit/database/db.dart';
import 'package:rutina_fit/theme/app_theme.dart';
import 'package:rutina_fit/utils/format.dart';

class Progress extends StatefulWidget {
  const Progress({super.key});
  @override
  State<Progress> createState() => _ProgressState();
}

class _ProgressState extends State<Progress> {
  final ctrl = ProgressController();

  @override
  void initState() {
    super.initState();
    ctrl.load();
  }

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  String _n1(double v) => fmt(double.parse(v.toStringAsFixed(1)));

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
    final shown = ProgressController.lastSessions(d);
    final labels = ProgressController.labels(shown);
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
              text: shown.length < d.length
                  ? '${ctrl.period} · últimas ${ProgressController.maxSessions} sesiones'
                  : ctrl.period,
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
    final st = Stats.of(d);
    return _section(Icons.fitness_center, 'Fuerza: ejercicios por sesión', 'Ejercicios con al menos una serie hecha', [
      _chart(
        d,
        line: false,
        unit: 'ejercicios',
        color: cAccent,
        label: (v) => fmt(v),
        interval: 1,
        stats: [
          _stat('${st.sessions}', 'Sesiones'),
          _stat(fmt(st.total), 'Ejercicios'),
          _stat(_n1(st.average), 'Por sesión'),
        ],
      ),
    ]);
  }

  /// Cardio: minutos por sesión.
  Widget _cardioSection(List<Pt> d) {
    final st = Stats.of(d);
    return _section(Icons.directions_bike, 'Cardio: minutos por sesión', 'Bicicleta, caminadora y otros', [
      _chart(
        d,
        line: false,
        unit: 'min',
        color: cMist.withValues(alpha: 0.7),
        label: (v) => _n1(v),
        stats: [
          _stat('${st.sessions}', 'Sesiones'),
          _stat('${_n1(st.total)} min', 'Total'),
          _stat('${_n1(st.average)} min', 'Promedio'),
        ],
      ),
    ]);
  }

  @override
  Widget build(BuildContext c) => ListenableBuilder(listenable: ctrl, builder: _build);

  Widget _build(BuildContext c, Widget? _) {
    if (!ctrl.loaded) return const Center(child: CircularProgressIndicator());
    final t = Theme.of(c).textTheme;
    if (ctrl.isEmpty) {
      return RefreshIndicator(
        onRefresh: ctrl.load,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: const [
            SizedBox(height: 120),
            Text('Guarda una sesión para ver tu progreso.', textAlign: TextAlign.center),
          ],
        ),
      );
    }

    final s = ctrl.strengthInPeriod;
    final cc = ctrl.cardioInPeriod;

    return RefreshIndicator(
      onRefresh: ctrl.load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(onPressed: ctrl.prevYear, icon: const Icon(Icons.chevron_left)),
              Text('${ctrl.year}', style: t.titleLarge),
              IconButton(
                onPressed: ctrl.canNextYear ? ctrl.nextYear : null,
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
            selected: {ctrl.quarter},
            onSelectionChanged: (v) => ctrl.setQuarter(v.first),
          ),
          if (s.isEmpty && cc.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 80),
              child: Text('Sin entrenamientos en ${ctrl.period}.', textAlign: TextAlign.center, style: TextStyle(color: cSlate)),
            ),
          if (s.isNotEmpty) _strengthSection(s),
          if (cc.isNotEmpty) _cardioSection(cc),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
