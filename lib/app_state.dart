import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backup.dart';
import 'db.dart';
import 'l10n/l10n.dart';
import 'models.dart';
import 'theme.dart';
import 'utils/money_format.dart';

/// Holds settings, entries and categories for the whole app.
class AppState extends ChangeNotifier {
  AppState(this._prefs);

  final SharedPreferences _prefs;

  List<Entry> entries = [];
  List<EntryCategory> categories = [];
  List<Debt> debts = [];
  List<SavingsGoal> goals = [];

  String get userName => _prefs.getString('user_name') ?? '';
  bool get onboarded => userName.isNotEmpty;

  Currency get currency =>
      currencyByCode(_prefs.getString('currency') ?? 'INR');

  /// Language chosen by the user, or null (= follow the device).
  String? get languageSetting => _prefs.getString('language');

  /// Language the app is shown in: the user's choice, else the device
  /// language if the app has it, else English.
  String get languageCode {
    final chosen = languageSetting;
    if (chosen != null && kLanguages.any((l) => l.code == chosen)) {
      return chosen;
    }
    return deviceLanguageCode;
  }

  static String get deviceLanguageCode {
    final device = PlatformDispatcher.instance.locale.languageCode;
    return kLanguages.any((l) => l.code == device) ? device : 'en';
  }

  /// A currency that fits the device's region, for the welcome screen.
  static Currency get suggestedCurrency =>
      currencyForCountry(PlatformDispatcher.instance.locale.countryCode);

  /// Weeks start on Monday unless the user picks Sunday.
  bool get weekStartsOnSunday => _prefs.getString('week_start') == 'sunday';

  /// Overall monthly spending limit in minor units, 0 = not set.
  int get monthlyBudgetMinor => _prefs.getInt('monthly_budget') ?? 0;

  /// Number format setting; [NumberStyle.auto] follows the currency.
  NumberStyle get numberStyleSetting {
    final name = _prefs.getString('number_style');
    return NumberStyle.values
        .firstWhere((s) => s.name == name, orElse: () => NumberStyle.auto);
  }

  /// Decimal places setting: -1 = automatic (by currency), 0 or 2.
  int get decimalsSetting {
    final d = _prefs.getInt('decimals');
    return d == 0 || d == 2 ? d! : -1;
  }

  /// Formatter for the current currency and settings.
  MoneyFormatter get money => MoneyFormatter(
        style: numberStyleSetting == NumberStyle.auto
            ? currency.numberStyle
            : numberStyleSetting,
        decimals: decimalsSetting == -1 ? currency.decimals : decimalsSetting,
      );

  /// Color theme of the app (dark green by default).
  AppPalette get palette => paletteById(_prefs.getString('palette'));

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
    debts = await AppDatabase.instance.allDebts();
    goals = await AppDatabase.instance.allGoals();
    notifyListeners();
  }

  // ---- settings ----

  Future<void> completeOnboarding(String name, Currency currency) async {
    await _prefs.setString('user_name', name.trim());
    await _prefs.setString('currency', currency.code);
    notifyListeners();
  }

  Future<void> setLanguage(String code) async {
    await _prefs.setString('language', code);
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

  Future<void> setWeekStartsOnSunday(bool sunday) async {
    await _prefs.setString('week_start', sunday ? 'sunday' : 'monday');
    notifyListeners();
  }

  Future<void> setMonthlyBudget(int minor) async {
    if (minor <= 0) {
      await _prefs.remove('monthly_budget');
    } else {
      await _prefs.setInt('monthly_budget', minor);
    }
    notifyListeners();
  }

  Future<void> setNumberStyle(NumberStyle style) async {
    await _prefs.setString('number_style', style.name);
    notifyListeners();
  }

  /// -1 = automatic, 0 = whole numbers, 2 = two decimals.
  Future<void> setDecimals(int decimals) async {
    await _prefs.setInt('decimals', decimals);
    notifyListeners();
  }

  Future<void> setPalette(AppPalette p) async {
    await _prefs.setString('palette', p.id);
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

  /// Categories of one type in the user's order, with "Other" always last.
  /// Without [includeHidden], hidden ones are left out (except [keep],
  /// e.g. the category of the entry being edited).
  List<EntryCategory> categoriesFor(
    EntryType type, {
    bool includeHidden = true,
    String? keep,
  }) {
    final list = categories
        .where((c) =>
            c.type == type && (includeHidden || !c.hidden || c.name == keep))
        .toList();
    list.sort((a, b) {
      if (a.isOther != b.isOther) return a.isOther ? 1 : -1;
      if (a.position != b.position) return a.position.compareTo(b.position);
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return list;
  }

  /// Saves a new order for the categories of one type ("Other" stays last).
  Future<void> reorderCategories(List<EntryCategory> ordered) async {
    final withoutOther = ordered.where((c) => !c.isOther).toList();
    // Update the list in memory first so the dragged tile stays put.
    final positions = {
      for (var i = 0; i < withoutOther.length; i++) withoutOther[i].id: i + 1,
    };
    categories = [
      for (final c in categories)
        positions.containsKey(c.id) ? c.copyWith(position: positions[c.id]) : c,
    ];
    notifyListeners();
    await AppDatabase.instance.reorderCategories(withoutOther);
  }

  Future<void> setCategoryHidden(EntryCategory c, bool hidden) async {
    if (c.isOther) return;
    await AppDatabase.instance.updateCategory(c, c.copyWith(hidden: hidden));
    await load();
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

  /// Adds a category at the end of the user's order (or alphabetically,
  /// if the order was never changed).
  Future<void> addCategory(EntryCategory c) async {
    final last = categories
        .where((x) => x.type == c.type)
        .fold<int>(0, (m, x) => x.position > m ? x.position : m);
    await AppDatabase.instance
        .insertCategory(c.copyWith(position: last == 0 ? 0 : last + 1));
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

  /// First day of the week containing [day], using the week-start setting.
  DateTime startOfWeek(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    final back = weekStartsOnSunday ? d.weekday % 7 : d.weekday - 1;
    return DateTime(d.year, d.month, d.day - back);
  }

  // ---- budgets ----

  /// Expenses of one category in the month of [month].
  int expenseForCategory(String name, DateTime month) => entriesInMonth(month)
      .where((e) => !e.isIncome && e.category == name)
      .fold(0, (sum, e) => sum + e.amountMinor);

  /// Expense categories with a limit, in display order.
  List<EntryCategory> get budgetedCategories =>
      categoriesFor(EntryType.expense).where((c) => c.hasBudget).toList();

  /// Categories whose spending in [month] is over their limit.
  List<EntryCategory> overBudgetCategories(DateTime month) => budgetedCategories
      .where((c) => expenseForCategory(c.name, month) > c.budgetMinor!)
      .toList();

  /// A short warning when [e] (just saved) pushed a budget over its limit.
  String? budgetWarningFor(Entry e, AppLocalizations l) {
    if (e.isIncome) return null;
    final warnings = <String>[];
    for (final c in budgetedCategories) {
      if (c.name != e.category) continue;
      final spent = expenseForCategory(c.name, e.date);
      if (spent > c.budgetMinor!) {
        warnings.add(l.warningCategoryOver(categoryLabel(l, c.name),
            formatMoney(spent), formatMoney(c.budgetMinor!)));
      }
    }
    final limit = monthlyBudgetMinor;
    if (limit > 0) {
      final spent = expenseIn(e.date);
      if (spent > limit) {
        warnings.add(
            l.warningMonthlyOver(formatMoney(spent), formatMoney(limit)));
      }
    }
    return warnings.isEmpty ? null : warnings.join('\n');
  }

  // ---- backup / restore ----

  BackupData createBackup() => BackupData(
        userName: userName,
        currencyCode: currency.code,
        weekStartsOnSunday: weekStartsOnSunday,
        monthlyBudgetMinor: monthlyBudgetMinor,
        numberStyle: numberStyleSetting.name,
        decimals: decimalsSetting,
        palette: palette.id,
        categories: categories,
        entries: entries,
        debts: debts,
        goals: goals,
      );

  /// Replaces all data and settings with the backup.
  Future<void> restoreBackup(BackupData b) async {
    await AppDatabase.instance
        .replaceAll(b.categories, b.entries, b.debts, b.goals);
    if (b.userName.trim().isNotEmpty) {
      await _prefs.setString('user_name', b.userName.trim());
    }
    await _prefs.setString('currency', currencyByCode(b.currencyCode).code);
    await _prefs.setString(
        'week_start', b.weekStartsOnSunday ? 'sunday' : 'monday');
    if (b.monthlyBudgetMinor > 0) {
      await _prefs.setInt('monthly_budget', b.monthlyBudgetMinor);
    } else {
      await _prefs.remove('monthly_budget');
    }
    if (b.numberStyle != null) {
      await _prefs.setString('number_style', b.numberStyle!);
    }
    if (b.decimals != null) await _prefs.setInt('decimals', b.decimals!);
    if (b.palette != null) await _prefs.setString('palette', b.palette!);
    await load();
  }

  // ---- lend & borrow ----

  /// Total still to get back from people.
  int get toReceiveMinor => debts
      .where((d) => d.type == DebtType.lent)
      .fold(0, (s, d) => s + d.remainingMinor);

  /// Total still to pay back to people.
  int get toPayMinor => debts
      .where((d) => d.type == DebtType.borrowed)
      .fold(0, (s, d) => s + d.remainingMinor);

  Future<void> saveDebt(Debt d) async {
    await AppDatabase.instance.saveDebt(d);
    await load();
  }

  Future<void> deleteDebt(Debt d) async {
    await AppDatabase.instance.deleteDebt(d.id!);
    await load();
  }

  // ---- savings goals ----

  Future<void> saveGoal(SavingsGoal g) async {
    await AppDatabase.instance.saveGoal(g);
    await load();
  }

  Future<void> deleteGoal(SavingsGoal g) async {
    await AppDatabase.instance.deleteGoal(g.id!);
    await load();
  }

  // ---- formatting ----

  /// "₹ 1,23,456.00" — or with another [symbol], e.g. the currency code.
  String formatMoney(int minor, {String? symbol}) =>
      money.money(minor, symbol ?? currency.symbol);

  /// Parses an amount field (with calculator support) into minor units.
  /// Returns null when empty or invalid.
  int? parseMinor(String text) {
    final v = money.parse(text);
    return v == null ? null : money.toMinor(v);
  }

  /// Text to put in an amount field when editing, e.g. "12.5".
  String amountInput(int minor) => money.input(minor);
}
