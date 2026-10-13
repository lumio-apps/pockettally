import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'utils/lock_guard.dart';

/// One planned Lend & Borrow notification.
class DebtReminder {
  const DebtReminder({
    required this.debtId,
    required this.at,
    required this.title,
    required this.body,
  });

  final int debtId;
  final DateTime at;
  final String title;
  final String body;
}

/// The daily "Did you spend anything today?" notification and the
/// Lend & Borrow reminders (Android only).
///
/// Daily reminders are planned for the next [_days] days at the chosen time
/// and planned again whenever data changes or the app opens, so a day with
/// an entry gets no reminder. Everything runs on the phone; nothing is sent
/// anywhere.
class ReminderService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool? _ready;

  static const int _firstId = 9100;
  static const int _testId = 9099;
  static const int _days = 7;
  static const String _channelId = 'daily_reminder';

  /// Lend & Borrow reminders use this id plus the record's id.
  static const int _debtBaseId = 1000000;
  static const String _debtChannelId = 'debt_reminders';

  /// Reminders are offered on Android only.
  static bool get supported => Platform.isAndroid;

  static Future<bool> _init() async {
    if (!supported) return false;
    if (_ready != null) return _ready!;
    try {
      final ok = await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_notify'),
        ),
      );
      _ready = ok ?? true;
    } catch (_) {
      // A broken notification setup must never stop the app.
      _ready = false;
    }
    return _ready!;
  }

  /// Asks for permission to show notifications (Android 13 and newer).
  /// Returns false when the user said no.
  static Future<bool> requestPermission() async {
    if (!await _init()) return false;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return false;
    final granted =
        await LockGuard.around(() => android.requestNotificationsPermission());
    return granted ?? true;
  }

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  /// True when reminders can come at the exact minute. Android 12 and
  /// newer ask the user for this ("Alarms & reminders"); without it Android
  /// may show a reminder up to an hour late.
  static Future<bool> canBeExact() async {
    if (!await _init()) return false;
    try {
      return await _android?.canScheduleExactNotifications() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens the phone's "Alarms & reminders" setting for the app. Returns
  /// true when it is allowed afterwards.
  static Future<bool> requestExact() async {
    if (!await _init()) return false;
    final android = _android;
    if (android == null) return false;
    try {
      await LockGuard.around(() => android.requestExactAlarmsPermission());
    } catch (_) {
      // Settings could not be opened.
    }
    return canBeExact();
  }

  /// Exact when allowed, else as close as Android allows.
  static Future<AndroidScheduleMode> _mode() async => await canBeExact()
      ? AndroidScheduleMode.exactAllowWhileIdle
      : AndroidScheduleMode.inexactAllowWhileIdle;

  /// Shows a notification right now, to check that reminders show and
  /// ring on this phone.
  static Future<bool> showTest({
    required String title,
    required String body,
    required String channelName,
  }) async {
    if (!await _init()) return false;
    try {
      await _plugin.show(
        id: _testId,
        title: title,
        body: body,
        notificationDetails: _debtDetails(channelName),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  static NotificationDetails _debtDetails(String channelName) =>
      NotificationDetails(
        android: AndroidNotificationDetails(
          _debtChannelId,
          channelName,
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
        ),
      );

  /// Cancels the planned daily reminders.
  static Future<void> cancelDaily() async {
    if (!await _init()) return;
    for (var i = 0; i < _days; i++) {
      await _plugin.cancel(id: _firstId + i);
    }
  }

  /// Cancels every planned notification of the app (used by "Reset").
  static Future<void> cancelAll() async {
    await cancelDaily();
    await _cancelDebtReminders();
  }

  static Future<void> _cancelDebtReminders() async {
    if (!await _init()) return;
    try {
      final pending = await _plugin.pendingNotificationRequests();
      for (final p in pending) {
        if (p.id >= _debtBaseId) await _plugin.cancel(id: p.id);
      }
    } catch (_) {
      // Nothing planned, or the list could not be read.
    }
  }

  /// Plans the Lend & Borrow reminders again: the old ones are cancelled
  /// and every reminder in [reminders] that is still to come is planned.
  static Future<void> syncDebts({
    required List<DebtReminder> reminders,
    required String channelName,
  }) async {
    if (!await _init()) return;
    await _cancelDebtReminders();
    final details = _debtDetails(channelName);
    final mode = await _mode();
    final now = DateTime.now();
    for (final r in reminders) {
      if (!r.at.isAfter(now)) continue;
      await _plugin.zonedSchedule(
        id: _debtBaseId + r.debtId,
        scheduledDate: tz.TZDateTime.from(r.at.toUtc(), tz.UTC),
        notificationDetails: details,
        androidScheduleMode: mode,
        title: r.title,
        body: r.body,
      );
    }
  }

  /// Plans the reminders again. [minutes] is the time of day (minutes after
  /// midnight); with [doneToday] today is skipped.
  static Future<void> sync({
    required bool on,
    required int minutes,
    required bool doneToday,
    required String title,
    required String body,
    required String channelName,
  }) async {
    if (!await _init()) return;
    await cancelDaily();
    if (!on) return;
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        channelName,
        category: AndroidNotificationCategory.reminder,
      ),
    );
    final mode = await _mode();
    final now = DateTime.now();
    for (var i = 0; i < _days; i++) {
      final at = DateTime(
          now.year, now.month, now.day + i, minutes ~/ 60, minutes % 60);
      if (!at.isAfter(now)) continue;
      if (i == 0 && doneToday) continue;
      await _plugin.zonedSchedule(
        id: _firstId + i,
        scheduledDate: tz.TZDateTime.from(at.toUtc(), tz.UTC),
        notificationDetails: details,
        androidScheduleMode: mode,
        title: title,
        body: body,
      );
    }
  }
}
