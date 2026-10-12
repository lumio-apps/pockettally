import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'utils/lock_guard.dart';

/// The daily "Did you spend anything today?" notification (Android only).
///
/// Reminders are planned for the next [_days] days at the chosen time and
/// planned again whenever data changes or the app opens, so a day with an
/// entry gets no reminder. Everything runs on the phone; nothing is sent
/// anywhere.
class ReminderService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool? _ready;

  static const int _firstId = 9100;
  static const int _days = 7;
  static const String _channelId = 'daily_reminder';

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

  static Future<void> cancelAll() async {
    if (!await _init()) return;
    for (var i = 0; i < _days; i++) {
      await _plugin.cancel(id: _firstId + i);
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
    await cancelAll();
    if (!on) return;
    final details = NotificationDetails(
      android: AndroidNotificationDetails(_channelId, channelName),
    );
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
        // No exact-alarm permission needed; a few minutes late is fine.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: title,
        body: body,
      );
    }
  }
}
