import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';

/// Shown on first launch: asks for the user's name and currency.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key, required this.state});

  final AppState state;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _nameController = TextEditingController();
  Currency _currency = kCurrencies.first;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _canContinue => _nameController.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Image.asset('assets/icon/logo.png', width: 72, height: 72),
              const SizedBox(height: 16),
              Text('Welcome to PocketTally', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                'Track your daily income and expenses. '
                'Everything stays on your phone.',
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'What should we call you?',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<Currency>(
                initialValue: _currency,
                decoration: const InputDecoration(
                  labelText: 'Currency',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final c in kCurrencies)
                    DropdownMenuItem(
                      value: c,
                      child: Text('${c.code}  ${c.symbol}  ·  ${c.name}'),
                    ),
                ],
                onChanged: (c) => setState(() => _currency = c ?? _currency),
              ),
              const SizedBox(height: 8),
              Text('You can change this later in Settings.',
                  style: theme.textTheme.bodySmall),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _canContinue
                      ? () => widget.state
                          .completeOnboarding(_nameController.text, _currency)
                      : null,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text('Get started'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
