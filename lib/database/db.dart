import 'package:path/path.dart' as p;
import 'package:rutina_fit/models/exercises.dart';
import 'package:sqflite/sqflite.dart';

class Db {
  static const _bikeSql =
      'CREATE TABLE bike(id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT, seconds INTEGER)';

  static Database? _db;

  static Future<Database> get db async => _db ??= await openDatabase(
        p.join(await getDatabasesPath(), 'rutina.db'),
        version: 3,
        onCreate: (d, v) async {
          await d.execute('''
            CREATE TABLE logs(
              date TEXT, routine TEXT, exercise TEXT, set_no INTEGER,
              weight REAL, reps INTEGER, done INTEGER,
              PRIMARY KEY(date, routine, exercise, set_no))''');
          await d.execute(_bikeSql);
          await _createLibrary(d);
          await _seedCatalog(d);
        },
        onUpgrade: (d, o, n) async {
          if (o < 2) await d.execute(_bikeSql);
          if (o < 3) {
            await _createLibrary(d);
            await _seedCatalog(d);
            await _legacyRoutines(d);
          }
        },
      );

  static Future<void> _createLibrary(Database d) async {
    await d.execute('CREATE TABLE exercises(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT UNIQUE, '
        'category TEXT, sub TEXT, reps TEXT, tip TEXT, unit TEXT, custom INTEGER DEFAULT 0)');
    await d.execute('CREATE TABLE routines(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT UNIQUE)');
    await d.execute('CREATE TABLE routine_exercises(routine_id INTEGER, exercise_id INTEGER, '
        'position INTEGER, PRIMARY KEY(routine_id, exercise_id))');
  }

  static Future<void> _seedCatalog(Database d) async {
    final b = d.batch();
    for (final (name, sub, reps, tip) in catalog) {
      b.insert('exercises', {
        'name': name,
        'category': subcategories[sub],
        'sub': sub,
        'reps': reps,
        'tip': tip,
        'unit': reps.endsWith(' s') ? 'seg' : 'reps',
        'custom': 0,
      });
    }
    await b.commit(noResult: true);
  }

  /// Convierte las antiguas Rutina A y B en rutinas normales y conserva su historial.
  static Future<void> _legacyRoutines(Database d) async {
    const a = [
      'Sentadilla con barra', 'Press de pecho con mancuernas', 'Remo con barra', 'Peso muerto rumano',
      'Press de hombros', 'Curl de bíceps', 'Extensión de tríceps con liga', 'Plancha',
    ];
    const b = [
      'Sentadilla goblet', 'Press de pecho', 'Remo con mancuerna (por lado)', 'Peso muerto con barra',
      'Elevaciones laterales', 'Curl martillo', 'Face pull con liga', 'Dead bug (por lado)',
    ];
    Future<void> make(String name, List<String> names) async {
      final rid = await d.insert('routines', {'name': name});
      for (var i = 0; i < names.length; i++) {
        final r = await d.query('exercises', columns: ['id'], where: 'name=?', whereArgs: [names[i]]);
        if (r.isNotEmpty) {
          await d.insert('routine_exercises', {'routine_id': rid, 'exercise_id': r.first['id'], 'position': i});
        }
      }
    }

    await make('Rutina A', a);
    await make('Rutina B', b);
    await d.execute("UPDATE logs SET routine = 'Rutina ' || routine WHERE routine IN ('A', 'B')");
  }

  // ---------- Catálogo y rutinas ----------
  static Future<List<Ex>> exercises() async => [
        for (final m in await (await db).query('exercises', orderBy: 'category, sub, name')) Ex.fromMap(m),
      ];

  static Future<Map<String, String>> units() async => {for (final e in await exercises()) e.name: e.unit};

  /// Crea un ejercicio propio. Lanza error si el nombre ya existe.
  static Future<int> addExercise(String name, String sub, String reps, String unit) async =>
      (await db).insert('exercises', {
        'name': name,
        'category': subcategories[sub],
        'sub': sub,
        'reps': reps,
        'tip': '',
        'unit': unit,
        'custom': 1,
      });

  static Future<List<Map<String, Object?>>> routines() async => (await db).rawQuery(
      'SELECT r.id, r.name, COUNT(re.exercise_id) AS n FROM routines r '
      'LEFT JOIN routine_exercises re ON re.routine_id = r.id GROUP BY r.id ORDER BY r.id');

  static Future<List<Ex>> routineExercises(int id) async => [
        for (final m in await (await db).rawQuery(
            'SELECT e.* FROM routine_exercises re JOIN exercises e ON e.id = re.exercise_id '
            'WHERE re.routine_id = ? ORDER BY re.position',
            [id]))
          Ex.fromMap(m),
      ];

  static Future<void> saveRoutine(int? id, String name, List<int> exerciseIds) async {
    final d = await db;
    await d.transaction((t) async {
      var rid = id;
      if (rid == null) {
        rid = await t.insert('routines', {'name': name});
      } else {
        await t.update('routines', {'name': name}, where: 'id=?', whereArgs: [rid]);
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
        where: 'exercise=? AND done=1 AND date<>?',
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

  static Future<void> saveBike(String id, int seconds) async =>
      (await db).insert('bike', {'date': id, 'seconds': seconds});

  /// Sesión sin guardar = fecha sin hora; se ubica a las 8:00.
  static DateTime _parse(String d) => DateTime.parse(d.length <= 10 ? '$d 08:00:00' : d);

  /// Peso máximo por sesión de un ejercicio.
  static Future<List<Pt>> weightSeries(String ex) async {
    final rows = await (await db).rawQuery(
        'SELECT date, MAX(weight) AS w FROM logs'
        ' WHERE exercise=? AND done=1 AND weight>0 GROUP BY date ORDER BY date',
        [ex]);
    return [for (final r in rows) Pt(_parse(r['date'] as String), (r['w'] as num).toDouble())];
  }

  /// Minutos de bicicleta por sesión.
  static Future<List<Pt>> bikeSeries() async {
    final rows = await (await db).query('bike', orderBy: 'date');
    return [
      for (final r in rows) Pt(_parse(r['date'] as String), (r['seconds'] as int) / 60),
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


class Pt {
  final DateTime x;
  final double y;
  const Pt(this.x, this.y);
}