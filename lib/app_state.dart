import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' show PlatformDispatcher;

import 'package:crypto/crypto.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'android_extras.dart';
import 'backup.dart';
import 'category_icons.dart';
import 'db.dart';
import 'l10n/l10n.dart';
import 'models.dart';
import 'photo_store.dart';
import 'reminder.dart';
import 'theme.dart';
import 'utils/money_format.dart';

/// Holds settings, entries and categories for the whole app.
class AppState extends ChangeNotifier {
  AppState(this._prefs);

  final SharedPreferences _prefs;

  List<Entry> entries = [];

  /// The wallets, the main one first.
  List<Wallet> wallets = [];

  /// Money moved between wallets, newest first.
  List<Transfer> transfers = [];

  /// Deleted entries waiting in the Trash.
  List<TrashedEntry> trash = [];
  List<EntryCategory> categories = [];
  List<Debt> debts = [];
  List<SavingsGoal> goals = [];
  List<RecurringRule> recurring = [];
  List<Favorite> favorites = [];

  String get userName => _prefs.getString('user_name') ?? '';
  bool get onboarded => userName.isNotEmpty;

  /// File name of the profile photo (see PhotoStore), or null.
  String? get profilePhotoName => _prefs.getString('profile_photo');

  /// The profile photo, or null when none is set or the file is gone.
  File? get profilePhotoFile {
    final name = profilePhotoName;
    if (name == null) return null;
    final f = PhotoStore.profileFile(name);
    try {
      return f != null && f.existsSync() ? f : null;
    } catch (_) {
      return null;
    }
  }

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
    trash = await AppDatabase.instance.trashedEntries();
    wallets = await AppDatabase.instance.allWallets();
    transfers = await AppDatabase.instance.allTransfers();
    categories = await AppDatabase.instance.allCategories();
    debts = await AppDatabase.instance.allDebts();
    goals = await AppDatabase.instance.allGoals();
    recurring = await AppDatabase.instance.allRecurring();
    favorites = await AppDatabase.instance.allFavorites();
    notifyListeners();
    // A new entry for today means no reminder today.
    unawaited(syncReminder());
    unawaited(syncDebtReminders());
  }

  // ---- app lock ----

  /// True when the app asks for a PIN.
  bool get appLockOn => _prefs.getString('pin_hash') != null;

  /// Seconds in the background before the PIN is asked again (0 = always).
  int get lockAfterSeconds => _prefs.getInt('lock_after') ?? 0;

  /// Fingerprint or face unlock next to the PIN (only with the app lock).
  bool get biometricOn =>
      appLockOn && (_prefs.getBool('biometric_unlock') ?? false);

  Future<void> setBiometric(bool on) async {
    await _prefs.setBool('biometric_unlock', on);
    notifyListeners();
  }

  Future<void> setLockAfter(int seconds) async {
    await _prefs.setInt('lock_after', seconds);
    notifyListeners();
  }

  /// Wrong PINs in a row allowed before a pause.
  static const int pinTriesBeforeWait = 5;
  static const Duration pinWait = Duration(seconds: 30);

  /// The PIN is never stored, only a salted, repeated SHA-256 of it.
  static String hashPin(String pin, String salt) {
    List<int> bytes = utf8.encode('$salt:$pin');
    for (var i = 0; i < 10000; i++) {
      bytes = sha256.convert(bytes).bytes;
    }
    return base64Encode(bytes);
  }

  Future<void> setPin(String pin) async {
    final random = Random.secure();
    final salt = base64Encode(List<int>.generate(16, (_) => random.nextInt(256)));
    await _prefs.setString('pin_salt', salt);
    await _prefs.setString('pin_hash', hashPin(pin, salt));
    await _prefs.remove('pin_failures');
    await _prefs.remove('pin_wait_until');
    notifyListeners();
  }

  Future<void> removePin() async {
    await _prefs.remove('pin_hash');
    await _prefs.remove('biometric_unlock');
    await _prefs.remove('pin_salt');
    await _prefs.remove('pin_failures');
    await _prefs.remove('pin_wait_until');
    notifyListeners();
  }

  /// How long to wait before the next try (zero when trying is allowed).
  Duration get pinWaitLeft {
    final until = _prefs.getInt('pin_wait_until') ?? 0;
    final left = until - DateTime.now().millisecondsSinceEpoch;
    return left > 0 ? Duration(milliseconds: left) : Duration.zero;
  }

  /// Checks [pin]. After [pinTriesBeforeWait] wrong ones in a row the next
  /// try has to wait [pinWait]. Returns false while waiting.
  Future<bool> tryPin(String pin) async {
    if (pinWaitLeft > Duration.zero) return false;
    final salt = _prefs.getString('pin_salt') ?? '';
    final ok = hashPin(pin, salt) == _prefs.getString('pin_hash');
    if (ok) {
      await _prefs.remove('pin_failures');
      return true;
    }
    final failures = (_prefs.getInt('pin_failures') ?? 0) + 1;
    if (failures >= pinTriesBeforeWait) {
      await _prefs.setInt('pin_failures', 0);
      await _prefs.setInt('pin_wait_until',
          DateTime.now().add(pinWait).millisecondsSinceEpoch);
    } else {
      await _prefs.setInt('pin_failures', failures);
    }
    return false;
  }

  /// "Forgot PIN": deletes all data, photos and settings. The app starts
  /// again with the welcome screen.
  Future<void> resetEverything() async {
    await ReminderService.cancelAll();
    _plannedDebtReminders = null;
    await AppDatabase.instance.deleteEverything();
    await PhotoStore.deleteAll();
    await _prefs.clear();
    await load();
  }

  // ---- auto backup ----

  bool get autoBackupOn => _prefs.getBool('auto_backup_on') ?? false;

  /// 1 = every day, 7 = every week (default).
  int get autoBackupDays => _prefs.getInt('auto_backup_days') == 1 ? 1 : 7;

  /// Backups (manual and automatic) also carry the bill photos.
  bool get backupWithPhotos => _prefs.getBool('backup_photos') ?? false;

  DateTime? get lastAutoBackup {
    final ms = _prefs.getInt('auto_backup_last');
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// Where automatic backups go on this device (shown in the profile).
  String? get autoBackupFolder => _prefs.getString('auto_backup_dir');

  /// True when the last automatic backup could not be written.
  bool get autoBackupFailed => _prefs.getBool('auto_backup_failed') ?? false;

  Future<void> setAutoBackup({bool? on, int? days, bool? withPhotos}) async {
    if (on != null) await _prefs.setBool('auto_backup_on', on);
    if (days != null) await _prefs.setInt('auto_backup_days', days);
    if (withPhotos != null) await _prefs.setBool('backup_photos', withPhotos);
    notifyListeners();
  }

  Future<void> markAutoBackup({required bool ok, String? folder}) async {
    await _prefs.setBool('auto_backup_failed', !ok);
    if (ok) {
      await _prefs.setInt(
          'auto_backup_last', DateTime.now().millisecondsSinceEpoch);
    }
    if (folder != null) await _prefs.setString('auto_backup_dir', folder);
    notifyListeners();
  }

  // ---- daily reminder ----

  bool get reminderOn => _prefs.getBool('reminder_on') ?? false;

  /// Minutes after midnight, 21:00 by default.
  int get reminderMinutes => _prefs.getInt('reminder_minutes') ?? 21 * 60;

  Future<void> setReminder({bool? on, int? minutes}) async {
    if (on != null) await _prefs.setBool('reminder_on', on);
    if (minutes != null) await _prefs.setInt('reminder_minutes', minutes);
    notifyListeners();
    await syncReminder();
  }

  /// Plans the reminders for the next days again (Android only).
  Future<void> syncReminder() async {
    try {
      final l = lookupAppLocalizations(Locale(languageCode));
      final now = DateTime.now();
      await ReminderService.sync(
        on: reminderOn && onboarded,
        minutes: reminderMinutes,
        doneToday: entries.any((e) =>
            e.date.year == now.year &&
            e.date.month == now.month &&
            e.date.day == now.day),
        title: 'PocketTally',
        body: l.reminderBody,
        channelName: l.dailyReminder,
      );
    } catch (e) {
      debugPrint('Reminder not planned: $e');
    }
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

  /// Uses a photo stored by PhotoStore as the profile photo.
  Future<void> setProfilePhoto(String name) async {
    final old = profilePhotoName;
    await _prefs.setString('profile_photo', name);
    if (old != null && old != name) await PhotoStore.deleteProfile(old);
    notifyListeners();
  }

  Future<void> removeProfilePhoto() async {
    final old = profilePhotoName;
    await _prefs.remove('profile_photo');
    if (old != null) await PhotoStore.deleteProfile(old);
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
    trash = await AppDatabase.instance.trashedEntries();
    notifyListeners();
  }

  /// Puts a deleted entry back from the Trash, used by Undo and by the
  /// Trash screen.
  Future<void> restoreEntry(Entry e) async {
    await AppDatabase.instance.restoreFromTrash(e.id!);
    await load();
  }

  /// Removes one entry from the Trash for good (and its bill photo).
  Future<void> deleteForever(Entry e) async {
    await AppDatabase.instance.deleteForever(e.id!);
    await _afterTrashChange();
  }

  Future<void> emptyTrash() async {
    await AppDatabase.instance.purgeTrash();
    await _afterTrashChange();
  }

  /// At start-up: removes what has been in the Trash for [kTrashDays] days.
  Future<void> purgeOldTrash() async {
    final cutoff = DateTime.now().subtract(const Duration(days: kTrashDays));
    await AppDatabase.instance.purgeTrash(cutoff: cutoff);
    trash = await AppDatabase.instance.trashedEntries();
  }

  /// Bill photos that an entry or a Trash item still needs.
  Set<String> get usedPhotos => {
        ...entries.map((e) => e.photo),
        ...trash.map((t) => t.entry.photo),
      }.whereType<String>().toSet();

  Future<void> _afterTrashChange() async {
    trash = await AppDatabase.instance.trashedEntries();
    notifyListeners();
    await PhotoStore.cleanOrphans(usedPhotos);
  }

  // ---- wallets ----

  /// The first wallet: entries without a wallet belong to it.
  Wallet get mainWallet => wallets.firstWhere((w) => w.main,
      orElse: () => wallets.isNotEmpty
          ? wallets.first
          : Wallet(name: kMainWalletName, colorValue: 0xFF81C784, main: true));

  /// The wallet name an entry belongs to (an unknown name counts as main).
  String walletNameOf(Entry e) {
    final name = e.wallet;
    if (name == null) return mainWallet.name;
    for (final w in wallets) {
      if (w.name == name) return w.name;
    }
    return mainWallet.name;
  }

  /// What is in a wallet now: its opening balance plus income minus expense.
  int walletBalance(Wallet w) {
    var sum = w.openingMinor;
    for (final e in entries) {
      if (walletNameOf(e) != w.name) continue;
      sum += e.isIncome ? e.amountMinor : -e.amountMinor;
    }
    for (final t in transfers) {
      if (t.from == w.name) sum -= t.amountMinor;
      if (t.to == w.name) sum += t.amountMinor;
    }
    return sum;
  }

  /// Entries of one wallet, or all of them when [wallet] is null.
  List<Entry> entriesOfWallet(String? wallet) => wallet == null
      ? entries
      : entries.where((e) => walletNameOf(e) == wallet).toList();

  Future<void> addTransfer(Transfer t) async {
    await AppDatabase.instance.insertTransfer(t);
    await load();
  }

  Future<void> deleteTransfer(Transfer t) async {
    await AppDatabase.instance.deleteTransfer(t.id!);
    await load();
  }

  /// Brings a deleted transfer back (Undo).
  Future<void> restoreTransfer(Transfer t) async {
    await AppDatabase.instance.insertTransfer(t);
    await load();
  }

  Wallet walletNamed(String name) =>
      wallets.firstWhere((w) => w.name == name, orElse: () => mainWallet);

  /// The wallet a new entry starts with: the one used last, else the main.
  String get defaultWalletName {
    final last = _prefs.getString('last_wallet');
    return last != null && wallets.any((w) => w.name == last)
        ? last
        : mainWallet.name;
  }

  Future<void> setLastWallet(String name) =>
      _prefs.setString('last_wallet', name);

  /// True when another wallet already has [name] (letter case ignored).
  bool walletNameTaken(String name, {Wallet? except}) => wallets.any((w) =>
      w.id != except?.id && w.name.toLowerCase() == name.trim().toLowerCase());

  Future<void> addWallet(Wallet w) async {
    await AppDatabase.instance.insertWallet(w);
    await load();
  }

  Future<void> updateWallet(Wallet old, Wallet changed) async {
    await AppDatabase.instance.updateWallet(old, changed);
    final last = _prefs.getString('last_wallet');
    if (last == old.name) await _prefs.setString('last_wallet', changed.name);
    await load();
  }

  Future<void> deleteWallet(Wallet w) async {
    await AppDatabase.instance.deleteWallet(w);
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

  /// Category of the last new entry of this type, used as the default
  /// for the next one.
  String? lastCategory(EntryType type) =>
      _prefs.getString('last_category_${type.name}');

  Future<void> setLastCategory(EntryType type, String name) =>
      _prefs.setString('last_category_${type.name}', name);

  /// The category of this name and type, or null if it does not exist.
  EntryCategory? categoryRecord(String name, EntryType type) {
    for (final c in categories) {
      if (c.name == name && c.type == type) return c;
    }
    return null;
  }

  /// The icon of a category: the one chosen for it, else one that fits
  /// its name.
  IconData iconFor(String categoryName, EntryType type) => categoryIcon(
      categoryName,
      chosen: categoryRecord(categoryName, type)?.icon);

  /// The categories used most in the last 90 days, for one-tap picking.
  /// Filled up with the user's category order when there are few entries.
  List<String> topCategories(EntryType type, {int count = 6}) {
    final since = DateTime.now().subtract(const Duration(days: 90));
    final visible =
        categoriesFor(type, includeHidden: false).map((c) => c.name).toList();
    final uses = <String, int>{};
    for (final e in entries) {
      if (e.type != type || e.date.isBefore(since)) continue;
      if (!visible.contains(e.category)) continue;
      uses[e.category] = (uses[e.category] ?? 0) + 1;
    }
    final top = uses.keys.toList()
      ..sort((a, b) => uses[b]!.compareTo(uses[a]!));
    for (final name in visible) {
      if (top.length >= count) break;
      if (!top.contains(name)) top.add(name);
    }
    return top.take(count).toList();
  }

  // ---- home screen widgets (Android) ----

  /// What the widgets show now, so they are only redrawn on a change.
  String? _widgetTexts;

  /// Every change of data or settings may change what the widgets show.
  @override
  void notifyListeners() {
    super.notifyListeners();
    unawaited(syncWidget());
  }

  /// Saves the texts for the home screen widgets (this month's balance,
  /// income and expenses, in the app's language and money format) and
  /// redraws them. Nothing happens when nothing changed.
  Future<void> syncWidget() async {
    if (!AndroidExtras.supported) return;
    try {
      final l = lookupAppLocalizations(Locale(languageCode));
      final now = DateTime.now();
      final income = incomeIn(now);
      final expense = expenseIn(now);
      final hide = hideBalance;
      final compact = NumberFormat.compact(locale: currency.locale);
      final texts = <String, String>{
        'widget_title': l.monthBalance(DateFormat.MMMM().format(now)),
        'widget_balance': hide ? '••••••' : formatMoney(income - expense),
        'widget_balance_short': hide
            ? '••••'
            : '${currency.symbol} ${compact.format((income - expense) / 100)}',
        'widget_income': hide ? '••••' : '+ ${formatMoney(income)}',
        'widget_expense': hide ? '••••' : '− ${formatMoney(expense)}',
        'widget_label_expense': '− ${l.expense}',
        'widget_label_income': '+ ${l.income}',
      };
      final joined = texts.values.join('\n');
      if (joined == _widgetTexts) return;
      _widgetTexts = joined;
      for (final t in texts.entries) {
        await _prefs.setString(t.key, t.value);
      }
      await AndroidExtras.updateWidgets();
    } catch (e) {
      _widgetTexts = null;
      debugPrint('Widgets not updated: $e');
    }
  }

  /// The PDF report choices remembered from last time (see ReportOptions).
  String? get pdfOptions => _prefs.getString('pdf_options');

  Future<void> setPdfOptions(String json) =>
      _prefs.setString('pdf_options', json);

  /// Hide the balance on Home (the eye button), e.g. in public.
  bool get hideBalance => _prefs.getBool('hide_balance') ?? false;

  /// Flat panels without soft shadows and movement (older phones).
  bool get reduceEffects => _prefs.getBool('reduce_effects') ?? false;

  Future<void> setReduceEffects(bool on) async {
    await _prefs.setBool('reduce_effects', on);
    notifyListeners();
  }

  Future<void> setHideBalance(bool hide) async {
    await _prefs.setBool('hide_balance', hide);
    notifyListeners();
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
  /// With [wallet], only the entries of that wallet.
  List<Entry> entriesBetween(DateTime start, DateTime end, {String? wallet}) =>
      entries
          .where((e) =>
              !e.date.isBefore(start) &&
              e.date.isBefore(end) &&
              (wallet == null || walletNameOf(e) == wallet))
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

  /// Whether unused monthly budget is added to the next month.
  bool get budgetRollover => _prefs.getBool('budget_rollover') ?? false;

  Future<void> setBudgetRollover(bool on) async {
    await _prefs.setBool('budget_rollover', on);
    notifyListeners();
  }

  /// Monthly budget left unused in the month before [month], added to
  /// [month] when carry-over is on. Only the month just before counts (no
  /// piling up), and only if the app was used in it.
  int carriedOverInto(DateTime month) {
    final base = monthlyBudgetMinor;
    if (!budgetRollover || base <= 0) return 0;
    final prev = DateTime(month.year, month.month - 1, 1);
    if (entriesInMonth(prev).isEmpty) return 0;
    final left = base - expenseIn(prev);
    return left > 0 ? left : 0;
  }

  /// The monthly limit for [month], with any carried-over budget.
  int monthlyLimitFor(DateTime month) =>
      monthlyBudgetMinor <= 0 ? 0 : monthlyBudgetMinor + carriedOverInto(month);

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
    final limit = monthlyLimitFor(e.date);
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

  /// Everything for a backup file; [withPhotos] also packs the bill photos.
  BackupData createBackup({bool withPhotos = false}) => BackupData(
        photos: withPhotos ? _billPhotos() : const {},
        userName: userName,
        currencyCode: currency.code,
        weekStartsOnSunday: weekStartsOnSunday,
        monthlyBudgetMinor: monthlyBudgetMinor,
        numberStyle: numberStyleSetting.name,
        decimals: decimalsSetting,
        palette: palette.id,
        profilePhoto: _profilePhotoBytes(),
        categories: categories,
        entries: entries,
        debts: debts,
        goals: goals,
        recurring: recurring,
        favorites: favorites,
        wallets: wallets,
        transfers: transfers,
      );

  /// File names of the bill photos that exist on the phone. Used to write a
  /// backup photo by photo (see BackupData.writeToFile).
  Set<String> billPhotoNames() => {
        for (final e in entries)
          if (e.photo != null && PhotoStore.file(e.photo!)?.existsSync() == true)
            e.photo!,
      };

  Map<String, List<int>> _billPhotos() {
    final photos = <String, List<int>>{};
    for (final e in entries) {
      final name = e.photo;
      if (name == null || photos.containsKey(name)) continue;
      final bytes = PhotoStore.readBill(name);
      if (bytes != null) photos[name] = bytes;
    }
    return photos;
  }

  List<int>? _profilePhotoBytes() {
    try {
      return profilePhotoFile?.readAsBytesSync();
    } catch (_) {
      return null;
    }
  }

  /// Replaces all data and settings with the backup.
  Future<void> restoreBackup(BackupData b) async {
    for (final p in b.photos.entries) {
      try {
        await PhotoStore.writeBill(p.key, p.value);
      } catch (_) {}
    }
    await AppDatabase.instance
        .replaceAll(b.categories, b.entries, b.debts, b.goals,
            recurring: b.recurring,
            favorites: b.favorites,
            wallets: b.wallets,
            transfers: b.transfers);
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
    // A backup without a photo keeps the photo already on this device.
    final photo = b.profilePhoto;
    if (photo != null && photo.isNotEmpty) {
      try {
        await setProfilePhoto(await PhotoStore.saveProfileBytes(photo));
      } catch (_) {}
    }
    await load();
  }

  // ---- recurring entries ----

  /// The run in progress, so two calls (start-up and resume) never add
  /// the same entries twice.
  Future<int>? _recurringRun;

  /// Adds every entry that is due up to [today] and moves the rules on.
  /// Returns how many entries were added. Safe to call often: a call made
  /// while another is running waits for it instead of starting again.
  Future<int> runRecurring({DateTime? today}) {
    final running = _recurringRun;
    if (running != null) return running;
    final run = _runRecurring(today);
    _recurringRun = run;
    return run.whenComplete(() => _recurringRun = null);
  }

  Future<int> _runRecurring(DateTime? today) async {
    final now = today ?? DateTime.now();
    final end = DateTime(now.year, now.month, now.day);
    var added = 0;
    for (final rule in recurring) {
      if (rule.paused || rule.id == null) continue;
      var next = rule.nextDate;
      final due = <Entry>[];
      // At most ~3 years of daily entries in one go, as a safety limit.
      while (!next.isAfter(end) && due.length < 1100) {
        due.add(rule.entryOn(next));
        next = nextRepeatDate(next, rule.every, rule.anchorDay);
      }
      if (due.isEmpty) continue;
      await AppDatabase.instance
          .applyRecurring(rule.copyWith(nextDate: next), due);
      added += due.length;
    }
    if (added > 0) await load();
    return added;
  }

  /// Saves [e] and repeats it [every] day/week/month/year from now on.
  Future<void> addRecurringFrom(Entry e, RepeatEvery every) async {
    await AppDatabase.instance.saveRecurring(RecurringRule.fromEntry(e, every));
    recurring = await AppDatabase.instance.allRecurring();
    // A run that started before this rule existed would not see it.
    final running = _recurringRun;
    if (running != null) await running;
    await runRecurring();
    notifyListeners();
  }

  Future<void> setRecurringPaused(RecurringRule r, bool paused) async {
    var rule = r.copyWith(paused: paused);
    if (!paused) {
      // Resuming does not add the entries missed while paused.
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      var next = rule.nextDate;
      while (next.isBefore(today)) {
        next = nextRepeatDate(next, rule.every, rule.anchorDay);
      }
      rule = rule.copyWith(nextDate: next);
    }
    await AppDatabase.instance.saveRecurring(rule);
    await load();
  }

  Future<void> deleteRecurring(RecurringRule r) async {
    await AppDatabase.instance.deleteRecurring(r.id!);
    await load();
  }

  // ---- favorites ----

  Future<void> addFavorite(Favorite f) async {
    await AppDatabase.instance.insertFavorite(f);
    await load();
  }

  Future<void> deleteFavorite(Favorite f) async {
    await AppDatabase.instance.deleteFavorite(f.id!);
    await load();
  }

  /// Adds the favorite as an entry for today and returns it (for Undo).
  Future<Entry> addFromFavorite(Favorite f) async {
    final now = DateTime.now();
    final e = f.entryOn(now, minutes: now.hour * 60 + now.minute);
    final id = await AppDatabase.instance.insert(e);
    await load();
    return entries.firstWhere((x) => x.id == id, orElse: () => e);
  }

  // ---- CSV import ----

  /// Adds imported entries; categories they use that do not exist yet are
  /// created. A name that differs only in letter case ("food" vs "Food")
  /// uses the existing category. Existing data is kept.
  Future<void> importEntries(List<Entry> list) async {
    var colorIndex = categories.length;
    final fixed = <Entry>[];
    for (final type in EntryType.values) {
      // Lower-case name -> the exact name to use.
      final names = {
        for (final c in categories.where((c) => c.type == type))
          c.name.toLowerCase(): c.name,
      };
      for (final e in list.where((e) => e.type == type)) {
        final key = e.category.trim().toLowerCase();
        var name = names[key];
        if (name == null) {
          name = e.category.trim();
          names[key] = name;
          await AppDatabase.instance.insertCategory(EntryCategory(
            name: name,
            type: type,
            colorValue: kCategoryPalette[colorIndex++ % kCategoryPalette.length],
          ));
        }
        fixed.add(name == e.category ? e : _withCategory(e, name));
      }
    }
    // Wallet names from the file: a name that differs only in letter case
    // uses the existing wallet; a new name creates a wallet.
    final walletNames = {for (final w in wallets) w.name.toLowerCase(): w.name};
    var walletColor = wallets.length;
    for (var i = 0; i < fixed.length; i++) {
      final raw = fixed[i].wallet?.trim() ?? '';
      if (raw.isEmpty) {
        if (fixed[i].wallet != null) fixed[i] = _withWallet(fixed[i], null);
        continue;
      }
      var name = walletNames[raw.toLowerCase()];
      if (name == null) {
        name = raw;
        walletNames[raw.toLowerCase()] = name;
        await AppDatabase.instance.insertWallet(Wallet(
          name: name,
          colorValue: kCategoryPalette[walletColor++ % kCategoryPalette.length],
        ));
      }
      if (name != fixed[i].wallet) fixed[i] = _withWallet(fixed[i], name);
    }
    await AppDatabase.instance.insertAll(fixed);
    await load();
  }

  static Entry _withWallet(Entry e, String? wallet) => Entry(
        type: e.type,
        amountMinor: e.amountMinor,
        category: e.category,
        date: e.date,
        note: e.note,
        period: e.period,
        photo: e.photo,
        tags: e.tags,
        minutes: e.minutes,
        wallet: wallet,
      );

  static Entry _withCategory(Entry e, String category) => Entry(
        type: e.type,
        amountMinor: e.amountMinor,
        category: category,
        date: e.date,
        note: e.note,
        period: e.period,
        photo: e.photo,
        tags: e.tags,
        minutes: e.minutes,
        wallet: e.wallet,
      );

  // ---- tags ----

  /// Every tag used so far, most used first.
  List<String> get allTags {
    final count = <String, int>{};
    for (final e in entries) {
      for (final t in e.tags) {
        count[t] = (count[t] ?? 0) + 1;
      }
    }
    final list = count.keys.toList()
      ..sort((a, b) => count[b]!.compareTo(count[a]!));
    return list;
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

  /// Adds several records at once (split bill).
  Future<void> addDebts(List<Debt> list) async {
    for (final d in list) {
      await AppDatabase.instance.saveDebt(d);
    }
    await load();
  }

  /// People from earlier Lend & Borrow records, most recent first, for
  /// quick picking.
  List<String> get knownPeople {
    final seen = <String>{};
    final names = <String>[];
    for (final d in debts) {
      final key = d.person.trim().toLowerCase();
      if (key.isEmpty || !seen.add(key)) continue;
      names.add(d.person.trim());
    }
    return names;
  }

  /// What was planned last time, so the same plan is not made again.
  String? _plannedDebtReminders;

  /// The planning in progress; a new one waits for it, so two never mix.
  Future<void>? _debtSync;

  /// Plans the Lend & Borrow notifications again (Android only). Cheap to
  /// call often: nothing happens when the plan did not change.
  Future<void> syncDebtReminders() {
    if (!ReminderService.supported) return Future<void>.value();
    final run = (_debtSync ?? Future<void>.value())
        .then((_) => _syncDebtReminders());
    _debtSync = run;
    return run;
  }

  Future<void> _syncDebtReminders() async {
    try {
      final l = lookupAppLocalizations(Locale(languageCode));
      final now = DateTime.now();
      final list = <DebtReminder>[
        for (final d in debts)
          if (d.id != null && d.hasUpcomingReminder(now))
            DebtReminder(
              debtId: d.id!,
              at: d.remindAt!,
              title: l.lendAndBorrow,
              body: debtReminderText(l, d),
            ),
      ];
      // Planned again when on-time reminders get allowed.
      final exact = await ReminderService.canBeExact();
      final plan = [
        '${l.debtReminders}|$exact',
        for (final r in list)
          '${r.debtId}|${r.at.millisecondsSinceEpoch}|${r.body}',
      ].join('\n');
      if (plan == _plannedDebtReminders) return;
      _plannedDebtReminders = plan;
      await ReminderService.syncDebts(
          reminders: list, channelName: l.debtReminders);
    } catch (e) {
      _plannedDebtReminders = null;
      debugPrint('Lend & Borrow reminders not planned: $e');
    }
  }

  /// "Rahul owes you ₹ 500. Time to ask for it?" (and the note, if any).
  String debtReminderText(AppLocalizations l, Debt d) {
    final amount = formatMoney(d.remainingMinor);
    final text = d.type == DebtType.lent
        ? l.debtReminderLent(d.person, amount)
        : l.debtReminderBorrowed(d.person, amount);
    return d.note.isEmpty ? text : '$text (${d.note})';
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
