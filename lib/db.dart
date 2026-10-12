import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'models.dart';
import 'platform.dart';

/// Local SQLite storage. Everything stays on the device.
///
/// Schema history:
///   v1 (app 0.1.0): entries
///   v2 (app 0.2.0): categories
///   v3 (app 0.3.0): categories.budget
///   v4 (app 0.5.0): entries.photo, debts, goals
///   v5 (app 0.6.0): categories.position, categories.hidden
///   v6 (app 0.8.0): entries.tags, recurring, favorites
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  /// Desktop: the user's app data folder. Phones: the usual database folder.
  static Future<String> _path() async {
    final dir =
        isDesktop ? (await appDataDirectory()).path : await getDatabasesPath();
    return p.join(dir, 'pockettally.db');
  }

  /// Deletes the whole database file (used by "Reset the app"). It is
  /// created again, with the default categories, on next use.
  Future<void> deleteEverything() async {
    final db = _db;
    _db = null;
    if (db != null) await db.close();
    await deleteDatabase(await _path());
  }

  Future<Database> get _database async {
    if (_db != null) return _db!;
    _db = await openDatabase(
      await _path(),
      version: 6,
      onCreate: (db, version) async {
        await _createEntries(db);
        await _createCategories(db);
        await _createDebtsAndGoals(db);
        await _createRecurringAndFavorites(db);
      },
      // Every upgrade brings the tables up to date by checking what is
      // there, so an upgrade that stopped half way is finished next time.
      onUpgrade: (db, oldVersion, newVersion) => _ensureSchema(db),
      onOpen: _ensureSchema,
    );
    return _db!;
  }

  /// Adds whatever table or column is missing. Safe to run every time.
  static Future<void> _ensureSchema(Database db) async {
    if (!await _tableExists(db, 'categories')) await _createCategories(db);
    await _addColumnIfMissing(db, 'categories', 'budget', 'INTEGER');
    await _addColumnIfMissing(
        db, 'categories', 'position', 'INTEGER NOT NULL DEFAULT 0');
    await _addColumnIfMissing(
        db, 'categories', 'hidden', 'INTEGER NOT NULL DEFAULT 0');
    await _addColumnIfMissing(db, 'entries', 'photo', 'TEXT');
    await _addColumnIfMissing(
        db, 'entries', 'tags', "TEXT NOT NULL DEFAULT ''");
    await _createDebtsAndGoals(db);
    await _createRecurringAndFavorites(db);
  }

  static Future<bool> _tableExists(Database db, String table) async {
    final rows = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
        [table]);
    return rows.isNotEmpty;
  }

  static Future<void> _addColumnIfMissing(
      Database db, String table, String column, String definition) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    if (columns.any((c) => c['name'] == column)) return;
    await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
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
        period TEXT,
        photo TEXT,
        tags TEXT NOT NULL DEFAULT ''
      )
    ''');
    await db.execute('CREATE INDEX idx_entries_date ON entries(date)');
  }

  static Future<void> _createDebtsAndGoals(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS debts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        person TEXT NOT NULL,
        type TEXT NOT NULL,
        amount_minor INTEGER NOT NULL,
        paid_minor INTEGER NOT NULL DEFAULT 0,
        date INTEGER NOT NULL,
        note TEXT NOT NULL DEFAULT ''
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS goals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        target_minor INTEGER NOT NULL,
        saved_minor INTEGER NOT NULL DEFAULT 0,
        color INTEGER NOT NULL
      )
    ''');
  }

  static Future<void> _createRecurringAndFavorites(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS recurring (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        amount_minor INTEGER NOT NULL,
        category TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        period TEXT,
        tags TEXT NOT NULL DEFAULT '',
        every TEXT NOT NULL,
        anchor_day INTEGER NOT NULL,
        next_date INTEGER NOT NULL,
        paused INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS favorites (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        amount_minor INTEGER NOT NULL,
        category TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        period TEXT
      )
    ''');
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
        budget INTEGER,
        position INTEGER NOT NULL DEFAULT 0,
        hidden INTEGER NOT NULL DEFAULT 0,
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

  /// Adds many entries in one transaction (CSV import).
  Future<void> insertAll(List<Entry> entries) async {
    final db = await _database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final e in entries) {
        batch.insert('entries', e.toMap()..remove('id'));
      }
      await batch.commit(noResult: true);
    });
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

  /// Saves the user's order: [ordered] gets positions 1, 2, 3…
  Future<void> reorderCategories(List<EntryCategory> ordered) async {
    final db = await _database;
    final batch = db.batch();
    for (var i = 0; i < ordered.length; i++) {
      batch.update('categories', {'position': i + 1},
          where: 'id = ?', whereArgs: [ordered[i].id]);
    }
    await batch.commit(noResult: true);
  }

  /// Saves a changed name/color. Entries using the old name follow the rename.
  Future<void> updateCategory(EntryCategory old, EntryCategory changed) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.update('categories', changed.toMap(),
          where: 'id = ?', whereArgs: [old.id]);
      if (old.name != changed.name) {
        // Entries, repeating entries and favorites follow the rename.
        for (final table in const ['entries', 'recurring', 'favorites']) {
          await txn.update(
            table,
            {'category': changed.name},
            where: 'category = ? AND type = ?',
            whereArgs: [old.name, old.type.name],
          );
        }
      }
    });
  }

  /// Deletes a category and moves its entries (and repeating entries and
  /// favorites) to "Other".
  Future<void> deleteCategory(EntryCategory c) async {
    final db = await _database;
    await db.transaction((txn) async {
      for (final table in const ['entries', 'recurring', 'favorites']) {
        await txn.update(
          table,
          {'category': kOtherCategory},
          where: 'category = ? AND type = ?',
          whereArgs: [c.name, c.type.name],
        );
      }
      await txn.delete('categories', where: 'id = ?', whereArgs: [c.id]);
    });
  }

  // ---- debts ----

  Future<List<Debt>> allDebts() async {
    final db = await _database;
    final rows = await db.query('debts', orderBy: 'date DESC, id DESC');
    return rows.map(Debt.fromMap).toList();
  }

  Future<void> saveDebt(Debt d) async {
    final db = await _database;
    if (d.id == null) {
      await db.insert('debts', d.toMap());
    } else {
      await db.update('debts', d.toMap(), where: 'id = ?', whereArgs: [d.id]);
    }
  }

  Future<void> deleteDebt(int id) async {
    final db = await _database;
    await db.delete('debts', where: 'id = ?', whereArgs: [id]);
  }

  // ---- savings goals ----

  Future<List<SavingsGoal>> allGoals() async {
    final db = await _database;
    final rows = await db.query('goals', orderBy: 'id');
    return rows.map(SavingsGoal.fromMap).toList();
  }

  Future<void> saveGoal(SavingsGoal g) async {
    final db = await _database;
    if (g.id == null) {
      await db.insert('goals', g.toMap());
    } else {
      await db.update('goals', g.toMap(), where: 'id = ?', whereArgs: [g.id]);
    }
  }

  Future<void> deleteGoal(int id) async {
    final db = await _database;
    await db.delete('goals', where: 'id = ?', whereArgs: [id]);
  }

  // ---- recurring entries ----

  Future<List<RecurringRule>> allRecurring() async {
    final db = await _database;
    final rows = await db.query('recurring', orderBy: 'next_date, id');
    return rows.map(RecurringRule.fromMap).toList();
  }

  Future<void> saveRecurring(RecurringRule r) async {
    final db = await _database;
    if (r.id == null) {
      await db.insert('recurring', r.toMap());
    } else {
      await db.update('recurring', r.toMap(),
          where: 'id = ?', whereArgs: [r.id]);
    }
  }

  Future<void> deleteRecurring(int id) async {
    final db = await _database;
    await db.delete('recurring', where: 'id = ?', whereArgs: [id]);
  }

  /// Adds the due [entries] and moves the rule on, in one transaction.
  Future<void> applyRecurring(RecurringRule updated, List<Entry> entries) async {
    final db = await _database;
    await db.transaction((txn) async {
      for (final e in entries) {
        await txn.insert('entries', e.toMap()..remove('id'));
      }
      await txn.update('recurring', updated.toMap(),
          where: 'id = ?', whereArgs: [updated.id]);
    });
  }

  // ---- favorites ----

  Future<List<Favorite>> allFavorites() async {
    final db = await _database;
    final rows = await db.query('favorites', orderBy: 'id');
    return rows.map(Favorite.fromMap).toList();
  }

  Future<void> insertFavorite(Favorite f) async {
    final db = await _database;
    await db.insert('favorites', f.toMap());
  }

  Future<void> deleteFavorite(int id) async {
    final db = await _database;
    await db.delete('favorites', where: 'id = ?', whereArgs: [id]);
  }

  // ---- backup / restore ----

  /// Replaces ALL data in one transaction.
  /// "Other" is added back for both types if the backup lacks it.
  Future<void> replaceAll(
    List<EntryCategory> categories,
    List<Entry> entries,
    List<Debt> debts,
    List<SavingsGoal> goals, {
    List<RecurringRule> recurring = const [],
    List<Favorite> favorites = const [],
  }) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.delete('entries');
      await txn.delete('categories');
      await txn.delete('debts');
      await txn.delete('goals');
      await txn.delete('recurring');
      await txn.delete('favorites');
      for (final r in recurring) {
        await txn.insert('recurring', r.toMap()..remove('id'));
      }
      for (final f in favorites) {
        await txn.insert('favorites', f.toMap()..remove('id'));
      }
      for (final d in debts) {
        await txn.insert('debts', d.toMap()..remove('id'));
      }
      for (final g in goals) {
        await txn.insert('goals', g.toMap()..remove('id'));
      }
      for (final c in categories) {
        await txn.insert(
          'categories',
          {
            'name': c.name,
            'type': c.type.name,
            'color': c.colorValue,
            'budget': c.budgetMinor,
            'position': c.position,
            'hidden': c.isOther ? 0 : (c.hidden ? 1 : 0),
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      for (final type in EntryType.values) {
        await txn.insert(
          'categories',
          {'name': kOtherCategory, 'type': type.name, 'color': 0xFF90A4AE},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      for (final e in entries) {
        final map = e.toMap()..remove('id');
        await txn.insert('entries', map);
      }
    });
  }
}
