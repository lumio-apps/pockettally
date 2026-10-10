import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../models.dart';
import '../utils/amount_parser.dart';
import '../widgets/budget_bar.dart';
import 'categories_screen.dart';

/// Monthly budget and per-category limits for the current month.
class BudgetsScreen extends StatelessWidget {
  const BudgetsScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final theme = Theme.of(context);
        final now = DateTime.now();
        final limit = state.monthlyBudgetMinor;
        final categories = state.categoriesFor(EntryType.expense);

        return Scaffold(
          appBar: AppBar(title: const Text('Budgets')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Text(DateFormat('MMMM y').format(now),
                  style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Monthly budget', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 12),
                      if (limit > 0)
                        BudgetBar(
                          state: state,
                          spent: state.expenseIn(now),
                          limit: limit,
                        )
                      else
                        const Text('No monthly limit set.'),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => showMonthlyBudgetDialog(context, state),
                          child: Text(limit > 0 ? 'Change' : 'Set monthly budget'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('Category limits', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text('Tap a category to set or change its monthly limit.',
                  style: theme.textTheme.bodySmall),
              const SizedBox(height: 8),
              for (final c in categories)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(radius: 10, backgroundColor: c.color),
                  title: Text(c.name),
                  subtitle: c.hasBudget
                      ? Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: BudgetBar(
                            state: state,
                            spent: state.expenseForCategory(c.name, now),
                            limit: c.budgetMinor!,
                          ),
                        )
                      : const Text('No limit'),
                  onTap: () => showCategoryDialog(
                    context,
                    state,
                    type: EntryType.expense,
                    existing: c,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Dialog to set, change or remove the monthly budget.
Future<void> showMonthlyBudgetDialog(BuildContext context, AppState state) {
  return showDialog<void>(
    context: context,
    builder: (_) => _MonthlyBudgetDialog(state: state),
  );
}

class _MonthlyBudgetDialog extends StatefulWidget {
  const _MonthlyBudgetDialog({required this.state});

  final AppState state;

  @override
  State<_MonthlyBudgetDialog> createState() => _MonthlyBudgetDialogState();
}

class _MonthlyBudgetDialogState extends State<_MonthlyBudgetDialog> {
  late final TextEditingController _amount;
  String? _error;

  @override
  void initState() {
    super.initState();
    final current = widget.state.monthlyBudgetMinor;
    _amount = TextEditingController(
        text: current > 0 ? (current / 100).toStringAsFixed(2) : '');
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final v = evaluateAmount(_amount.text);
    if (v == null || (v * 100).round() <= 0) {
      setState(() => _error = 'Enter an amount greater than 0');
      return;
    }
    await widget.state.setMonthlyBudget((v * 100).round());
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _remove() async {
    await widget.state.setMonthlyBudget(0);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final hasBudget = widget.state.monthlyBudgetMinor > 0;
    return AlertDialog(
      title: const Text('Monthly budget'),
      content: TextField(
        controller: _amount,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
        decoration: InputDecoration(
          labelText: 'Limit for all expenses',
          prefixText: '${widget.state.currency.symbol} ',
          errorText: _error,
          border: const OutlineInputBorder(),
        ),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
      ),
      actions: [
        if (hasBudget)
          TextButton(onPressed: _remove, child: const Text('Remove')),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
