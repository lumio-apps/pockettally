import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'models.dart';

/// Local SQLite storage. Everything stays on the device.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get _database async {
    if (_db != null) return _db!;
    final dir = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dir, 'pockettally.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT NOT NULL,
            amount_minor INTEGER NOT NULL,
            category TEXT NOT NULL,
            date INTEGER NOT NULL,
            note TEXT NOT NULL DEFAULT '',
            period TEXT
          )
        ''');
        await db.execute('CREATE INDEX idx_entries_date ON entries(date)');
      },
    );
    return _db!;
  }

  Future<List<Entry>> allEntries() async {
    final db = await _database;
    final rows = await db.query('entries', orderBy: 'date DESC, id DESC');
    return rows.map(Entry.fromMap).toList();
  }

  Future<int> insert(Entry e) async {
    final db = await _database;
    return db.insert('entries', e.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> update(Entry e) async {
    final db = await _database;
    await db.update('entries', e.toMap(), where: 'id = ?', whereArgs: [e.id]);
  }

  Future<void> delete(int id) async {
    final db = await _database;
    await db.delete('entries', where: 'id = ?', whereArgs: [id]);
  }
}
