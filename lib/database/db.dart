import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

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

  /// Peso máximo por sesión de un ejercicio.
  static Future<List<Pt>> weightSeries(String ex) async {
    final rows = await (await db).rawQuery(
        'SELECT date, MAX(weight) AS w FROM logs'
        ' WHERE exercise=? AND done=1 AND weight>0 GROUP BY date ORDER BY date',
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


class Pt {
  final DateTime x;
  final double y;
  const Pt(this.x, this.y);
}