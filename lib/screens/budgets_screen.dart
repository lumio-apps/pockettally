import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../l10n/l10n.dart';
import '../models.dart';
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
        final l = context.l10n;
        final now = DateTime.now();
        final limit = state.monthlyBudgetMinor;
        final categories = state.categoriesFor(EntryType.expense);

        return Scaffold(
          appBar: AppBar(title: Text(l.navBudgets)),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Text(DateFormat.yMMMM().format(now),
                  style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(l.monthlyBudget, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 12),
                      if (limit > 0)
                        BudgetBar(
                          state: state,
                          spent: state.expenseIn(now),
                          limit: limit,
                        )
                      else
                        Text(l.noMonthlyLimit),
                      const SizedBox(height: 8),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: TextButton(
                          onPressed: () => showMonthlyBudgetDialog(context, state),
                          child: Text(limit > 0 ? l.change : l.setMonthlyBudget),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(l.categoryLimits, style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(l.categoryLimitsHint,
                  style: theme.textTheme.bodySmall),
              const SizedBox(height: 8),
              for (final c in categories)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(radius: 10, backgroundColor: c.color),
                  title: Text(categoryLabel(l, c.name)),
                  subtitle: c.hasBudget
                      ? Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: BudgetBar(
                            state: state,
                            spent: state.expenseForCategory(c.name, now),
                            limit: c.budgetMinor!,
                          ),
                        )
                      : Text(l.noLimit),
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
        text: current > 0 ? widget.state.amountInput(current) : '');
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final v = widget.state.parseMinor(_amount.text);
    if (v == null || v <= 0) {
      setState(() => _error = context.l10n.enterAmountAboveZero);
      return;
    }
    await widget.state.setMonthlyBudget(v);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _remove() async {
    await widget.state.setMonthlyBudget(0);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final hasBudget = widget.state.monthlyBudgetMinor > 0;
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.monthlyBudget),
      content: TextField(
        controller: _amount,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
        decoration: InputDecoration(
          labelText: l.limitForAllExpenses,
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
          TextButton(onPressed: _remove, child: Text(l.remove)),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        FilledButton(onPressed: _save, child: Text(l.save)),
      ],
    );
  }
}
