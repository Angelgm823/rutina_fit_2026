import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart'
    show
        SfCartesianChart,
        LineSeries,
        ColumnSeries,
        StackedColumnSeries,
        CategoryAxis,
        NumericAxis,
        AxisTitle,
        AxisLine,
        MajorGridLines,
        MarkerSettings,
        TooltipBehavior,
        ChartTitle,
        ChartAlignment,
        DataLabelSettings,
        Legend,
        LegendPosition,
        LegendItemOverflowMode;
import 'package:rutina_fit/controllers/progress_controller.dart';
import 'package:rutina_fit/database/db.dart';
import 'package:rutina_fit/theme/app_theme.dart';
import 'package:rutina_fit/utils/format.dart';

/// Paleta categórica para dividir la barra de fuerza por ejercicio (validada para
/// buen contraste entre colores adyacentes, también para daltonismo). "Otros" usa
/// el gris del tema en vez de un color de la paleta.
const _catPaletteDark = [
  Color(0xFF3987E5), // azul
  Color(0xFFD95926), // naranja
  Color(0xFF199E70), // aguamarina
  Color(0xFFC98500), // amarillo
  Color(0xFFD55181), // magenta
  Color(0xFF008300), // verde
  Color(0xFF9085E9), // violeta
];
const _catPaletteLight = [
  Color(0xFF2A78D6),
  Color(0xFFEB6834),
  Color(0xFF1BAF7A),
  Color(0xFFEDA100),
  Color(0xFFE87BA4),
  Color(0xFF008300),
  Color(0xFF6250D6),
];

/// Rampa secuencial (un solo tono, claro→oscuro) para codificar magnitud: menos
/// tiempo = más claro, más tiempo = más oscuro. Los dos tonos están dentro del
/// rango que mantiene buen contraste tanto en temas claros como oscuros.
const _seqLow = Color(0xFF86B6EF); // menos minutos
const _seqHigh = Color(0xFF184F95); // más minutos

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
    bool sequential = false, // colorea cada barra según su magnitud (menos→más)
  }) {
    final shown = ProgressController.lastSessions(d);
    final labels = ProgressController.labels(shown);
    final top = shown.map((pt) => pt.y).reduce((a, b) => a > b ? a : b);
    final axisText = TextStyle(color: cSlate);
    final dataLabels = DataLabelSettings(
      isVisible: shown.length <= 12, // con muchas sesiones las etiquetas se enciman
      textStyle: TextStyle(color: cMist, fontSize: 11),
    );
    final minV = shown.map((p) => p.y).reduce((a, b) => a < b ? a : b);
    final maxV = top;
    Color seqColor(double v) => Color.lerp(_seqLow, _seqHigh, maxV == minV ? 1 : (v - minV) / (maxV - minV))!;

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
                  pointColorMapper: sequential ? (pt, _) => seqColor(pt.y) : null,
                  width: 0.4,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Fuerza: repeticiones hechas por sesión, divididas por ejercicio.
  Widget _strengthSection(List<Pt> d) {
    final st = Stats.of(d);
    return _section(Icons.fitness_center, 'Fuerza: repeticiones por sesión', 'Repeticiones por ejercicio en cada sesión', [
      Row(children: [
        _stat('${st.sessions}', 'Sesiones'),
        _stat(fmt(st.total), 'Repeticiones'),
        _stat(_n1(st.average), 'Por sesión'),
      ]),
      _strengthChart(d),
    ]);
  }

  /// Barras apiladas: repeticiones por sesión, una franja de color por ejercicio.
  Widget _strengthChart(List<Pt> d) {
    final shown = ProgressController.lastSessions(d);
    final labels = ProgressController.labels(shown);
    final top = shown.map((pt) => pt.y).reduce((a, b) => a > b ? a : b);
    final axisText = TextStyle(color: cSlate);
    final categories = ctrl.strengthCategories;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final palette = dark ? _catPaletteDark : _catPaletteLight;
    Color colorOf(int i, String cat) => cat == otrosCategoria ? cSlate : palette[i % palette.length];

    return SizedBox(
      height: 290,
      child: SfCartesianChart(
        plotAreaBorderWidth: 0,
        title: ChartTitle(
          text: shown.length < d.length
              ? '${ctrl.period} · últimas ${ProgressController.maxSessions} sesiones'
              : ctrl.period,
          textStyle: axisText,
          alignment: ChartAlignment.near,
        ),
        legend: Legend(
          isVisible: categories.length > 1,
          position: LegendPosition.bottom,
          overflowMode: LegendItemOverflowMode.wrap,
          textStyle: TextStyle(color: cMist, fontSize: 11),
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
          maximum: (top * 1.25).ceilToDouble(),
          labelStyle: axisText,
          title: AxisTitle(text: 'repeticiones', textStyle: axisText),
          axisLine: const AxisLine(width: 0),
          majorGridLines: MajorGridLines(color: cSteel, width: 0.5),
        ),
        series: [
          for (var i = 0; i < categories.length; i++)
            StackedColumnSeries<Pt, String>(
              dataSource: shown,
              xValueMapper: (pt, idx) => labels[idx],
              yValueMapper: (pt, _) => ctrl.strengthDetail[pt.x]?[categories[i]] ?? 0,
              name: categories[i],
              color: colorOf(i, categories[i]),
              width: 0.6,
              borderColor: cNight,
              borderWidth: shown.length <= 12 ? 2 : 1,
            ),
        ],
      ),
    );
  }

  /// Cardio: minutos por sesión.
  Widget _cardioSection(List<Pt> d) {
    final st = Stats.of(d);
    return _section(Icons.directions_bike, 'Cardio: minutos por sesión', 'Bicicleta, caminadora y otros', [
      _chart(
        d,
        line: false,
        unit: 'min',
        color: _seqHigh,
        sequential: true,
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
