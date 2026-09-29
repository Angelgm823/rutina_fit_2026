import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:rutina_fit/database/db.dart';
import 'package:rutina_fit/theme/AppTheme.dart';
import 'package:rutina_fit/utils/format.dart';

typedef Entry = (String, List<String>);

Future<List<Entry>> buildReport() async {
  final out = <Entry>[];
  for (final r in await Db.timeline()) {
    final d = shortDate(r['date'] as String);
    if (r['type'] == 'bike') {
      out.add(('$d · Bicicleta · ${fmtMins(r['seconds'] as int)}', []));
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