import 'dart:convert';
import 'dart:math' show max;
import 'dart:ui' as ui;
import 'dart:typed_data' show Uint8List;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart' show PdfColor, PdfPageFormat;
import 'package:pdf/widgets.dart' as pw;
import 'package:rutina_fit/database/db.dart';
import 'package:rutina_fit/models/exercises.dart' show kindOf, setText;
import 'package:rutina_fit/theme/app_theme.dart';
import 'package:rutina_fit/utils/format.dart';
import 'package:simple_file_saver/simple_file_saver.dart';

// ---------- Datos del reporte ----------
class Entry {
  final bool bike;
  final DateTime when;
  final String whenLabel, title, badge;
  final List<(String, String)> rows; // (ejercicio, series)
  final int sets;
  final double minutes;
  const Entry({
    required this.bike,
    required this.when,
    required this.whenLabel,
    required this.title,
    required this.badge,
    this.rows = const [],
    this.sets = 0,
    this.minutes = 0,
  });
}

const _months = [
  'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
  'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
];

String _two(int n) => n.toString().padLeft(2, '0');
String _dayLabel(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year}';
String _stamp() {
  final d = DateTime.now();
  return '${d.year}${_two(d.month)}${_two(d.day)}_${_two(d.hour)}${_two(d.minute)}';
}

DateTime _parse(String d) => DateTime.parse(d.length <= 10 ? '$d 08:00:00' : d);
String _label(String raw) {
  final d = _parse(raw);
  return raw.length <= 10 ? _dayLabel(d) : '${_dayLabel(d)}  ${_two(d.hour)}:${_two(d.minute)}';
}

/// Series consecutivas idénticas se muestran una sola vez: "20 kg × 8 (2 series)".
/// Si son distintas, se listan todas: "20 kg × 8   22 kg × 6".
String _compact(List<String> sets) {
  final out = <String>[];
  var i = 0;
  while (i < sets.length) {
    var j = i;
    while (j + 1 < sets.length && sets[j + 1] == sets[i]) {
      j++;
    }
    final n = j - i + 1;
    out.add(n > 1 ? '${sets[i]} ($n series)' : sets[i]);
    i = j + 1;
  }
  return out.join('   ');
}

Future<List<Entry>> buildReport() async {
  final exs = await Db.byName();
  final out = <Entry>[];
  for (final r in await Db.timeline()) {
    final raw = r['date'] as String;
    if (r['type'] == 'bike') {
      final secs = r['seconds'] as int;
      out.add(Entry(
        bike: true,
        when: _parse(raw),
        whenLabel: _label(raw),
        title: (r['exercise'] as String?) ?? 'Bicicleta estática',
        badge: fmtMins(secs),
        minutes: secs / 60,
      ));
    } else {
      final sets = (await Db.day(raw, r['routine'] as String)).where((x) => x['done'] == 1);
      final by = <String, List<String>>{};
      for (final x in sets) {
        final name = x['exercise'] as String;
        final w = (x['weight'] as num).toDouble();
        final e = exs[name];
        by.putIfAbsent(name, () => []).add(
            setText(e?.kind ?? kindOf(name, '', 'reps'), w, x['reps'] as int, e?.unit ?? 'reps'));
      }
      out.add(Entry(
        bike: false,
        when: _parse(raw),
        whenLabel: _label(raw),
        title: '${r['routine']}',
        badge: '${r['done']} series',
        sets: (r['done'] as num).toInt(),
        rows: [for (final e in by.entries) (e.key, _compact(e.value))],
      ));
    }
  }
  return out;
}

List<(String, String)> _stats(List<Entry> report) {
  final gym = report.where((e) => !e.bike).toList();
  final bikes = report.where((e) => e.bike).toList();
  final sets = gym.fold<int>(0, (s, e) => s + e.sets);
  final mins = bikes.fold<double>(0, (s, e) => s + e.minutes);
  return [
    ('${gym.length}', 'Sesiones de fuerza'),
    ('$sets', 'Series completadas'),
    ('${bikes.length}', 'Sesiones de cardio'),
    ('${fmt(double.parse(mins.toStringAsFixed(1)))} min', 'Minutos de cardio'),
  ];
}

/// Agrupa por mes conservando el orden (más reciente primero).
List<(String, List<Entry>)> _groups(List<Entry> report) {
  final out = <(String, List<Entry>)>[];
  for (final e in report) {
    final label = '${_months[e.when.month - 1]} ${e.when.year}';
    if (out.isEmpty || out.last.$1 != label) out.add((label, []));
    out.last.$2.add(e);
  }
  return out;
}

// ---------- PDF ----------
Future<String> exportPdf(List<Entry> report) async {
  final ink = PdfColor.fromHex('#111827');
  final night = PdfColor.fromHex('#1F2937');
  final steel = PdfColor.fromHex('#4B5563');
  final slate = PdfColor.fromHex('#9CA3AF');
  final mist = PdfColor.fromHex('#EDEDED');
  final soft = PdfColor.fromHex('#F3F4F6');
  final line = PdfColor.fromHex('#D1D5DB');

  pw.TextStyle st(double size, PdfColor color, {bool bold = false}) =>
      pw.TextStyle(fontSize: size, color: color, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal);

  pw.Widget statBox(String v, String l) => pw.Expanded(
        child: pw.Container(
          margin: const pw.EdgeInsets.only(right: 6),
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(color: soft, borderRadius: pw.BorderRadius.circular(6)),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(v, style: st(18, ink, bold: true)),
            pw.Text(l, style: st(9, steel)),
          ]),
        ),
      );

  pw.Widget card(Entry e) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 10),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: line, width: 0.8), borderRadius: pw.BorderRadius.circular(6)),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: pw.BoxDecoration(
              color: night,
              borderRadius: pw.BorderRadius.vertical(top: pw.Radius.circular(6)),
            ),
            child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('${e.title}   ${e.whenLabel}', style: st(11, mist, bold: true)),
              pw.Text(e.badge, style: st(10, slate)),
            ]),
          ),
          if (e.rows.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.all(10),
              child: pw.Column(children: [
                for (final (ex, sets) in e.rows)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 3),
                    child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                      pw.SizedBox(width: 170, child: pw.Text(ex, style: st(9.5, ink, bold: true))),
                      pw.Expanded(child: pw.Text(sets, style: st(9.5, steel))),
                    ]),
                  ),
              ]),
            ),
        ]),
      );

  // Fuente con soporte Unicode (acentos, ×, etc.) incrustada en el PDF
  final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/LiberationSans-Regular.ttf'));
  final boldFont = pw.Font.ttf(await rootBundle.load('assets/fonts/LiberationSans-Bold.ttf'));
  final doc = pw.Document(theme: pw.ThemeData.withFont(base: regular, bold: boldFont));
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(32),
    footer: (ctx) => pw.Container(
      alignment: pw.Alignment.centerRight,
      child: pw.Text('Página ${ctx.pageNumber} de ${ctx.pagesCount}', style: st(9, slate)),
    ),
    build: (_) => [
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(18),
        decoration: pw.BoxDecoration(color: ink, borderRadius: pw.BorderRadius.circular(8)),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('Mi historial de entrenamiento', style: st(22, mist, bold: true)),
          pw.SizedBox(height: 4),
          pw.Text('Generado el ${_dayLabel(DateTime.now())}', style: st(10, slate)),
        ]),
      ),
      pw.SizedBox(height: 14),
      pw.Row(children: [for (final (v, l) in _stats(report)) statBox(v, l)]),
      pw.SizedBox(height: 14),
      for (final (label, items) in _groups(report)) ...[
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 6, bottom: 8),
          child: pw.Text(label, style: st(13, ink, bold: true)),
        ),
        for (final e in items) card(e),
      ],
    ],
  ));

  final name = 'historial_${_stamp()}';
  await SimpleFileSaver.saveFile(
    fileInfo: FileSaveInfo.fromBytes(bytes: await doc.save(), basename: name, extension: 'pdf'),
  );
  return '$name.pdf';
}

// ---------- Imagen ----------
class _Block {
  final double h;
  final void Function(Canvas c, double x, double y) paint;
  const _Block(this.h, this.paint);
}

TextPainter _tp(String s, double size, Color color, double maxW, {bool bold = false}) => TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(color: color, fontSize: size, height: 1.25, fontWeight: bold ? FontWeight.bold : FontWeight.normal),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxW);

_Block _statsBlock(List<(String, String)> stats, double w) {
  const gap = 16.0, pad = 20.0;
  final bw = (w - gap * (stats.length - 1)) / stats.length;
  final items = [for (final (v, l) in stats) (_tp(v, 38, cMist, bw - 2 * pad, bold: true), _tp(l, 20, cSlate, bw - 2 * pad))];
  final bh = 2 * pad + items.fold<double>(0, (m, i) => max(m, i.$1.height + i.$2.height));
  return _Block(bh, (c, x, y) {
    for (var i = 0; i < items.length; i++) {
      final bx = x + i * (bw + gap);
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(bx, y, bw, bh), const Radius.circular(20)), Paint()..color = cNight);
      items[i].$1.paint(c, Offset(bx + pad, y + pad));
      items[i].$2.paint(c, Offset(bx + pad, y + pad + items[i].$1.height));
    }
  });
}

_Block _cardBlock(Entry e, double w) {
  const pad = 28.0, col = 420.0;
  final badge = _tp(e.badge, 26, cSlate, 260, bold: true);
  final title = _tp(e.title, 32, cMist, w - 2 * pad - badge.width - 16, bold: true);
  final date = _tp(e.whenLabel, 22, cSlate, w - 2 * pad);
  final rows = [
    for (final (ex, sets) in e.rows) (_tp(ex, 24, cMist, col - 20, bold: true), _tp(sets, 24, cSlate, w - 2 * pad - col)),
  ];
  final head = pad + title.height + 4 + date.height;
  var total = head + pad + (rows.isEmpty ? 0 : 18);
  for (final r in rows) {
    total += max(r.$1.height, r.$2.height) + 10;
  }
  final height = total;
  return _Block(height, (c, x, y) {
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, height), const Radius.circular(24)), Paint()..color = cNight);
    title.paint(c, Offset(x + pad, y + pad));
    badge.paint(c, Offset(x + w - pad - badge.width, y + pad + 4));
    date.paint(c, Offset(x + pad, y + pad + title.height + 4));
    if (rows.isEmpty) return;
    c.drawLine(Offset(x + pad, y + head + 9), Offset(x + w - pad, y + head + 9), Paint()..color = cSteel..strokeWidth = 1);
    var cy = y + head + 18;
    for (final r in rows) {
      r.$1.paint(c, Offset(x + pad, cy));
      r.$2.paint(c, Offset(x + pad + col, cy));
      cy += max(r.$1.height, r.$2.height) + 10;
    }
  });
}

Future<String> exportImage(List<Entry> report) async {
  const w = 1080.0, m = 48.0, cw = w - 2 * m, maxH = 7500.0;
  final blocks = <(_Block, double)>[]; // (bloque, espacio antes)

  final title = _tp('Mi historial de entrenamiento', 46, cMist, cw, bold: true);
  final sub = _tp('Generado el ${_dayLabel(DateTime.now())}', 24, cSlate, cw);
  blocks.add((
    _Block(title.height + 6 + sub.height, (c, x, y) {
      title.paint(c, Offset(x, y));
      sub.paint(c, Offset(x, y + title.height + 6));
    }),
    0,
  ));
  blocks.add((_statsBlock(_stats(report), cw), 32));

  var h = m * 2 + blocks.fold<double>(0, (s, b) => s + b.$1.h + b.$2);
  var skipped = 0;
  for (final (label, items) in _groups(report)) {
    final head = _tp(label, 30, cSlate, cw, bold: true);
    final headBlock = _Block(head.height, (c, x, y) => head.paint(c, Offset(x, y)));
    var headAdded = false;
    for (final e in items) {
      final card = _cardBlock(e, cw);
      final need = card.h + 16 + (headAdded ? 0 : headBlock.h + 36);
      if (h + need > maxH) {
        skipped++;
        continue;
      }
      if (!headAdded) {
        blocks.add((headBlock, 36));
        h += headBlock.h + 36;
        headAdded = true;
      }
      blocks.add((card, 16));
      h += card.h + 16;
    }
  }
  if (skipped > 0) {
    final note = _tp('… y $skipped sesiones más en el PDF', 22, cSlate, cw);
    blocks.add((_Block(note.height, (c, x, y) => note.paint(c, Offset(x, y))), 24));
    h += note.height + 24;
  }

  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = cInk);
  var y = m;
  for (final (b, gap) in blocks) {
    y += gap;
    b.paint(canvas, m, y);
    y += b.h;
  }
  final img = await rec.endRecording().toImage(w.toInt(), h.ceil());
  final data = await img.toByteData(format: ui.ImageByteFormat.png);

  final name = 'historial_${_stamp()}';
  await SimpleFileSaver.saveFile(
    fileInfo: FileSaveInfo.fromBytes(bytes: data!.buffer.asUint8List(), basename: name, extension: 'png'),
  );
  return '$name.png';
}
// ---------- Respaldo ----------
/// Guarda en Descargas un archivo .json con todos tus datos, para pasarlo al teléfono nuevo.
Future<String> exportBackup() async {
  final name = 'rutina_fit_respaldo_${_stamp()}';
  final bytes = utf8.encode(const JsonEncoder.withIndent(' ').convert(await Db.exportData()));
  await SimpleFileSaver.saveFile(
    fileInfo: FileSaveInfo.fromBytes(bytes: Uint8List.fromList(bytes), basename: name, extension: 'json'),
  );
  return '$name.json';
}

/// Abre el selector de archivos y une el respaldo elegido. null = el usuario canceló.
Future<(int, int, int)?> importBackup() async {
  final file = await FilePicker.pickFile(dialogTitle: 'Elige tu respaldo de Rutina Fit');
  if (file == null) return null;
  final Object? data;
  try {
    data = jsonDecode(utf8.decode(await file.readAsBytes()));
  } on FormatException {
    throw const FormatException('El archivo no es un respaldo válido (.json).');
  }
  if (data is! Map<String, dynamic>) throw const FormatException('El archivo no es un respaldo válido.');
  return Db.importData(data);
}
