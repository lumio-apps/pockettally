import 'package:flutter/material.dart';

import '../app_state.dart';
import '../l10n/l10n.dart';
import '../models.dart';
import '../photo_store.dart';
import '../platform.dart';
import '../utils/money_format.dart';
import '../widgets/profile_avatar.dart';

/// Top of the profile page (see SettingsScreen): the photo, name,
/// currency and how amounts are written.
class ProfileSection extends StatelessWidget {
  const ProfileSection({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final money = state.money;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Center(
          child: Semantics(
            button: true,
            label: l.changePhoto,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => _photoOptions(context),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ProfileAvatar(state: state, radius: 52),
                  PositionedDirectional(
                    end: -2,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: theme.scaffoldBackgroundColor,
                            width: 3),
                      ),
                      child: Icon(Icons.photo_camera_outlined,
                          size: 18, color: theme.colorScheme.onPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              state.userName,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        Center(
          child: TextButton(
            onPressed: () => _photoOptions(context),
            child: Text(l.changePhoto),
          ),
        ),
        SectionTitle(l.profile),
        ListTile(
          leading: const Icon(Icons.person_outline),
          title: Text(l.yourName),
          subtitle: Text(state.userName),
          trailing: const Icon(Icons.edit_outlined),
          onTap: () => _editName(context),
        ),
        ListTile(
          leading: const Icon(Icons.payments_outlined),
          title: Text(l.currency),
          subtitle: Text(
              '${state.currency.code} ${state.currency.symbol} · ${state.currency.name}'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _pickCurrency(context),
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
                child: Text(l.automaticWith(state.currency.decimals == 0
                    ? '13'
                    : '12${money.decimalSeparator}50')),
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
      ],
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

  Future<void> _photoOptions(BuildContext context) async {
    final l = context.l10n;
    final hasPhoto = state.profilePhotoFile != null;
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isDesktop)
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: Text(l.takePhoto),
                onTap: () => Navigator.pop(ctx, 'camera'),
              ),
            ListTile(
              leading: Icon(isDesktop
                  ? Icons.folder_open_outlined
                  : Icons.photo_library_outlined),
              title: Text(isDesktop ? l.chooseFile : l.chooseFromGallery),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            if (hasPhoto)
              ListTile(
                leading: Icon(Icons.delete_outline,
                    color: Theme.of(ctx).colorScheme.error),
                title: Text(l.removePhoto,
                    style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
                onTap: () => Navigator.pop(ctx, 'remove'),
              ),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    if (choice == 'remove') {
      await state.removeProfilePhoto();
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      final name = await PhotoStore.pickProfile(camera: choice == 'camera');
      if (name != null) await state.setProfilePhoto(name);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.couldNotAddPhoto)));
    }
  }

  Future<void> _editName(BuildContext context) async {
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
          onSubmitted: (v) => Navigator.pop(ctx, v),
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

  Future<void> _pickCurrency(BuildContext context) async {
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
}

/// A small colored heading above a group of settings.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 20, 16, 4),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
