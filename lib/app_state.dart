import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'db.dart';
import 'models.dart';

/// Holds settings and entries for the whole app.
class AppState extends ChangeNotifier {
  AppState(this._prefs);

  final SharedPreferences _prefs;

  List<Entry> entries = [];

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
    notifyListeners();
  }

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

  // ---- summaries ----

  Iterable<Entry> entriesInMonth(DateTime month) => entries
      .where((e) => e.date.year == month.year && e.date.month == month.month);

  int incomeIn(DateTime month) => entriesInMonth(month)
      .where((e) => e.isIncome)
      .fold(0, (sum, e) => sum + e.amountMinor);

  int expenseIn(DateTime month) => entriesInMonth(month)
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
