import 'dart:async';
import 'dart:io';
import 'dart:math' show max;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:syncfusion_flutter_charts/charts.dart'
    show
        SfCartesianChart,
        LineSeries,
        ColumnSeries,
        DateTimeAxis,
        NumericAxis,
        AxisTitle,
        AxisLine,
        MajorGridLines,
        MarkerSettings,
        TooltipBehavior;

// ---------- Datos de la rutina ----------
class Ex {
  final String name, reps, tip, unit;
  const Ex(this.name, this.reps, this.tip, {this.unit = 'reps'});
}

const baseSets = 2;

const routines = <String, List<Ex>>{
  'A': [
    Ex('Sentadilla con barra', '8–12', 'Muy ligero, prioriza técnica'),
    Ex('Press de pecho con mancuernas', '8–12', 'Puede ser en el suelo'),
    Ex('Remo con barra', '8–12', 'Barra hacia el abdomen'),
    Ex('Peso muerto rumano', '8–12', 'Espalda estable'),
    Ex('Press de hombros', '8–12', 'De pie o sentado'),
    Ex('Curl de bíceps', '10–15', 'Movimiento controlado'),
    Ex('Extensión de tríceps con liga', '10–15', 'Sin balancear el cuerpo'),
    Ex('Plancha', '15–30 s', 'Abdomen y glúteos activos', unit: 'seg'),
  ],
  'B': [
    Ex('Sentadilla goblet', '10–15', 'Mancuerna frente al pecho'),
    Ex('Press de pecho', '8–12', 'Mancuernas o barra, con seguridad'),
    Ex('Remo con mancuerna (por lado)', '10–12', 'Controla el descenso'),
    Ex('Peso muerto con barra', '8–10', 'Peso que controles bien'),
    Ex('Elevaciones laterales', '12–15', 'Poco peso, sin balanceo'),
    Ex('Curl martillo', '10–15', 'Muñecas neutras'),
    Ex('Face pull con liga', '12–15', 'Espalda alta y hombros'),
    Ex('Dead bug (por lado)', '8–10', 'Lento y controlado'),
  ],
};

String fmt(num n) => n == n.roundToDouble() ? n.toInt().toString() : n.toString();

// ---------- Base de datos (SQLite) ----------
class Db {
  static const _bikeSql =
      'CREATE TABLE bike(id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT, seconds INTEGER)';

  static Database? _db;

  static Future<Database> get db async => _db ??= await openDatabase(
        p.join(await getDatabasesPath(), 'rutina.db'),
        version: 2,
        onCreate: (d, v) async {
          await d.execute('''
            CREATE TABLE logs(
              date TEXT, routine TEXT, exercise TEXT, set_no INTEGER,
              weight REAL, reps INTEGER, done INTEGER,
              PRIMARY KEY(date, routine, exercise, set_no))''');
          await d.execute(_bikeSql);
        },
        onUpgrade: (d, o, n) async {
          if (o < 2) await d.execute(_bikeSql);
        },
      );

  static Future<List<Map<String, Object?>>> day(String date, String r) async =>
      (await db).query('logs', where: 'date=? AND routine=?', whereArgs: [date, r]);

  static Future<void> save(String date, String r, String ex, int n, double w, int reps, bool done) async =>
      (await db).insert(
        'logs',
        {'date': date, 'routine': r, 'exercise': ex, 'set_no': n, 'weight': w, 'reps': reps, 'done': done ? 1 : 0},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  static Future<Map<String, Object?>?> last(String ex, String before) async {
    final r = await (await db).query('logs',
        where: 'exercise=? AND done=1 AND date<>?',
        whereArgs: [ex, before],
        orderBy: 'date DESC, weight DESC',
        limit: 1);
    return r.isEmpty ? null : r.first;
  }

  static Future<List<Map<String, Object?>>> history() async => (await db).rawQuery(
      'SELECT date, routine, SUM(done) AS done, COUNT(*) AS total FROM logs '
      'GROUP BY date, routine HAVING SUM(done) > 0 ORDER BY date DESC');

  /// Cierra la sesión en curso: borra series sin marcar y le pone un id único.
  static Future<void> finish(String date, String r, String id) async {
    final d = await db;
    await d.transaction((t) async {
      await t.delete('logs', where: 'date=? AND routine=? AND done=0', whereArgs: [date, r]);
      await t.update('logs', {'date': id}, where: 'date=? AND routine=?', whereArgs: [date, r]);
    });
  }

  static Future<void> saveBike(String id, int seconds) async =>
      (await db).insert('bike', {'date': id, 'seconds': seconds});

  /// Peso máximo por sesión de un ejercicio.
  static Future<List<Pt>> weightSeries(String ex) async {
    final rows = await (await db).rawQuery(
        'SELECT date, MAX(weight) AS w FROM logs '
        'WHERE exercise=? AND done=1 AND weight>0 GROUP BY date ORDER BY date',
        [ex]);
    return [for (final r in rows) Pt(DateTime.parse(r['date'] as String), (r['w'] as num).toDouble())];
  }

  /// Minutos de bicicleta por sesión.
  static Future<List<Pt>> bikeSeries() async {
    final rows = await (await db).query('bike', orderBy: 'date');
    return [
      for (final r in rows) Pt(DateTime.parse(r['date'] as String), (r['seconds'] as int) / 60),
    ];
  }

  /// Fuerza + bicicleta juntas, más recientes primero.
  static Future<List<Map<String, Object?>>> timeline() async {
    final gym = await history();
    final bike = await (await db).query('bike');
    final all = <Map<String, Object?>>[
      for (final g in gym) {...g, 'type': 'gym'},
      for (final b in bike) {...b, 'type': 'bike'},
    ];
    all.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
    return all;
  }
}

// ---------- Paleta ----------
const cMist = Color(0xFFEDEDED);
const cSlate = Color(0xFF9CA3AF);
const cSteel = Color(0xFF4B5563);
const cNight = Color(0xFF1F2937);
const cInk = Color(0xFF111827);

// ---------- App ----------
void main() => runApp(const App());

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext c) => MaterialApp(
        title: 'Rutina',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: cInk,
          colorScheme: const ColorScheme.dark(
            primary: cMist,
            onPrimary: cInk,
            secondary: cSlate,
            onSecondary: cInk,
            surface: cInk,
            onSurface: cMist,
            onSurfaceVariant: cSlate,
            outline: cSteel,
            outlineVariant: cSteel,
            surfaceContainerLow: cNight,
            surfaceContainer: cNight,
            surfaceContainerHigh: cNight,
            surfaceContainerHighest: cSteel,
          ),
        ),
        home: const Home(),
      );
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int tab = 0;

  Future<void> _export(String kind) async {
    final msg = ScaffoldMessenger.of(context);
    try {
      final report = await buildReport();
      if (report.isEmpty) {
        msg.showSnackBar(const SnackBar(content: Text('Aún no hay sesiones para exportar.')));
        return;
      }
      kind == 'pdf' ? await exportPdf(report) : await exportImage(report);
    } catch (e) {
      msg.showSnackBar(SnackBar(content: Text('No se pudo exportar: $e')));
    }
  }
  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(
          title: Text(['Entrenar', 'Historial', 'Progreso'][tab]),
          actions: [
            if (tab == 1)
              PopupMenuButton<String>(
                icon: const Icon(Icons.download),
                tooltip: 'Descargar historial',
                onSelected: _export,
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'pdf', child: Text('Descargar PDF')),
                  PopupMenuItem(value: 'img', child: Text('Descargar imagen')),
                ],
              ),
          ],
        ),
        body: tab == 0
            ? ListView(padding: const EdgeInsets.all(16), children: [
                for (final k in routines.keys)
                  Card(
                    child: ListTile(
                      title: Text('Rutina $k'),
                      subtitle: Text('${routines[k]!.length} ejercicios · cuerpo completo'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => Workout(k))),
                    ),
                  ),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.directions_bike),
                    title: const Text('Bicicleta estática'),
                    subtitle: const Text('Solo cardio · cronómetro'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const Bike())),
                  ),
                ),
              ])
            : tab == 1
                ? const History()
                : const Progress(),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (i) => setState(() => tab = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.fitness_center), label: 'Entrenar'),
            NavigationDestination(icon: Icon(Icons.history), label: 'Historial'),
            NavigationDestination(icon: Icon(Icons.show_chart), label: 'Progreso'),
          ],
        ),
      );
}

// ---------- Historial ----------
class History extends StatelessWidget {
  const History({super.key});
  @override
  Widget build(BuildContext c) => FutureBuilder<List<Map<String, Object?>>>(
        future: Db.timeline(),
        builder: (c, s) {
          final rows = s.data ?? [];
          if (rows.isEmpty) {
            return const Center(child: Text('Aún no hay sesiones. Marca tu primera serie.'));
          }
          return ListView(children: [
            for (final r in rows)
              r['type'] == 'bike'
                  ? ListTile(
                      leading: const Icon(Icons.directions_bike),
                      title: Text('${_short(r['date'] as String)} · Bicicleta'),
                      subtitle: Text(_mins(r['seconds'] as int)),
                    )
                  : ListTile(
                      leading: const Icon(Icons.fitness_center),
                      title: Text('${_short(r['date'] as String)} · Rutina ${r['routine']}'),
                      subtitle: Text('${r['done']} de ${r['total']} series completadas'),
                      onTap: () => _detail(c, r['date'] as String, r['routine'] as String),
                    ),
          ]);
        },
      );
}

String _short(String d) => d.length > 16 ? d.substring(0, 16) : d;

String _mins(int s) => s >= 60 ? '${s ~/ 60} min ${s % 60} s' : '$s s';

Future<void> _detail(BuildContext c, String d, String r) async {
  final rows = (await Db.day(d, r)).where((x) => x['done'] == 1).toList();
  if (!c.mounted) return;
  showModalBottomSheet(
    context: c,
    builder: (_) => ListView(padding: const EdgeInsets.all(16), children: [
      for (final x in rows)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text('${x['exercise']} · serie ${(x['set_no'] as int) + 1}: '
              '${fmt(x['weight'] as num)} kg × ${x['reps']}'),
        ),
    ]),
  );
}

// ---------- Sesión de entrenamiento ----------
class SetRow {
  final w = TextEditingController();
  final r = TextEditingController();
  bool done = false;
}

class Workout extends StatefulWidget {
  final String routine;
  const Workout(this.routine, {super.key});
  @override
  State<Workout> createState() => _WorkoutState();
}

class _WorkoutState extends State<Workout> {
  final date = DateTime.now().toIso8601String().substring(0, 10);
  final rows = <String, List<SetRow>>{};
  final hints = <String, String>{};
  int restTotal = 90, rest = 0;
  Timer? timer;
  bool loading = true;

  List<Ex> get exs => routines[widget.routine]!;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final saved = await Db.day(date, widget.routine);
    for (final e in exs) {
      final mine = saved.where((x) => x['exercise'] == e.name).toList();
      final n = mine.fold<int>(baseSets, (m, x) => max(m, (x['set_no'] as int) + 1));
      final list = List.generate(n, (_) => SetRow());
      for (final x in mine) {
        final s = list[x['set_no'] as int];
        final w = (x['weight'] as num).toDouble();
        final r = x['reps'] as int;
        s.w.text = w == 0 ? '' : fmt(w);
        s.r.text = r == 0 ? '' : '$r';
        s.done = x['done'] == 1;
      }
      rows[e.name] = list;
      final l = await Db.last(e.name, date);
      if (l != null) hints[e.name] = 'Última vez: ${fmt(l['weight'] as num)} kg × ${l['reps']}';
    }
    if (mounted) setState(() => loading = false);
  }

  void _save(Ex e, int i) {
    final s = rows[e.name]![i];
    Db.save(date, widget.routine, e.name, i, double.tryParse(s.w.text.replaceAll(',', '.')) ?? 0,
        int.tryParse(s.r.text) ?? 0, s.done);
  }

  void _toggle(Ex e, int i, bool v) {
    setState(() => rows[e.name]![i].done = v);
    _save(e, i);
    if (v) _startRest();
  }

  void _startRest() {
    timer?.cancel();
    setState(() => rest = restTotal);
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (rest <= 1) {
        t.cancel();
        setState(() => rest = 0);
        HapticFeedback.heavyImpact();
        SystemSound.play(SystemSoundType.alert);
      } else {
        setState(() => rest--);
      }
    });
  }

  Future<void> _finish() async {
    final done = rows.values.expand((l) => l).where((s) => s.done).length;
    if (done == 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Marca al menos una serie para guardar.')));
      return;
    }
    final id = DateTime.now().toIso8601String().substring(0, 19).replaceAll('T', ' ');
    await Db.finish(date, widget.routine, id);

    final newHints = <String, String>{};
    for (final e in exs) {
      final l = await Db.last(e.name, date);
      if (l != null) newHints[e.name] = 'Última vez: ${fmt(l['weight'] as num)} kg × ${l['reps']}';
    }
    if (!mounted) return;

    final removed = <SetRow>[];
    timer?.cancel();
    setState(() {
      for (final l in rows.values) {
        while (l.length > baseSets) {
          removed.add(l.removeLast());
        }
        for (final s in l) {
          s.w.clear();
          s.r.clear();
          s.done = false;
        }
      }
      hints
        ..clear()
        ..addAll(newHints);
      rest = 0;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final s in removed) {
        s.w.dispose();
        s.r.dispose();
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Progreso guardado: $done series.')));
  }

  @override
  void dispose() {
    timer?.cancel();
    for (final l in rows.values) {
      for (final s in l) {
        s.w.dispose();
        s.r.dispose();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(
          title: Text('Rutina ${widget.routine}'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.icon(
                onPressed: loading ? null : _finish,
                icon: const Icon(Icons.save),
                label: const Text('Guardar'),
              ),
            ),
          ],
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(padding: const EdgeInsets.all(12), children: [for (final e in exs) _card(e)]),
        bottomNavigationBar: _restBar(),
      );

  Widget _card(Ex e) {
    final list = rows[e.name]!;
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(e.name, style: theme.textTheme.titleMedium),
          Text('${e.reps} · ${e.tip}'),
          if (hints[e.name] != null)
            Text(hints[e.name]!, style: TextStyle(color: theme.colorScheme.primary)),
          const SizedBox(height: 4),
          for (var i = 0; i < list.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Checkbox(value: list[i].done, onChanged: (v) => _toggle(e, i, v ?? false)),
                Text('Serie ${i + 1}'),
                const SizedBox(width: 12),
                Expanded(child: _field(list[i].w, 'kg', e, i)),
                const SizedBox(width: 8),
                Expanded(child: _field(list[i].r, e.unit, e, i)),
              ]),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => setState(() => list.add(SetRow())),
              icon: const Icon(Icons.add),
              label: const Text('Serie'),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _field(TextEditingController t, String label, Ex e, int i) => TextField(
        controller: t,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, isDense: true, border: const OutlineInputBorder()),
        onChanged: (_) => _save(e, i),
      );

  Widget _restBar() {
    final theme = Theme.of(context);
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: theme.colorScheme.surfaceContainerHigh,
        child: rest > 0
            ? Row(children: [
                Text('${rest ~/ 60}:${(rest % 60).toString().padLeft(2, '0')}',
                    style: theme.textTheme.headlineMedium),
                const Spacer(),
                TextButton(onPressed: () => setState(() => rest += 15), child: const Text('+15 s')),
                TextButton(
                  onPressed: () {
                    timer?.cancel();
                    setState(() => rest = 0);
                  },
                  child: const Text('Saltar'),
                ),
              ])
            : Row(children: [
                const Icon(Icons.timer_outlined),
                const SizedBox(width: 8),
                for (final s in [60, 90, 120])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text('$s s'),
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                      selected: restTotal == s,
                      onSelected: (_) => setState(() => restTotal = s),
                    ),
                  ),
                const Spacer(),
                FilledButton(onPressed: _startRest, child: const Text('Iniciar')),
              ]),
      ),
    );
  }
}

// ---------- Bicicleta estática ----------
class Bike extends StatefulWidget {
  const Bike({super.key});
  @override
  State<Bike> createState() => _BikeState();
}

class _BikeState extends State<Bike> {
  Duration acc = Duration.zero;
  DateTime? startedAt;
  Timer? ticker;
  final manual = TextEditingController();

  bool get running => startedAt != null;
  Duration get elapsed =>
      acc + (startedAt == null ? Duration.zero : DateTime.now().difference(startedAt!));

  String get clock {
    final s = elapsed.inSeconds;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  void _toggle() {
    if (running) {
      ticker?.cancel();
      setState(() {
        acc = elapsed;
        startedAt = null;
      });
    } else {
      startedAt = DateTime.now();
      ticker = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
      setState(() {});
    }
  }

  void _reset() {
    ticker?.cancel();
    manual.clear();
    setState(() {
      acc = Duration.zero;
      startedAt = null;
    });
  }

  Future<void> _save() async {
    var secs = elapsed.inSeconds;
    if (secs == 0) secs = (int.tryParse(manual.text) ?? 0) * 60;
    if (secs == 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Inicia el cronómetro o escribe los minutos.')));
      return;
    }
    final id = DateTime.now().toIso8601String().substring(0, 19).replaceAll('T', ' ');
    await Db.saveBike(id, secs);
    if (!mounted) return;
    _reset();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Bicicleta guardada: ${_mins(secs)}')));
  }

  @override
  void dispose() {
    ticker?.cancel();
    manual.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final theme = Theme.of(c);
    return Scaffold(
      appBar: AppBar(title: const Text('Bicicleta estática')),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        const SizedBox(height: 24),
        Center(child: Text(clock, style: theme.textTheme.displayLarge)),
        const SizedBox(height: 8),
        Center(
          child: Text('Resistencia baja-media · ritmo en el que puedas hablar',
              textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
        ),
        const SizedBox(height: 32),
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: _toggle,
              icon: Icon(running ? Icons.pause : Icons.play_arrow),
              label: Text(running ? 'Pausar' : (acc == Duration.zero ? 'Iniciar' : 'Continuar')),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(onPressed: _reset, child: const Text('Reiniciar')),
        ]),
        const SizedBox(height: 32),
        TextField(
          controller: manual,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Minutos (si no usaste el cronómetro)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.tonalIcon(
          onPressed: _save,
          icon: const Icon(Icons.save),
          label: const Text('Guardar sesión de bici'),
        ),
      ]),
    );
  }
}

// ---------- Exportar historial ----------
typedef Entry = (String, List<String>);

Future<List<Entry>> buildReport() async {
  final out = <Entry>[];
  for (final r in await Db.timeline()) {
    final d = _short(r['date'] as String);
    if (r['type'] == 'bike') {
      out.add(('$d · Bicicleta · ${_mins(r['seconds'] as int)}', []));
    } else {
      final sets = (await Db.day(r['date'] as String, r['routine'] as String)).where((x) => x['done'] == 1);
      final by = <String, List<String>>{};
      for (final x in sets) {
        by.putIfAbsent(x['exercise'] as String, () => []).add('${fmt(x['weight'] as num)} kg × ${x['reps']}');
      }
      out.add((
        '$d · Rutina ${r['routine']} · ${r['done']} series',
        [for (final e in by.entries) '${e.key}: ${e.value.join(', ')}'],
      ));
    }
  }
  return out;
}

Future<void> exportPdf(List<Entry> report) async {
  final doc = pw.Document();
  doc.addPage(pw.MultiPage(
    build: (_) => [
      pw.Header(level: 0, text: 'Mi historial de entrenamiento'),
      for (final (title, lines) in report)
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 10),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            for (final l in lines) pw.Text('   $l'),
          ]),
        ),
    ],
  ));
  await Printing.sharePdf(bytes: await doc.save(), filename: 'historial.pdf');
}

Future<void> exportImage(List<Entry> report) async {
  const w = 900.0, pad = 32.0, maxH = 7000.0;
  TextPainter tp(String s, double size, Color color, [bool bold = false]) => TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(color: color, fontSize: size, fontWeight: bold ? FontWeight.bold : FontWeight.normal),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: w - 2 * pad);

  final items = <(TextPainter, double)>[(tp('Mi historial de entrenamiento', 34, cMist, true), 0)];
  var h = pad * 2 + items.first.$1.height;
  for (final (title, lines) in report) {
    final block = [(tp(title, 26, cMist, true), 22.0), for (final l in lines) (tp(l, 22, cSlate), 6.0)];
    final bh = block.fold<double>(0, (s, b) => s + b.$1.height + b.$2);
    if (h + bh > maxH) {
      items.add((tp('… más sesiones en el PDF', 22, cSlate), 22));
      break;
    }
    items.addAll(block);
    h += bh;
  }

  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  canvas.drawRect(Rect.fromLTWH(0, 0, w, h + 40), Paint()..color = cInk);
  var y = pad;
  for (final (painter, gap) in items) {
    y += gap;
    painter.paint(canvas, Offset(pad, y));
    y += painter.height;
  }
  final img = await rec.endRecording().toImage(w.toInt(), (h + 40).ceil());
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  final dir = await getTemporaryDirectory();
  final file = File(p.join(dir.path, 'historial.png'));
  await file.writeAsBytes(data!.buffer.asUint8List());
  await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
}

// ---------- Progreso (gráficas) ----------
class Pt {
  final DateTime x;
  final double y;
  const Pt(this.x, this.y);
}

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