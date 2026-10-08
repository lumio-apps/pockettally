import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'db.dart';
import 'models.dart';

/// Holds settings, entries and categories for the whole app.
class AppState extends ChangeNotifier {
  AppState(this._prefs);

  final SharedPreferences _prefs;

  List<Entry> entries = [];
  List<EntryCategory> categories = [];

  String get userName => _prefs.getString('user_name') ?? '';
  bool get onboarded => userName.isNotEmpty;

  Currency get currency =>
      currencyByCode(_prefs.getString('currency') ?? 'INR');

  ThemeMode get themeMode {
    switch (_prefs.getString('theme')) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> load() async {
    entries = await AppDatabase.instance.allEntries();
    categories = await AppDatabase.instance.allCategories();
    notifyListeners();
  }

  // ---- settings ----

  Future<void> completeOnboarding(String name, Currency currency) async {
    await _prefs.setString('user_name', name.trim());
    await _prefs.setString('currency', currency.code);
    notifyListeners();
  }

  Future<void> setUserName(String name) async {
    await _prefs.setString('user_name', name.trim());
    notifyListeners();
  }

  Future<void> setCurrency(Currency c) async {
    await _prefs.setString('currency', c.code);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs.setString('theme', mode.name);
    notifyListeners();
  }

  // ---- entries ----

  Future<void> addEntry(Entry e) async {
    await AppDatabase.instance.insert(e);
    await load();
  }

  Future<void> updateEntry(Entry e) async {
    await AppDatabase.instance.update(e);
    await load();
  }

  Future<void> deleteEntry(Entry e) async {
    // Remove from the list right away so a swiped tile leaves the tree
    // in the same frame, then delete from the database.
    entries = entries.where((x) => x.id != e.id).toList();
    notifyListeners();
    await AppDatabase.instance.delete(e.id!);
  }

  /// Puts a deleted entry back (same id), used by the Undo action.
  Future<void> restoreEntry(Entry e) async {
    await AppDatabase.instance.insert(e);
    await load();
  }

  // ---- categories ----

  /// Categories of one type, with "Other" always last.
  List<EntryCategory> categoriesFor(EntryType type) {
    final list = categories.where((c) => c.type == type).toList();
    list.sort((a, b) {
      if (a.isOther != b.isOther) return a.isOther ? 1 : -1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return list;
  }

  Color colorFor(String categoryName, EntryType type) {
    for (final c in categories) {
      if (c.name == categoryName && c.type == type) return c.color;
    }
    return const Color(0xFF90A4AE);
  }

  /// True if another category of this type already uses [name].
  bool categoryNameTaken(String name, EntryType type, {int? exceptId}) {
    final n = name.trim().toLowerCase();
    return categories.any((c) =>
        c.type == type && c.id != exceptId && c.name.toLowerCase() == n);
  }

  int entryCountFor(EntryCategory c) =>
      entries.where((e) => e.type == c.type && e.category == c.name).length;

  Future<void> addCategory(EntryCategory c) async {
    await AppDatabase.instance.insertCategory(c);
    await load();
  }

  Future<void> updateCategory(EntryCategory old, EntryCategory changed) async {
    await AppDatabase.instance.updateCategory(old, changed);
    await load();
  }

  Future<void> deleteCategory(EntryCategory c) async {
    await AppDatabase.instance.deleteCategory(c);
    await load();
  }

  // ---- summaries ----

  /// Entries with date in [start, end).
  List<Entry> entriesBetween(DateTime start, DateTime end) => entries
      .where((e) => !e.date.isBefore(start) && e.date.isBefore(end))
      .toList();

  Iterable<Entry> entriesInMonth(DateTime month) => entries
      .where((e) => e.date.year == month.year && e.date.month == month.month);

  int incomeIn(DateTime month) => sumIncome(entriesInMonth(month));

  int expenseIn(DateTime month) => sumExpense(entriesInMonth(month));

  static int sumIncome(Iterable<Entry> list) => list
      .where((e) => e.isIncome)
      .fold(0, (sum, e) => sum + e.amountMinor);

  static int sumExpense(Iterable<Entry> list) => list
      .where((e) => !e.isIncome)
      .fold(0, (sum, e) => sum + e.amountMinor);

  // ---- formatting ----

  String formatMoney(int minor) {
    final c = currency;
    final f = NumberFormat.currency(
        locale: c.locale, symbol: '${c.symbol} ', decimalDigits: 2);
    return f.format(minor / 100);
  }
}
