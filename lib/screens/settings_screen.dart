import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../android_extras.dart';
import '../app_state.dart';
import '../auto_backup.dart';
import '../backup.dart';
import '../backup_service.dart';
import '../biometric.dart';
import '../l10n/l10n.dart';
import '../reminder.dart';
import 'trash_screen.dart';
import 'wallets_screen.dart';
import '../update_checker.dart';
import '../theme.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/reminder_permission.dart';
import 'budgets_screen.dart';
import 'categories_screen.dart';
import 'lock_screen.dart';
import 'profile_screen.dart';
import 'recurring_screen.dart';
import '../widgets/neo.dart';

/// Name of a color palette in the app's language.
String paletteName(AppLocalizations l, AppPalette p) {
  switch (p.id) {
    case 'blue':
      return l.paletteBlue;
    case 'forest':
      return l.paletteForest;
    case 'ocean':
      return l.paletteOcean;
    case 'plum':
      return l.palettePlum;
    case 'wine':
      return l.paletteWine;
    case 'graphite':
      return l.paletteGraphite;
    default:
      return l.paletteBlue;
  }
}

/// All app settings, in groups, with a card for the profile at the top
/// and a reminder that everything stays on the device. A tab on phones,
/// a page of the sidebar on wide windows.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.state});

  final AppState state;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _version = '';
  bool _busy = false;
  bool _checking = false;
  bool _biometricAvailable = false;

  AppState get state => widget.state;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = info.version);
    });
    _checkExact();
    Biometric.available().then((ok) {
      if (mounted) setState(() => _biometricAvailable = ok);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final l = context.l10n;
        return Scaffold(
          appBar: AppBar(title: Text(l.settings)),
          body: ListView(
            // Room at the bottom for the + button.
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 56),
            children: [
              _ProfileCard(
                state: state,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ProfileScreen(state: state),
                )),
              ),
              const SizedBox(height: 12),
              const _PrivacyBox(),
              _Group(
                title: l.sectionAppearance,
                children: [
                  ListTile(
                    leading: const _SettingIcon(
                        Icons.translate, Color(0xFF4C6FFF)),
                    title: Text(l.language),
                    subtitle:
                        Text(languageByCode(state.languageCode).nativeName),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _pickLanguage,
                  ),
                  ListTile(
                    leading: const _SettingIcon(
                        Icons.palette_outlined, Color(0xFFE0458B)),
                    title: Text(l.accentColor),
                    subtitle: Text(paletteName(l, state.palette)),
                    trailing: CircleAvatar(
                        radius: 12, backgroundColor: state.palette.brand),
                    onTap: _pickPalette,
                  ),
                  ListTile(
                    leading: const _SettingIcon(
                        Icons.brightness_6_outlined, Color(0xFF8E59D8)),
                    title: Text(l.theme),
                    trailing: DropdownButton<ThemeMode>(
                      value: state.themeMode,
                      underline: const SizedBox.shrink(),
                      items: [
                        DropdownMenuItem(
                            value: ThemeMode.system,
                            child: Text(l.themeSystem)),
                        DropdownMenuItem(
                            value: ThemeMode.light, child: Text(l.themeLight)),
                        DropdownMenuItem(
                            value: ThemeMode.dark, child: Text(l.themeDark)),
                      ],
                      onChanged: (m) {
                        if (m != null) state.setThemeMode(m);
                      },
                    ),
                  ),
                  SwitchListTile(
                    secondary: const _SettingIcon(
                        Icons.blur_off_outlined, Color(0xFF607D8B)),
                    title: Text(l.reduceEffects),
                    subtitle: Text(l.reduceEffectsSubtitle),
                    value: state.reduceEffects,
                    onChanged: state.setReduceEffects,
                  ),
                  ListTile(
                    leading: const _SettingIcon(
                        Icons.calendar_view_week_outlined, Color(0xFF00A3A3)),
                    title: Text(l.weekStartsOn),
                    trailing: DropdownButton<bool>(
                      value: state.weekStartsOnSunday,
                      underline: const SizedBox.shrink(),
                      items: [
                        DropdownMenuItem(value: false, child: Text(l.monday)),
                        DropdownMenuItem(value: true, child: Text(l.sunday)),
                      ],
                      onChanged: (v) {
                        if (v != null) state.setWeekStartsOnSunday(v);
                      },
                    ),
                  ),
                ],
              ),
              _Group(
                title: l.security,
                children: [
                  SwitchListTile(
                    secondary: const _SettingIcon(
                        Icons.lock_outline, Color(0xFF2E9E5B)),
                    title: Text(l.appLock),
                    subtitle: Text(l.appLockSubtitle),
                    value: state.appLockOn,
                    onChanged: (on) => on ? _turnLockOn() : _turnLockOff(),
                  ),
                  if (state.appLockOn) ...[
                    if (_biometricAvailable)
                      SwitchListTile(
                        secondary: const _SettingIcon(
                            Icons.fingerprint, Color(0xFF2E9E5B)),
                        title: Text(l.biometricUnlock),
                        subtitle: Text(l.biometricUnlockSubtitle),
                        value: state.biometricOn,
                        onChanged: _setBiometric,
                      ),
                    ListTile(
                      leading: const _SettingIcon(
                          Icons.password, Color(0xFF2E9E5B)),
                      title: Text(l.changePin),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _changePin,
                    ),
                    ListTile(
                      leading: const _SettingIcon(
                          Icons.timer_outlined, Color(0xFF2E9E5B)),
                      title: Text(l.lockAfter),
                      trailing: DropdownButton<int>(
                        value: const [0, 60, 300]
                                .contains(state.lockAfterSeconds)
                            ? state.lockAfterSeconds
                            : 0,
                        underline: const SizedBox.shrink(),
                        items: [
                          DropdownMenuItem(
                              value: 0, child: Text(l.lockImmediately)),
                          DropdownMenuItem(
                              value: 60, child: Text(l.lockAfterMinutes(1))),
                          DropdownMenuItem(
                              value: 300, child: Text(l.lockAfterMinutes(5))),
                        ],
                        onChanged: (v) {
                          if (v != null) state.setLockAfter(v);
                        },
                      ),
                    ),
                  ],
                ],
              ),
              if (ReminderService.supported)
                _Group(
                  title: l.reminder,
                  children: [
                    SwitchListTile(
                      secondary: const _SettingIcon(
                          Icons.notifications_none, Color(0xFFF08C00)),
                      title: Text(l.dailyReminder),
                      subtitle: Text(l.dailyReminderSubtitle),
                      value: state.reminderOn,
                      onChanged: _setReminder,
                    ),
                    if (state.reminderOn)
                      ListTile(
                        leading: const _SettingIcon(
                            Icons.schedule, Color(0xFFF08C00)),
                        title: Text(l.reminderTime),
                        trailing: Text(
                          MaterialLocalizations.of(context).formatTimeOfDay(
                            TimeOfDay(
                                hour: state.reminderMinutes ~/ 60,
                                minute: state.reminderMinutes % 60),
                            alwaysUse24HourFormat:
                                MediaQuery.of(context).alwaysUse24HourFormat,
                          ),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        onTap: _pickReminderTime,
                      ),
                    if (kExactAlarms && !_exact)
                      ListTile(
                        leading: const _SettingIcon(
                            Icons.alarm_on_outlined, Color(0xFFE5533D)),
                        title: Text(l.allowExactReminders),
                        subtitle: Text(l.allowExactRemindersHint),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _allowExact,
                      ),
                    ListTile(
                      leading: const _SettingIcon(
                          Icons.notifications_active_outlined,
                          Color(0xFFF08C00)),
                      title: Text(l.testNotification),
                      subtitle: Text(l.testNotificationHint),
                      onTap: _testNotification,
                    ),
                    ListTile(
                      leading: const _SettingIcon(
                          Icons.battery_alert_outlined, Color(0xFF64748B)),
                      title: Text(l.remindersNotComing),
                      subtitle: Text(l.remindersNotComingHint),
                      trailing: const Icon(Icons.open_in_new, size: 18),
                      onTap: AndroidExtras.openAppSettings,
                    ),
                  ],
                ),
              _Group(
                title: l.sectionData,
                children: [
                  ListTile(
                    leading: const _SettingIcon(
                        Icons.category_outlined, Color(0xFF4C6FFF)),
                    title: Text(l.categories),
                    subtitle: Text(l.categoriesSubtitle),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => CategoriesScreen(state: state),
                    )),
                  ),
                  ListTile(
                    leading: const _SettingIcon(
                        Icons.repeat, Color(0xFF00A3A3)),
                    title: Text(l.recurringEntries),
                    subtitle: Text(state.recurring.isEmpty
                        ? l.recurringSubtitle
                        : l.recurringCount(state.recurring.length)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => RecurringScreen(state: state),
                    )),
                  ),
                  ListTile(
                    leading: const _SettingIcon(
                        Icons.savings_outlined, Color(0xFFD89B00)),
                    title: Text(l.navBudgets),
                    subtitle: Text(state.monthlyBudgetMinor > 0
                        ? l.monthlyLimitAmount(
                            state.formatMoney(state.monthlyBudgetMinor))
                        : l.budgetsSubtitle),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => BudgetsScreen(state: state),
                    )),
                  ),
                  ListTile(
                    leading: const _SettingIcon(
                        Icons.account_balance_wallet_outlined,
                        Color(0xFF2E9E5B)),
                    title: Text(l.wallets),
                    subtitle: Text(l.walletsSubtitle),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => WalletsScreen(state: state))),
                  ),
                  ListTile(
                    leading: const _SettingIcon(
                        Icons.delete_sweep_outlined, Color(0xFF607D8B)),
                    title: Text(l.trash),
                    subtitle: Text(state.trash.isEmpty
                        ? l.trashEmpty
                        : l.trashCount(state.trash.length)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => TrashScreen(state: state))),
                  ),
                ],
              ),
              _Group(
                title: l.sectionBackup,
                children: [
                  SwitchListTile(
                    secondary: const _SettingIcon(
                        Icons.cloud_done_outlined, Color(0xFF1565FF)),
                    title: Text(l.autoBackup),
                    subtitle: Text(_autoBackupStatus(l)),
                    value: state.autoBackupOn,
                    onChanged: _setAutoBackup,
                  ),
                  if (state.autoBackupOn) ...[
                    ListTile(
                      leading: const _SettingIcon(
                          Icons.event_repeat, Color(0xFF1565FF)),
                      title: Text(l.howOften),
                      trailing: DropdownButton<int>(
                        value: state.autoBackupDays,
                        underline: const SizedBox.shrink(),
                        items: [
                          DropdownMenuItem(value: 1, child: Text(l.everyDay)),
                          DropdownMenuItem(value: 7, child: Text(l.everyWeek)),
                        ],
                        onChanged: (v) {
                          if (v != null) state.setAutoBackup(days: v);
                        },
                      ),
                    ),
                    if (state.autoBackupFolder != null)
                      ListTile(
                        leading: const _SettingIcon(
                            Icons.folder_outlined, Color(0xFF1565FF)),
                        title: Text(l.savedIn),
                        subtitle: Text(
                            '${_shortFolder(state.autoBackupFolder!)}\n${l.keepsLastBackups}'),
                        isThreeLine: true,
                      ),
                  ],
                  SwitchListTile(
                    secondary: const _SettingIcon(
                        Icons.photo_library_outlined, Color(0xFF8E59D8)),
                    title: Text(l.includeBillPhotos),
                    subtitle: Text(l.includeBillPhotosHint),
                    value: state.backupWithPhotos,
                    onChanged: (v) => state.setAutoBackup(withPhotos: v),
                  ),
                  ListTile(
                    leading: const _SettingIcon(
                        Icons.upload_file_outlined, Color(0xFF2E9E5B)),
                    title: Text(l.backUpData),
                    subtitle: Text(l.backUpSubtitle),
                    onTap: _busy ? null : _backup,
                  ),
                  ListTile(
                    leading: const _SettingIcon(
                        Icons.restore_outlined, Color(0xFFF08C00)),
                    title: Text(l.restoreFromBackup),
                    subtitle: Text(l.restoreSubtitle),
                    onTap: _busy ? null : _restore,
                  ),
                  ListTile(
                    leading: const _SettingIcon(
                        Icons.table_view_outlined, Color(0xFF00A3A3)),
                    title: Text(l.exportCsv),
                    subtitle: Text(l.exportCsvSubtitle),
                    onTap: _busy || state.entries.isEmpty ? null : _exportCsv,
                  ),
                  ListTile(
                    leading: const _SettingIcon(
                        Icons.post_add_outlined, Color(0xFF00A3A3)),
                    title: Text(l.importCsv),
                    subtitle: Text(l.importCsvSubtitle),
                    onTap: _busy ? null : _importCsv,
                  ),
                ],
              ),
              _Group(
                title: l.sectionAbout,
                children: [
                  ListTile(
                    leading: _checking
                        ? const SizedBox(
                            width: 34,
                            height: 34,
                            child: Padding(
                              padding: EdgeInsets.all(7),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : const _SettingIcon(Icons.system_update_outlined,
                            Color(0xFF1565FF)),
                    title: Text(l.checkForUpdates),
                    subtitle: Text(_version.isEmpty
                        ? 'PocketTally'
                        : l.installedVersion(_version)),
                    onTap: _checking ? null : _checkForUpdates,
                  ),
                  const ListTile(
                    leading:
                        _SettingIcon(Icons.favorite_border, Color(0xFFE0458B)),
                    title: Text('PocketTally'),
                    subtitle: Text('by Lumio Apps'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _autoBackupStatus(AppLocalizations l) {
    if (state.autoBackupOn && state.autoBackupFailed) return l.autoBackupFailed;
    final last = state.lastAutoBackup;
    if (last == null) return l.noBackupYet;
    return l.lastBackupAt(DateFormat.yMMMd().add_Hm().format(last));
  }

  /// "/storage/emulated/0/Documents/PocketTally" -> "Documents/PocketTally".
  String _shortFolder(String path) {
    const phone = '/storage/emulated/0/';
    return path.startsWith(phone) ? path.substring(phone.length) : path;
  }

  Future<void> _setAutoBackup(bool on) async {
    await state.setAutoBackup(on: on);
    // Make the first one right away, so the user sees where it went.
    if (on) await AutoBackup.runIfDue(state, force: true);
  }

  Future<void> _turnLockOn() async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final pin = await Navigator.of(context).push<String>(MaterialPageRoute(
      builder: (_) => PinSetupScreen(state: state, mode: PinSetupMode.create),
    ));
    if (pin == null) return;
    await state.setPin(pin);
    messenger.showSnackBar(SnackBar(duration: const Duration(seconds: 3), content: Text(l.pinSet)));
  }

  /// Asks for the current PIN; true when it was typed right.
  Future<bool> _verifyPin() async {
    final ok = await Navigator.of(context).push<String>(MaterialPageRoute(
      builder: (_) => PinSetupScreen(state: state, mode: PinSetupMode.verify),
    ));
    return ok == 'ok';
  }

  /// Turning it on first asks for the fingerprint or face once, so it is
  /// known to work before the lock relies on it.
  Future<void> _setBiometric(bool on) async {
    if (on && !await Biometric.authenticate(context.l10n.biometricReason)) {
      return;
    }
    await state.setBiometric(on);
  }

  Future<void> _turnLockOff() async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    if (!await _verifyPin()) return;
    await state.removePin();
    messenger.showSnackBar(SnackBar(duration: const Duration(seconds: 3), content: Text(l.pinOff)));
  }

  Future<void> _changePin() async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    if (!await _verifyPin()) return;
    final pin = await navigator.push<String>(MaterialPageRoute(
      builder: (_) => PinSetupScreen(state: state, mode: PinSetupMode.create),
    ));
    if (pin == null) return;
    await state.setPin(pin);
    messenger.showSnackBar(SnackBar(duration: const Duration(seconds: 3), content: Text(l.pinSet)));
  }

  Future<void> _setReminder(bool on) async {
    if (on && !await askReminderPermissions(context)) return;
    await state.setReminder(on: on);
    await _checkExact();
  }

  /// Whether reminders can come at the exact minute (see ReminderService).
  bool _exact = true;

  Future<void> _checkExact() async {
    if (!ReminderService.supported) return;
    final exact = await ReminderService.canBeExact();
    if (mounted && exact != _exact) setState(() => _exact = exact);
  }

  Future<void> _allowExact() async {
    await askExactReminders(context);
    await _checkExact();
    // Plan the reminders again, now on time.
    await state.syncReminder();
    await state.syncDebtReminders();
  }

  Future<void> _testNotification() async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    if (!await ReminderService.requestPermission()) {
      messenger.showSnackBar(SnackBar(duration: const Duration(seconds: 3), content: Text(l.notificationsBlocked)));
      return;
    }
    final ok = await ReminderService.showTest(
      title: 'PocketTally',
      body: l.testNotificationBody,
      channelName: l.debtReminders,
    );
    if (!ok) {
      messenger.showSnackBar(SnackBar(duration: const Duration(seconds: 3), content: Text(l.notificationsBlocked)));
    }
  }

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
          hour: state.reminderMinutes ~/ 60,
          minute: state.reminderMinutes % 60),
    );
    if (picked != null) {
      await state.setReminder(minutes: picked.hour * 60 + picked.minute);
    }
  }

  Future<void> _pickLanguage() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (ctx, scroll) => ListView(
          controller: scroll,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(ctx.l10n.language,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600)),
            ),
            for (final lang in kLanguages)
              ListTile(
                title: Text(lang.nativeName),
                subtitle: Text(lang.englishName),
                trailing: lang.code == state.languageCode
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(ctx, lang.code),
              ),
          ],
        ),
      ),
    );
    if (picked != null) await state.setLanguage(picked);
  }

  Future<void> _pickPalette() async {
    final l = context.l10n;
    final picked = await showDialog<AppPalette>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l.accentColor),
        children: [
          for (final p in kPalettes)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, p),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Row(
                children: [
                  CircleAvatar(radius: 16, backgroundColor: p.brand),
                  const SizedBox(width: 16),
                  Expanded(child: Text(paletteName(l, p))),
                  if (p.id == state.palette.id) const Icon(Icons.check),
                ],
              ),
            ),
        ],
      ),
    );
    if (picked != null) await state.setPalette(picked);
  }

  Future<void> _backup() async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final saved =
          await BackupService.export(state, dialogTitle: l.saveBackupTitle);
      if (saved) {
        messenger.showSnackBar(SnackBar(duration: const Duration(seconds: 3), 
          content: Text(l.backupSaved(state.entries.length)),
        ));
      }
    } catch (_) {
      messenger.showSnackBar(SnackBar(duration: const Duration(seconds: 3), content: Text(l.couldNotSaveBackup)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportCsv() async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final saved =
          await BackupService.exportCsv(state, dialogTitle: l.exportCsv);
      if (saved) {
        messenger.showSnackBar(
            SnackBar(duration: const Duration(seconds: 3), content: Text(l.csvExported(state.entries.length))));
      }
    } catch (_) {
      messenger.showSnackBar(SnackBar(duration: const Duration(seconds: 3), content: Text(l.couldNotSaveFile)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importCsv() async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final result = await BackupService.pickCsv(dialogTitle: l.importCsv);
      if (result == null || !mounted) return;
      if (result.entries.isEmpty) {
        messenger.showSnackBar(SnackBar(duration: const Duration(seconds: 3), content: Text(l.csvNoEntries)));
        return;
      }
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l.csvImportQuestion(result.entries.length)),
          content: Text(result.skipped > 0
              ? '${l.csvImportNote}\n\n${l.csvSkipped(result.skipped)}'
              : l.csvImportNote),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l.cancel)),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l.add)),
          ],
        ),
      );
      if (ok != true) return;
      await state.importEntries(result.entries);
      messenger.showSnackBar(
          SnackBar(duration: const Duration(seconds: 3), content: Text(l.csvImported(result.entries.length))));
    } on FormatException {
      messenger.showSnackBar(SnackBar(duration: const Duration(seconds: 3), content: Text(l.csvInvalid)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(duration: const Duration(seconds: 3), content: Text(l.csvInvalid)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkForUpdates() async {
    final l = context.l10n;
    setState(() => _checking = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final update = await UpdateChecker.check();
      if (!mounted) return;
      if (update == null) {
        messenger.showSnackBar(SnackBar(duration: const Duration(seconds: 3), content: Text(l.upToDate)));
      } else {
        await _showUpdateDialog(update);
      }
    } catch (_) {
      messenger
          .showSnackBar(SnackBar(duration: const Duration(seconds: 3), content: Text(l.couldNotCheckUpdates)));
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _showUpdateDialog(UpdateInfo update) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _UpdateDialog(update: update),
    );
  }

  Future<void> _restore() async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final BackupData? backup;
      try {
        backup = await BackupService.pick(dialogTitle: l.chooseBackupTitle);
      } on FormatException catch (e) {
        messenger.showSnackBar(
            SnackBar(duration: const Duration(seconds: 3), content: Text(backupErrorMessage(l, e.message))));
        return;
      }
      if (backup == null || !mounted) return;
      // A non-nullable copy, so the dialog builder below can use it.
      final BackupData data = backup;

      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l.restoreQuestion),
          content: Text(l.restoreDetails(
            data.entries.length.toString(),
            data.categories.length.toString(),
            state.entries.length.toString(),
          )),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.restore),
            ),
          ],
        ),
      );
      if (ok != true) return;

      await state.restoreBackup(data);
      messenger.showSnackBar(SnackBar(duration: const Duration(seconds: 3), content: Text(l.backupRestored)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(duration: const Duration(seconds: 3), content: Text(l.couldNotRestore)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}


class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({required this.update});

  final UpdateInfo update;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  double? _progress;
  bool _failed = false;

  Future<void> _start() async {
    setState(() {
      _progress = 0;
      _failed = false;
    });
    try {
      await UpdateChecker.downloadAndInstall(widget.update, (p) {
        if (mounted) setState(() => _progress = p);
      });
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _progress = null;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final downloading = _progress != null;
    return AlertDialog(
      title: Text(l.versionAvailable(widget.update.version)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.update.notes.isNotEmpty) Text(widget.update.notes),
            if (downloading) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 4),
              Text('${((_progress ?? 0) * 100).round()}%'),
            ],
            if (_failed) ...[
              const SizedBox(height: 12),
              Text(l.downloadFailed,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: downloading ? null : () => Navigator.of(context).pop(),
          child: Text(l.later),
        ),
        FilledButton(
          onPressed: downloading ? null : _start,
          child: Text(l.update),
        ),
      ],
    );
  }
}

/// The user's photo, name and money format; a tap opens the profile.
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.state, required this.onTap});

  final AppState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    final c = state.currency;
    return NeoCard(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              ProfileAvatar(state: state, radius: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${c.code} ${c.symbol} · ${state.money.number(123456789)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l.editProfile,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

/// "100% offline": no account, no ads, nothing leaves the device.
class _PrivacyBox extends StatelessWidget {
  const _PrivacyBox();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l = context.l10n;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.verified_user_outlined, color: scheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.offlineTitle,
                    style: TextStyle(
                        color: scheme.primary, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(l.privacyBody,
                    style: TextStyle(color: scheme.onSurface, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A heading and a card holding a group of settings.
class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(4, 22, 4, 8),
          child: Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        NeoCard(
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: children),
          ),
        ),
      ],
    );
  }
}

/// A small colored square with an icon, in front of a setting.
class _SettingIcon extends StatelessWidget {
  const _SettingIcon(this.icon, this.color);

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color.withValues(alpha: dark ? 0.26 : 0.13),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon,
          size: 19, color: dark ? Color.lerp(color, Colors.white, 0.35) : color),
    );
  }
}
