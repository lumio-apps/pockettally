import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../app_state.dart';
import '../models.dart';
import '../update_checker.dart';
import 'categories_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.state});

  final AppState state;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _version = '';
  bool _checking = false;

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
        return Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: ListView(
            children: [
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Your name'),
                subtitle: Text(state.userName),
                onTap: _editName,
              ),
              ListTile(
                leading: const Icon(Icons.payments_outlined),
                title: const Text('Currency'),
                subtitle: Text(
                    '${state.currency.code} ${state.currency.symbol} · ${state.currency.name}'),
                onTap: _pickCurrency,
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(72, 0, 16, 8),
                child: Text(
                  'Changing currency only changes the symbol. '
                  'Amounts you already entered are not converted.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.brightness_6_outlined),
                title: const Text('Theme'),
                trailing: DropdownButton<ThemeMode>(
                  value: state.themeMode,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(
                        value: ThemeMode.system, child: Text('System')),
                    DropdownMenuItem(
                        value: ThemeMode.light, child: Text('Light')),
                    DropdownMenuItem(
                        value: ThemeMode.dark, child: Text('Dark')),
                  ],
                  onChanged: (m) {
                    if (m != null) state.setThemeMode(m);
                  },
                ),
              ),
              ListTile(
                leading: const Icon(Icons.category_outlined),
                title: const Text('Categories'),
                subtitle: const Text('Add, rename, recolor or delete'),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => CategoriesScreen(state: state),
                )),
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
                  title: const Text('Check for updates'),
                  subtitle: Text(_version.isEmpty
                      ? 'PocketTally'
                      : 'Installed version $_version'),
                  onTap: _checking ? null : _checkForUpdates,
                )
              else
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Version'),
                  subtitle: Text(_version),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _editName() async {
    final controller = TextEditingController(text: state.userName);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Your name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Save')),
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
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Choose currency',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
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

  Future<void> _checkForUpdates() async {
    setState(() => _checking = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final update = await UpdateChecker.check();
      if (!mounted) return;
      if (update == null) {
        messenger.showSnackBar(
            const SnackBar(content: Text("You're up to date")));
      } else {
        await _showUpdateDialog(update);
      }
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Could not check for updates. Check your internet.')));
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
  String? _error;

  Future<void> _start() async {
    setState(() {
      _progress = 0;
      _error = null;
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
          _error = 'Download failed. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final downloading = _progress != null;
    return AlertDialog(
      title: Text('Version ${widget.update.version} is available'),
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
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: downloading ? null : () => Navigator.of(context).pop(),
          child: const Text('Later'),
        ),
        FilledButton(
          onPressed: downloading ? null : _start,
          child: const Text('Update'),
        ),
      ],
    );
  }
}
