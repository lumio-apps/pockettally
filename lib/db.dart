import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'models.dart';

/// Local SQLite storage. Everything stays on the device.
///
/// Schema history:
///   v1 (app 0.1.0): entries
///   v2 (app 0.2.0): categories
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get _database async {
    if (_db != null) return _db!;
    final dir = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dir, 'pockettally.db'),
      version: 2,
      onCreate: (db, version) async {
        await _createEntries(db);
        await _createCategories(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createCategories(db);
        }
      },
    );
    return _db!;
  }

  static Future<void> _createEntries(Database db) async {
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
  }

  /// Creates the categories table, adds the defaults, and adds any category
  /// name already used by existing entries (for users upgrading from 0.1.0).
  static Future<void> _createCategories(Database db) async {
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        color INTEGER NOT NULL,
        UNIQUE(name, type)
      )
    ''');

    final batch = db.batch();
    for (final (name, color) in kDefaultExpenseCategories) {
      batch.insert('categories', {
        'name': name,
        'type': EntryType.expense.name,
        'color': color,
      });
    }
    for (final (name, color) in kDefaultIncomeCategories) {
      batch.insert('categories', {
        'name': name,
        'type': EntryType.income.name,
        'color': color,
      });
    }
    await batch.commit(noResult: true);

    final used =
        await db.rawQuery('SELECT DISTINCT category, type FROM entries');
    var i = 0;
    for (final row in used) {
      await db.insert(
        'categories',
        {
          'name': row['category'],
          'type': row['type'],
          'color': kCategoryPalette[i++ % kCategoryPalette.length],
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  // ---- entries ----

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

  // ---- categories ----

  Future<List<EntryCategory>> allCategories() async {
    final db = await _database;
    final rows = await db.query('categories', orderBy: 'name COLLATE NOCASE');
    return rows.map(EntryCategory.fromMap).toList();
  }

  Future<void> insertCategory(EntryCategory c) async {
    final db = await _database;
    await db.insert('categories', c.toMap());
  }

  /// Saves a changed name/color. Entries using the old name follow the rename.
  Future<void> updateCategory(EntryCategory old, EntryCategory changed) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.update('categories', changed.toMap(),
          where: 'id = ?', whereArgs: [old.id]);
      if (old.name != changed.name) {
        await txn.update(
          'entries',
          {'category': changed.name},
          where: 'category = ? AND type = ?',
          whereArgs: [old.name, old.type.name],
        );
      }
    });
  }

  /// Deletes a category and moves its entries to "Other".
  Future<void> deleteCategory(EntryCategory c) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.update(
        'entries',
        {'category': kOtherCategory},
        where: 'category = ? AND type = ?',
        whereArgs: [c.name, c.type.name],
      );
      await txn.delete('categories', where: 'id = ?', whereArgs: [c.id]);
    });
  }
}
