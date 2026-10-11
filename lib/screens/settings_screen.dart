import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../app_state.dart';
import '../backup.dart';
import '../backup_service.dart';
import '../l10n/l10n.dart';
import '../models.dart';
import '../theme.dart';
import '../update_checker.dart';
import '../utils/money_format.dart';
import 'budgets_screen.dart';
import 'categories_screen.dart';
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
        final money = state.money;
        return Scaffold(
          appBar: AppBar(title: Text(l.navSettings)),
          body: ListView(
            children: [
              ListTile(
                leading: const Icon(Icons.translate),
                title: Text(l.language),
                subtitle: Text(languageByCode(state.languageCode).nativeName),
                onTap: _pickLanguage,
              ),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(l.yourName),
                subtitle: Text(state.userName),
                onTap: _editName,
              ),
              ListTile(
                leading: const Icon(Icons.payments_outlined),
                title: Text(l.currency),
                subtitle: Text(
                    '${state.currency.code} ${state.currency.symbol} · ${state.currency.name}'),
                onTap: _pickCurrency,
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(72, 0, 16, 8),
                child: Text(l.currencyNote,
                    style: const TextStyle(fontSize: 12)),
              ),
              ListTile(
                leading: const Icon(Icons.pin_outlined),
                title: Text(l.numberFormat),
                trailing: DropdownButton<NumberStyle>(
                  value: state.numberStyleSetting,
                  underline: const SizedBox.shrink(),
                  items: [
                    for (final style in NumberStyle.values)
                      DropdownMenuItem(
                        value: style,
                        child: Text(_styleLabel(l, style)),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) state.setNumberStyle(v);
                  },
                ),
              ),
              ListTile(
                leading: const Icon(Icons.exposure_outlined),
                title: Text(l.decimals),
                trailing: DropdownButton<int>(
                  value: state.decimalsSetting,
                  underline: const SizedBox.shrink(),
                  items: [
                    DropdownMenuItem(
                      value: -1,
                      child: Text(l.automaticWith(
                          state.currency.decimals == 0 ? '13' : '12${money.decimalSeparator}50')),
                    ),
                    DropdownMenuItem(
                        value: 2,
                        child: Text(
                            l.decimalsTwo('12${money.decimalSeparator}50'))),
                    DropdownMenuItem(
                        value: 0, child: Text(l.decimalsNone('13'))),
                  ],
                  onChanged: (v) {
                    if (v != null) state.setDecimals(v);
                  },
                ),
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
              const Divider(),
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
              const Divider(),
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

  /// "1,234,567.89" etc.; "Automatic (…)" shows what it resolves to.
  String _styleLabel(AppLocalizations l, NumberStyle style) {
    final resolved =
        style == NumberStyle.auto ? state.currency.numberStyle : style;
    final sample =
        MoneyFormatter(style: resolved, decimals: 2).number(123456789);
    return style == NumberStyle.auto ? l.automaticWith(sample) : sample;
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

  Future<void> _editName() async {
    final l = context.l10n;
    final controller = TextEditingController(text: state.userName);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.yourName),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: Text(l.save)),
        ],
      ),
    );
    controller.dispose();
    if (name != null && name.trim().isNotEmpty) {
      await state.setUserName(name);
    }
  }

  Future<void> _pickCurrency() async {
    final picked = await showModalBottomSheet<Currency>(
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
              child: Text(ctx.l10n.chooseCurrency,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600)),
            ),
            for (final c in kCurrencies)
              ListTile(
                title: Text('${c.code}  ${c.symbol}'),
                subtitle: Text(c.name),
                trailing: c.code == state.currency.code
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(ctx, c),
              ),
          ],
        ),
      ),
    );
    if (picked != null) await state.setCurrency(picked);
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
