import 'package:flutter/material.dart';

import '../app_state.dart';
import '../l10n/l10n.dart';
import '../models.dart';

/// Shown on first launch, in three steps: language, name, currency.
/// All three can be changed later in Settings.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key, required this.state});

  final AppState state;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  static const _steps = 3;

  final _nameController = TextEditingController();
  final Currency _suggested = AppState.suggestedCurrency;
  late Currency _currency = _suggested;
  int _step = 0;

  AppState get state => widget.state;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _canContinue =>
      _step != 1 || _nameController.text.trim().isNotEmpty;

  Future<void> _next() async {
    if (!_canContinue) return;
    if (_step == 0) {
      // Save the language even if the preselected one was kept.
      await state.setLanguage(state.languageCode);
    }
    if (_step < _steps - 1) {
      setState(() => _step++);
      return;
    }
    await state.completeOnboarding(_nameController.text, _currency);
  }

  void _back() {
    if (_step > 0) setState(() => _step--);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    final last = _step == _steps - 1;

    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Row(
                  children: [
                    Image.asset('assets/icon/logo.png', width: 44, height: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l.stepOf((_step + 1).toString(), _steps.toString()),
                        style: theme.textTheme.labelLarge,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (_step + 1) / _steps,
                    minHeight: 6,
                  ),
                ),
              ),
              Expanded(
                child: switch (_step) {
                  0 => _languageStep(theme, l),
                  1 => _nameStep(theme, l),
                  _ => _currencyStep(theme, l),
                },
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Row(
                  children: [
                    if (_step > 0) ...[
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 52)),
                          onPressed: _back,
                          child: Text(l.back),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: _canContinue ? _next : null,
                        child: Text(last ? l.getStarted : l.continueButton),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heading(ThemeData theme, String title, [String? subtitle]) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(subtitle, style: theme.textTheme.bodyLarge),
          ],
        ],
      ),
    );
  }

  Widget _languageStep(ThemeData theme, AppLocalizations l) {
    final current = state.languageCode;
    return ListView(
      children: [
        _heading(theme, l.welcomeTitle, l.welcomeSubtitle),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
          child: Text(l.chooseLanguage, style: theme.textTheme.titleMedium),
        ),
        for (final lang in kLanguages)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
            title: Text(lang.nativeName),
            subtitle: lang.nativeName == lang.englishName
                ? null
                : Text(lang.englishName),
            trailing: lang.code == current
                ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
                : null,
            selected: lang.code == current,
            onTap: () => state.setLanguage(lang.code),
          ),
      ],
    );
  }

  Widget _nameStep(ThemeData theme, AppLocalizations l) {
    return ListView(
      children: [
        _heading(theme, l.whatToCallYou),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: TextField(
            controller: _nameController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: l.yourName,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _next(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: Text(l.changeLaterInSettings,
              style: theme.textTheme.bodySmall),
        ),
      ],
    );
  }

  Widget _currencyStep(ThemeData theme, AppLocalizations l) {
    final others = kCurrencies.where((c) => c.code != _suggested.code);
    Widget tile(Currency c) => ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 24),
          leading: SizedBox(
            width: 48,
            child: Text(c.symbol,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ),
          title: Text(c.code),
          subtitle: Text(c.name),
          trailing: c.code == _currency.code
              ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
              : null,
          selected: c.code == _currency.code,
          onTap: () => setState(() => _currency = c),
        );
    return ListView(
      children: [
        _heading(theme, l.chooseYourCurrency, l.changeLaterInSettings),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
          child: Text(l.currencySuggested, style: theme.textTheme.labelLarge),
        ),
        tile(_suggested),
        const Divider(),
        for (final c in others) tile(c),
      ],
    );
  }
}
