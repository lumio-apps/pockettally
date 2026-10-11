import 'dart:async';
import 'dart:io';
import 'dart:ui' show Locale;

import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:quick_actions/quick_actions.dart';

import 'app_state.dart';
import 'l10n/l10n.dart';
import 'models.dart';

/// Android-only extras: launcher shortcuts ("Add expense" when you
/// long-press the app icon) and the home screen balance widget.
/// Everything here does nothing on other platforms.
class AndroidExtras {
  static const _widgetProvider = 'com.lumio.pockettally.BalanceWidgetProvider';

  static bool get _enabled => Platform.isAndroid;

  /// Sets up the launcher shortcuts; [onAdd] opens the entry form.
  static void initShortcuts(
      AppLocalizations l, void Function(EntryType type) onAdd) {
    if (!_enabled) return;
    try {
      const actions = QuickActions();
      actions.initialize((type) {
        if (type == 'add_expense') onAdd(EntryType.expense);
        if (type == 'add_income') onAdd(EntryType.income);
      });
      actions.setShortcutItems([
        ShortcutItem(
            type: 'add_expense',
            localizedTitle: l.addExpense,
            icon: 'ic_shortcut_expense'),
        ShortcutItem(
            type: 'add_income',
            localizedTitle: l.addIncome,
            icon: 'ic_shortcut_income'),
      ]);
    } catch (_) {
      // Shortcuts are a convenience; never block the app.
    }
  }

  /// Calls [onAdd] when the app was opened with the widget's + button,
  /// now or later. Returns the subscription to cancel.
  static StreamSubscription<Uri?>? listenWidgetAdd(void Function() onAdd) {
    if (!_enabled) return null;
    bool isAdd(Uri? uri) => uri?.host == 'add';
    try {
      HomeWidget.initiallyLaunchedFromHomeWidget().then((uri) {
        if (isAdd(uri)) onAdd();
      }).catchError((_) {});
      return HomeWidget.widgetClicked.listen((uri) {
        if (isAdd(uri)) onAdd();
      }, onError: (_) {});
    } catch (_) {
      return null;
    }
  }

  static String? _lastWidgetText;

  /// Writes this month's balance to the home screen widget.
  static Future<void> updateWidget(AppState state) async {
    if (!_enabled) return;
    try {
      final lang = state.languageCode;
      final l = lookupAppLocalizations(Locale(lang));
      final now = DateTime.now();
      final income = state.incomeIn(now);
      final expense = state.expenseIn(now);
      final title = l.monthBalance(DateFormat.MMMM(lang).format(now));
      final balance = state.formatMoney(income - expense);
      final detail =
          '+ ${state.formatMoney(income)}   − ${state.formatMoney(expense)}';
      final text = '$title|$balance|$detail';
      if (text == _lastWidgetText) return;
      _lastWidgetText = text;
      await HomeWidget.saveWidgetData<String>('title', title);
      await HomeWidget.saveWidgetData<String>('balance', balance);
      await HomeWidget.saveWidgetData<String>('detail', detail);
      await HomeWidget.updateWidget(qualifiedAndroidName: _widgetProvider);
    } catch (_) {
      _lastWidgetText = null;
    }
  }
}
