import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../app_state.dart';
import '../backup.dart';
import '../backup_service.dart';
import '../reminder.dart';
import '../l10n/l10n.dart';
import '../theme.dart';
import '../update_checker.dart';
import 'budgets_screen.dart';
import 'categories_screen.dart';
import 'lock_screen.dart';
import 'profile_screen.dart';
import 'recurring_screen.dart';

/// Name of a color palette in the app's language.
String paletteName(AppLocalizations l, AppPalette p) {
  switch (p.id) {
    case 'ocean':
      return l.paletteOcean;
    case 'plum':
      return l.palettePlum;
    case 'wine':
      return l.paletteWine;
    case 'graphite':
      return l.paletteGraphite;
    default:
      return l.paletteForest;
  }
}

/// The profile page: photo, name and money format at the top, then all
/// app settings. Opened by tapping the photo on Home (Profile in the
/// sidebar on wide windows).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.state});

  final AppState state;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _version = '';
  bool _checking = false;
  bool _busy = false;

  AppState get state => widget.state;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = info.version);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final l = context.l10n;
        return Scaffold(
          appBar: AppBar(title: Text(l.profile)),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              ProfileSection(state: state),
              SectionTitle(l.sectionAppearance),
              ListTile(
                leading: const Icon(Icons.translate),
                title: Text(l.language),
                subtitle: Text(languageByCode(state.languageCode).nativeName),
                onTap: _pickLanguage,
              ),
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: Text(l.accentColor),
                subtitle: Text(paletteName(l, state.palette)),
                trailing: CircleAvatar(
                    radius: 14, backgroundColor: state.palette.brand),
                onTap: _pickPalette,
              ),
              ListTile(
                leading: const Icon(Icons.brightness_6_outlined),
                title: Text(l.theme),
                trailing: DropdownButton<ThemeMode>(
                  value: state.themeMode,
                  underline: const SizedBox.shrink(),
                  items: [
                    DropdownMenuItem(
                        value: ThemeMode.system, child: Text(l.themeSystem)),
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
              ListTile(
                leading: const Icon(Icons.calendar_view_week_outlined),
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
              SectionTitle(l.security),
              SwitchListTile(
                secondary: const Icon(Icons.lock_outline),
                title: Text(l.appLock),
                subtitle: Text(l.appLockSubtitle),
                value: state.appLockOn,
                onChanged: (on) => on ? _turnLockOn() : _turnLockOff(),
              ),
              if (state.appLockOn) ...[
                ListTile(
                  leading: const Icon(Icons.password),
                  title: Text(l.changePin),
                  onTap: _changePin,
                ),
                ListTile(
                  leading: const Icon(Icons.timer_outlined),
                  title: Text(l.lockAfter),
                  trailing: DropdownButton<int>(
                    value: const [0, 60, 300].contains(state.lockAfterSeconds)
                        ? state.lockAfterSeconds
                        : 0,
                    underline: const SizedBox.shrink(),
                    items: [
                      DropdownMenuItem(value: 0, child: Text(l.lockImmediately)),
                      DropdownMenuItem(value: 60, child: Text(l.lockAfterMinutes(1))),
                      DropdownMenuItem(value: 300, child: Text(l.lockAfterMinutes(5))),
                    ],
                    onChanged: (v) {
                      if (v != null) state.setLockAfter(v);
                    },
                  ),
                ),
              ],
              if (ReminderService.supported) ...[
                SectionTitle(l.reminder),
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_none),
                  title: Text(l.dailyReminder),
                  subtitle: Text(l.dailyReminderSubtitle),
                  value: state.reminderOn,
                  onChanged: _setReminder,
                ),
                if (state.reminderOn)
                  ListTile(
                    leading: const Icon(Icons.schedule),
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
              ],
              SectionTitle(l.sectionData),
              ListTile(
                leading: const Icon(Icons.category_outlined),
                title: Text(l.categories),
                subtitle: Text(l.categoriesSubtitle),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => CategoriesScreen(state: state),
                )),
              ),
              ListTile(
                leading: const Icon(Icons.repeat),
                title: Text(l.recurringEntries),
                subtitle: Text(state.recurring.isEmpty
                    ? l.recurringSubtitle
                    : l.recurringCount(state.recurring.length)),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => RecurringScreen(state: state),
                )),
              ),
              ListTile(
                leading: const Icon(Icons.savings_outlined),
                title: Text(l.navBudgets),
                subtitle: Text(state.monthlyBudgetMinor > 0
                    ? l.monthlyLimitAmount(
                        state.formatMoney(state.monthlyBudgetMinor))
                    : l.budgetsSubtitle),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => BudgetsScreen(state: state),
                )),
              ),
              ListTile(
                leading: const Icon(Icons.upload_file_outlined),
                title: Text(l.backUpData),
                subtitle: Text(l.backUpSubtitle),
                onTap: _busy ? null : _backup,
              ),
              ListTile(
                leading: const Icon(Icons.restore_outlined),
                title: Text(l.restoreFromBackup),
                subtitle: Text(l.restoreSubtitle),
                onTap: _busy ? null : _restore,
              ),
              ListTile(
                leading: const Icon(Icons.table_view_outlined),
                title: Text(l.exportCsv),
                subtitle: Text(l.exportCsvSubtitle),
                onTap: _busy || state.entries.isEmpty ? null : _exportCsv,
              ),
              ListTile(
                leading: const Icon(Icons.post_add_outlined),
                title: Text(l.importCsv),
                subtitle: Text(l.importCsvSubtitle),
                onTap: _busy ? null : _importCsv,
              ),
              SectionTitle(l.sectionAbout),
              if (kUpdaterEnabled)
                ListTile(
                  leading: _checking
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.system_update_outlined),
                  title: Text(l.checkForUpdates),
                  subtitle: Text(_version.isEmpty
                      ? 'PocketTally'
                      : l.installedVersion(_version)),
                  onTap: _checking ? null : _checkForUpdates,
                )
              else
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(l.version),
                  subtitle: Text(_version),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _turnLockOn() async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final pin = await Navigator.of(context).push<String>(MaterialPageRoute(
      builder: (_) => PinSetupScreen(state: state, mode: PinSetupMode.create),
    ));
    if (pin == null) return;
    await state.setPin(pin);
    messenger.showSnackBar(SnackBar(content: Text(l.pinSet)));
  }

  /// Asks for the current PIN; true when it was typed right.
  Future<bool> _verifyPin() async {
    final ok = await Navigator.of(context).push<String>(MaterialPageRoute(
      builder: (_) => PinSetupScreen(state: state, mode: PinSetupMode.verify),
    ));
    return ok == 'ok';
  }

  Future<void> _turnLockOff() async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    if (!await _verifyPin()) return;
    await state.removePin();
    messenger.showSnackBar(SnackBar(content: Text(l.pinOff)));
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
    messenger.showSnackBar(SnackBar(content: Text(l.pinSet)));
  }

  Future<void> _setReminder(bool on) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    if (on && !await ReminderService.requestPermission()) {
      messenger.showSnackBar(
          SnackBar(content: Text(l.notificationsBlocked)));
      return;
    }
    await state.setReminder(on: on);
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
        messenger.showSnackBar(SnackBar(
          content: Text(l.backupSaved(state.entries.length)),
        ));
      }
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.couldNotSaveBackup)));
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
            SnackBar(content: Text(l.csvExported(state.entries.length))));
      }
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.couldNotSaveFile)));
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
        messenger.showSnackBar(SnackBar(content: Text(l.csvNoEntries)));
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
          SnackBar(content: Text(l.csvImported(result.entries.length))));
    } on FormatException {
      messenger.showSnackBar(SnackBar(content: Text(l.csvInvalid)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.csvInvalid)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
            SnackBar(content: Text(backupErrorMessage(l, e.message))));
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
      messenger.showSnackBar(SnackBar(content: Text(l.backupRestored)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.couldNotRestore)));
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
        messenger.showSnackBar(SnackBar(content: Text(l.upToDate)));
      } else {
        await _showUpdateDialog(update);
      }
    } catch (_) {
      messenger
          .showSnackBar(SnackBar(content: Text(l.couldNotCheckUpdates)));
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
