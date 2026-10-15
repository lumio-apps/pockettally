import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../reminder.dart';

bool _askedForExact = false;

/// Before a reminder is set: asks to allow notifications and, where
/// Android needs it, on-time reminders ("Alarms & reminders"). Returns
/// false only when notifications are not allowed.
Future<bool> askReminderPermissions(BuildContext context) async {
  final l = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  if (!await ReminderService.requestPermission()) {
    messenger.showSnackBar(SnackBar(content: Text(l.notificationsBlocked)));
    return false;
  }
  // Asked once per app start; Settings has a button for it too.
  if (!kExactAlarms || _askedForExact || await ReminderService.canBeExact()) {
    return true;
  }
  if (!context.mounted) return true;
  _askedForExact = true;
  await askExactReminders(context);
  return true;
}

/// Explains why on-time reminders need the user's OK, then opens the
/// phone's setting. Returns true when it is allowed afterwards.
Future<bool> askExactReminders(BuildContext context) async {
  final l = context.l10n;
  final allow = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.alarm_on_outlined),
      title: Text(l.exactAlarmTitle),
      content: Text(l.exactAlarmBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l.later),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l.allowButton),
        ),
      ],
    ),
  );
  if (allow != true) return false;
  return ReminderService.requestExact();
}
