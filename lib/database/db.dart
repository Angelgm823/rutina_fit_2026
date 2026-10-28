import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:rutina_fit/models/exercises.dart';
import 'package:sqflite/sqflite.dart';

class Db {
  /// Tu base de ejercicios (tablas grupos_musculares y ejercicios), incluida en la app.
  static const _catalogAsset = 'assets/db/ejercicios.db';

  static Database? _db;

  static Future<Database> get db async => _db ??= await openDatabase(
        p.join(await getDatabasesPath(), 'rutina.db'),
        version: 7,
        onCreate: (d, v) async {
          await d.execute('''
            CREATE TABLE logs(
              date TEXT, routine TEXT, exercise TEXT, set_no INTEGER,
              weight REAL, reps INTEGER, done INTEGER,
              PRIMARY KEY(date, routine, exercise, set_no))''');
          await d.execute('CREATE TABLE bike(id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT, seconds INTEGER, exercise TEXT)');
          await _createLibrary(d);
        },
        onUpgrade: (d, o, n) async {
          if (o < 6) await _migrateTo6(d);
          if (o < 7) await _migrateTo7(d);
        },
        // Cada vez que abre la app compara tu ejercicios.db con el último que importó.
        onOpen: _syncCatalog,
      );

  /// Lee un valor guardado (ajustes de la app).
  static Future<String?> getMeta(String key) async {
    final r = await (await db).query('meta', where: 'key = ?', whereArgs: [key]);
    return r.isEmpty ? null : r.first['value'] as String?;
  }

  /// Guarda un valor (ajustes de la app).
  static Future<void> setMeta(String key, String value) async =>
      (await db).insert('meta', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);

  static Future<void> _createLibrary(Database d) async {
    await d.execute('CREATE TABLE exercises(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT UNIQUE, '
        'category TEXT, sub TEXT, reps TEXT, tip TEXT, unit TEXT, custom INTEGER DEFAULT 0, '
        'equipment TEXT, descr TEXT, ext_id TEXT, active INTEGER DEFAULT 1)');
    await d.execute('CREATE TABLE routines(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT UNIQUE, days TEXT)');
    await d.execute('CREATE TABLE routine_exercises(routine_id INTEGER, exercise_id INTEGER, '
        'position INTEGER, PRIMARY KEY(routine_id, exercise_id))');
    await d.execute('CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT)');
  }

  static Future<void> _ensureColumn(Database d, String table, String col, String type) async {
    final cols = [for (final r in await d.rawQuery('PRAGMA table_info($table)')) r['name']];
    if (!cols.contains(col)) await d.execute('ALTER TABLE $table ADD COLUMN $col $type');
  }

  /// Pasa de la base anterior (catálogo de 1,300 ejercicios en inglés) a la tuya.
  /// Tus rutinas, sesiones guardadas y ejercicios propios se conservan.
  static Future<void> _migrateTo6(Database d) async {
    // Bases muy antiguas pueden no tener estas tablas; créalas si faltan.
    await d.execute('''CREATE TABLE IF NOT EXISTS exercises(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT UNIQUE,
        category TEXT, sub TEXT, reps TEXT, tip TEXT, unit TEXT, custom INTEGER DEFAULT 0,
        equipment TEXT, descr TEXT, ext_id TEXT, active INTEGER DEFAULT 1)''');
    await d.execute('CREATE TABLE IF NOT EXISTS routines(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT UNIQUE)');
    await d.execute('CREATE TABLE IF NOT EXISTS routine_exercises(routine_id INTEGER, exercise_id INTEGER, '
        'position INTEGER, PRIMARY KEY(routine_id, exercise_id))');
    await _ensureColumn(d, 'exercises', 'equipment', 'TEXT');
    await _ensureColumn(d, 'exercises', 'descr', 'TEXT');
    await _ensureColumn(d, 'exercises', 'ext_id', 'TEXT');
    await _ensureColumn(d, 'exercises', 'active', 'INTEGER DEFAULT 1');
    await _ensureColumn(d, 'bike', 'exercise', 'TEXT');
    await d.execute('CREATE TABLE IF NOT EXISTS meta(key TEXT PRIMARY KEY, value TEXT)');

    // Borra el catálogo viejo que ninguna rutina ni sesión usa...
    await d.execute('DELETE FROM exercises WHERE custom = 0 '
        'AND id NOT IN (SELECT exercise_id FROM routine_exercises) '
        'AND name NOT IN (SELECT DISTINCT exercise FROM logs)');
    // ...y oculta del selector el que sí se usa (sigue funcionando en tus rutinas).
    await d.execute('UPDATE exercises SET active = 0, ext_id = NULL WHERE custom = 0');
    // Ejercicios que creaste tú: ajustar al nombre nuevo del grupo.
    await d.execute("UPDATE exercises SET sub = CASE sub WHEN 'Brazo' THEN 'Brazos' WHEN 'Hombro' THEN 'Hombros' "
        "WHEN 'Pierna' THEN 'Piernas y glúteos' WHEN 'Glúteo' THEN 'Piernas y glúteos' "
        "WHEN 'Gemelos' THEN 'Piernas y glúteos' WHEN 'Abdominales' THEN 'Abdomen' ELSE sub END WHERE custom = 1");
  }

  /// Agrega a cada rutina los días de la semana en que se entrena (opcional, lo eliges al crearla o editarla).
  static Future<void> _migrateTo7(Database d) async {
    await _ensureColumn(d, 'routines', 'days', 'TEXT');
  }

  /// '1,3,5' -> [1, 3, 5] (1 = lunes ... 7 = domingo, como DateTime.weekday). Vacío o null = sin día fijo.
  static List<int> parseDays(String? raw) =>
      raw == null || raw.isEmpty ? [] : [for (final s in raw.split(',')) int.parse(s)];

  static String? _daysToText(List<int> days) => days.isEmpty ? null : days.join(',');

  static String _fnv(Uint8List b) {
    var h = 0x811c9dc5;
    for (final x in b) {
      h ^= x;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return '${b.length}:${h.toRadixString(16)}';
  }

  /// Lee tu ejercicios.db y deja la tabla exercises al día:
  /// nuevos -> se agregan; cambiados -> se actualizan (y se renombran en tu historial);
  /// borrados de tu base -> se ocultan del selector, sin perder tus rutinas ni sesiones.
  static Future<void> _syncCatalog(Database d) async {
    try {
      final data = await rootBundle.load(_catalogAsset);
      final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      final hash = _fnv(bytes);
      final cur = await d.query('meta', where: "key = 'catalog_hash'");
      if (cur.isNotEmpty && cur.first['value'] == hash) return; // sin cambios

      final tmp = p.join(await getDatabasesPath(), 'ejercicios_import.db');
      await File(tmp).writeAsBytes(bytes, flush: true);
      final src = await openDatabase(tmp, readOnly: true);
      final rows = await src.rawQuery(
          'SELECT e.id, e.nombre, e.equipo, e.descripcion, g.nombre AS grupo '
          'FROM ejercicios e JOIN grupos_musculares g ON g.id = e.grupo_id ORDER BY e.id');
      await src.close();
      await File(tmp).delete();

      final timed = RegExp(r'plancha|isom[eé]tric|sost[eé]n|mant[eé]n', caseSensitive: false);
      await d.transaction((t) async {
        final seen = <String>[];
        for (final r in rows) {
          final extId = 'ej:${r['id']}';
          final name = (r['nombre'] as String).trim();
          final group = groupLabel(r['grupo'] as String);
          final equipo = ((r['equipo'] as String?) ?? '').trim();
          final secs = timed.hasMatch(name);
          final fields = {
            'category': categoryOf(group),
            'sub': group,
            'equipment': equipo,
            'descr': ((r['descripcion'] as String?) ?? '').trim(),
            'ext_id': extId,
            'custom': 0,
            'active': 1,
          };
          seen.add(extId);

          var prev = await t.query('exercises', columns: ['id', 'name'], where: 'ext_id = ?', whereArgs: [extId]);
          if (prev.isEmpty) prev = await t.query('exercises', columns: ['id', 'name'], where: 'name = ?', whereArgs: [name]);
          if (prev.isEmpty) {
            await t.insert('exercises', {
              'name': name,
              'reps': secs ? '20–40 s' : (equipo.toLowerCase() == 'peso corporal' ? '10–15' : '8–12'),
              'unit': secs ? 'seg' : 'reps',
              'tip': '',
              ...fields,
            });
          } else {
            final id = prev.first['id'];
            final old = prev.first['name'] as String;
            var newName = old;
            if (old != name) {
              final clash = await t.query('exercises', where: 'name = ? AND id <> ?', whereArgs: [name, id]);
              if (clash.isEmpty) {
                newName = name;
                await t.rawUpdate('UPDATE logs SET exercise = ? WHERE exercise = ?', [name, old]);
              }
            }
            await t.update('exercises', {'name': newName, ...fields}, where: 'id = ?', whereArgs: [id]);
          }
        }
        if (seen.isNotEmpty) {
          await t.rawUpdate(
              "UPDATE exercises SET active = 0 WHERE ext_id LIKE 'ej:%' AND ext_id NOT IN (${seen.map((_) => '?').join(',')})",
              seen);
        }
        await t.insert('meta', {'key': 'catalog_hash', 'value': hash}, conflictAlgorithm: ConflictAlgorithm.replace);
      });
    } catch (e) {
      debugPrint('No se pudo importar $_catalogAsset: $e');
    }
  }

  // ---------- Catálogo y rutinas ----------
  static const _exCols = ['id', 'name', 'category', 'sub', 'reps', 'tip', 'unit', 'custom', 'equipment', 'descr'];

  /// Ejercicios para armar rutinas (sin cardio y sin los ocultos).
  static Future<List<Ex>> exercises() async => [
        for (final m in await (await db).query('exercises',
            columns: _exCols, where: "active = 1 AND category <> 'Cardio'", orderBy: 'category, sub, name'))
          Ex.fromMap(m),
      ];

  /// Ejercicios de cardio de tu base (bicicleta, caminadora...).
  static Future<List<Ex>> cardio() async => [
        for (final m in await (await db).query('exercises',
            columns: _exCols, where: "active = 1 AND category = 'Cardio'", orderBy: 'id'))
          Ex.fromMap(m),
      ];

  /// Ejercicios con al menos una serie guardada (para la pantalla Progreso).
  static Future<List<String>> loggedExercises() async => [
        for (final r in await (await db).rawQuery('SELECT DISTINCT exercise FROM logs WHERE done=1 ORDER BY exercise'))
          r['exercise'] as String,
      ];

  /// Días de la semana (Lunes, Martes...) en que se realizó una rutina según el historial.
  static Future<List<String>> routineDays(String routine) async {
    const dias = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
    final rows = await (await db).rawQuery(
        'SELECT DISTINCT date FROM logs WHERE routine=? AND done=1', [routine]);
    final seen = <int>{};
    for (final r in rows) {
      final raw = r['date'] as String;
      final d = DateTime.parse(raw.length <= 10 ? '$raw 08:00:00' : raw);
      seen.add(d.weekday);
    }
    return [for (final w in (seen.toList()..sort())) dias[w - 1]];
  }

  /// Todos los ejercicios (incluidos los ocultos) por nombre, para mostrar el historial.
  static Future<Map<String, Ex>> byName() async => {
        for (final m in await (await db).query('exercises', columns: _exCols)) m['name'] as String: Ex.fromMap(m),
      };

  static Future<Kind> kind(String name) async {
    final r = await (await db).query('exercises', columns: _exCols, where: 'name = ?', whereArgs: [name], limit: 1);
    return r.isEmpty ? kindOf(name, '', 'reps') : Ex.fromMap(r.first).kind;
  }

  /// Crea un ejercicio propio. Lanza error si el nombre ya existe.
  static Future<int> addExercise(String name, String group, String reps, String unit) async =>
      (await db).insert('exercises', {
        'name': name,
        'category': categoryOf(group),
        'sub': group,
        'reps': reps,
        'tip': '',
        'unit': unit,
        'custom': 1,
        'equipment': '',
        'descr': '',
        'active': 1,
      });

  static Future<List<Map<String, Object?>>> routines() async => (await db).rawQuery(
      'SELECT r.id, r.name, r.days, COUNT(re.exercise_id) AS n FROM routines r '
      'LEFT JOIN routine_exercises re ON re.routine_id = r.id GROUP BY r.id ORDER BY r.id');

  /// Días de la semana que eligió el usuario para esta rutina (vacío = sin restricción).
  static Future<List<int>> routineDaysOf(int id) async {
    final r = await (await db).query('routines', columns: ['days'], where: 'id = ?', whereArgs: [id], limit: 1);
    return r.isEmpty ? [] : parseDays(r.first['days'] as String?);
  }

  static Future<List<Ex>> routineExercises(int id) async => [
        for (final m in await (await db).rawQuery(
            'SELECT e.* FROM routine_exercises re JOIN exercises e ON e.id = re.exercise_id '
            'WHERE re.routine_id = ? ORDER BY re.position',
            [id]))
          Ex.fromMap(m),
      ];

  static Future<void> saveRoutine(int? id, String name, List<int> exerciseIds, [List<int> days = const []]) async {
    final d = await db;
    await d.transaction((t) async {
      var rid = id;
      if (rid == null) {
        rid = await t.insert('routines', {'name': name, 'days': _daysToText(days)});
      } else {
        await t.update('routines', {'name': name, 'days': _daysToText(days)}, where: 'id=?', whereArgs: [rid]);
        await t.delete('routine_exercises', where: 'routine_id=?', whereArgs: [rid]);
      }
      for (var i = 0; i < exerciseIds.length; i++) {
        await t.insert('routine_exercises', {'routine_id': rid, 'exercise_id': exerciseIds[i], 'position': i});
      }
    });
  }

  /// Borra la rutina; el historial de sesiones ya guardadas se conserva.
  static Future<void> deleteRoutine(int id) async {
    final d = await db;
    await d.delete('routine_exercises', where: 'routine_id=?', whereArgs: [id]);
    await d.delete('routines', where: 'id=?', whereArgs: [id]);
  }

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
        where: 'exercise=? AND done=1 AND date<?',
        whereArgs: [ex, before],
        orderBy: 'date DESC, weight DESC',
        limit: 1);
    return r.isEmpty ? null : r.first;
  }

  static Future<List<Map<String, Object?>>> history() async => (await db).rawQuery(
      'SELECT date, routine, SUM(done) AS done, COUNT(*) AS total FROM logs'
      ' GROUP BY date, routine HAVING SUM(done) > 0 ORDER BY date DESC');

  /// Cierra la sesión en curso: borra series sin marcar y le pone un id único.
  static Future<void> finish(String date, String r, String id) async {
    final d = await db;
    await d.transaction((t) async {
      await t.delete('logs', where: 'date=? AND routine=? AND done=0', whereArgs: [date, r]);
      await t.update('logs', {'date': id}, where: 'date=? AND routine=?', whereArgs: [date, r]);
    });
  }

  /// Guarda una sesión de cardio (bicicleta, caminadora...) con su nombre.
  static Future<void> saveBike(String id, int seconds, String exercise) async =>
      (await db).insert('bike', {'date': id, 'seconds': seconds, 'exercise': exercise});

  /// Sesión sin guardar = fecha sin hora; se ubica a las 8:00.
  static DateTime parseDate(String d) => DateTime.parse(d.length <= 10 ? '$d 08:00:00' : d);

  /// Mejor marca por sesión de un ejercicio: peso (o resistencia de liga) máximo,
  /// o los segundos máximos si es por tiempo.
  static Future<List<Pt>> weightSeries(String ex, {bool timed = false}) async {
    final col = timed ? 'reps' : 'weight';
    final rows = await (await db).rawQuery(
        'SELECT date, MAX($col) AS w FROM logs'
        ' WHERE exercise=? AND done=1 AND $col>0 GROUP BY date ORDER BY date',
        [ex]);
    return [for (final r in rows) Pt(parseDate(r['date'] as String), (r['w'] as num).toDouble())];
  }

  /// Fuerza: repeticiones totales hechas en cada sesión.
  static Future<List<Pt>> strengthSeries() async {
    final rows = await (await db).rawQuery(
        'SELECT date, SUM(reps) AS n FROM logs WHERE done=1 GROUP BY date ORDER BY date');
    return [for (final r in rows) Pt(parseDate(r['date'] as String), (r['n'] as num).toDouble())];
  }

  /// Fuerza detallada: repeticiones por ejercicio en cada sesión (para dividir la
  /// barra de fuerza por color).
  static Future<List<Map<String, Object?>>> strengthDetailRows() async => (await db).rawQuery(
      'SELECT date, exercise, SUM(reps) AS n FROM logs WHERE done=1 GROUP BY date, exercise ORDER BY date');

  /// Minutos de cardio por sesión.
  static Future<List<Pt>> bikeSeries() async {
    final rows = await (await db).query('bike', orderBy: 'date');
    return [
      for (final r in rows) Pt(parseDate(r['date'] as String), (r['seconds'] as int) / 60),
    ];
  }

  /// Fuerza + cardio juntos, más recientes primero.
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

  // ---------- Tops (mejores marcas) ----------

  /// Top 3 sesiones de cardio más largas.
  static Future<List<Map<String, Object?>>> topCardio({int limit = 3}) async =>
      (await db).query('bike', orderBy: 'seconds DESC', limit: limit);

  /// Top 3 series (por peso o resistencia) de cada ejercicio con al menos un registro.
  static Future<Map<String, List<Map<String, Object?>>>> topWeights({int limit = 3}) async {
    final d = await db;
    final names = await d.rawQuery('SELECT DISTINCT exercise FROM logs WHERE done=1 AND weight>0 ORDER BY exercise');
    final result = <String, List<Map<String, Object?>>>{};
    for (final n in names) {
      final name = n['exercise'] as String;
      result[name] = await d.query('logs',
          where: 'exercise=? AND done=1 AND weight>0', whereArgs: [name], orderBy: 'weight DESC, date DESC', limit: limit);
    }
    return result;
  }

  // ---------- Respaldo (cambiar de dispositivo) ----------
  static const backupVersion = 1;

  /// Todo lo tuyo: sesiones, cardio, rutinas y ejercicios propios.
  /// Las rutinas guardan nombres de ejercicio (no ids) porque los ids cambian entre teléfonos.
  static Future<Map<String, Object?>> exportData() async {
    final d = await db;
    final routines = <Map<String, Object?>>[];
    for (final r in await d.query('routines', orderBy: 'id')) {
      final exs = await d.rawQuery(
          'SELECT e.name FROM routine_exercises re JOIN exercises e ON e.id = re.exercise_id '
          'WHERE re.routine_id = ? ORDER BY re.position',
          [r['id']]);
      routines.add({'name': r['name'], 'days': r['days'], 'exercises': [for (final e in exs) e['name']]});
    }
    return {
      'app': 'rutina_fit',
      'version': backupVersion,
      'created': DateTime.now().toIso8601String(),
      'custom_exercises': await d.query('exercises',
          columns: ['name', 'category', 'sub', 'reps', 'tip', 'unit', 'equipment', 'descr'], where: 'custom = 1'),
      'routines': routines,
      'logs': await d.query('logs'),
      'bike': await d.query('bike', columns: ['date', 'seconds', 'exercise']),
    };
  }

  /// Une el respaldo con lo que ya hay (no borra nada). Importar el mismo archivo dos veces no duplica.
  /// Devuelve (sesiones de fuerza, sesiones de cardio, rutinas) importadas.
  static Future<(int, int, int)> importData(Map<String, dynamic> data) async {
    if (data['app'] != 'rutina_fit') throw const FormatException('El archivo no es un respaldo de Rutina Fit.');
    if ((data['version'] as num? ?? 0) > backupVersion) {
      throw const FormatException('El respaldo es de una versión más nueva de la app. Actualiza la app.');
    }
    final d = await db;
    final sessions = <String>{};
    var bikes = 0, routines = 0;
    await d.transaction((t) async {
      for (final e in (data['custom_exercises'] as List? ?? const [])) {
        await t.insert('exercises', {...Map<String, Object?>.from(e as Map), 'custom': 1, 'active': 1},
            conflictAlgorithm: ConflictAlgorithm.ignore);
      }

      for (final r in (data['routines'] as List? ?? const [])) {
        final name = r['name'] as String;
        final ids = <int>[];
        for (final ex in (r['exercises'] as List)) {
          final row = await t.query('exercises', columns: ['id'], where: 'name = ?', whereArgs: [ex], limit: 1);
          if (row.isNotEmpty && !ids.contains(row.first['id'])) ids.add(row.first['id'] as int);
        }
        final prev = await t.query('routines', columns: ['id'], where: 'name = ?', whereArgs: [name]);
        final rid = prev.isEmpty ? await t.insert('routines', {'name': name, 'days': r['days']}) : prev.first['id'] as int;
        await t.delete('routine_exercises', where: 'routine_id = ?', whereArgs: [rid]);
        for (var i = 0; i < ids.length; i++) {
          await t.insert('routine_exercises', {'routine_id': rid, 'exercise_id': ids[i], 'position': i});
        }
        routines++;
      }

      for (final l in (data['logs'] as List? ?? const [])) {
        final m = Map<String, Object?>.from(l as Map);
        await t.insert('logs', m, conflictAlgorithm: ConflictAlgorithm.replace);
        sessions.add('${m['date']}|${m['routine']}');
      }

      for (final b in (data['bike'] as List? ?? const [])) {
        final dup = await t.query('bike',
            where: 'date = ? AND seconds = ? AND exercise IS ?', whereArgs: [b['date'], b['seconds'], b['exercise']]);
        if (dup.isEmpty) {
          await t.insert('bike', {'date': b['date'], 'seconds': b['seconds'], 'exercise': b['exercise']});
          bikes++;
        }
      }
    });
    return (sessions.length, bikes, routines);
  }
}


class Pt {
  final DateTime x;
  final double y;
  const Pt(this.x, this.y);
}