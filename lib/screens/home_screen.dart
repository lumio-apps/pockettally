import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../models.dart';
import '../widgets/budget_bar.dart';
import '../widgets/entry_tile.dart';
import 'budgets_screen.dart';
import 'entry_form_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.state});

  final AppState state;

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final now = DateTime.now();
        final income = state.incomeIn(now);
        final expense = state.expenseIn(now);
        final entries = state.entries;

        return Scaffold(
          appBar: AppBar(
            title: const Text('PocketTally'),
            actions: [
              IconButton(
                tooltip: 'Search',
                icon: const Icon(Icons.search),
                onPressed: () => _push(context, SearchScreen(state: state)),
              ),
              IconButton(
                tooltip: 'Stats',
                icon: const Icon(Icons.pie_chart_outline),
                onPressed: () => _push(context, StatsScreen(state: state)),
              ),
              IconButton(
                tooltip: 'Settings',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => _push(context, SettingsScreen(state: state)),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openForm(context),
            icon: const Icon(Icons.add),
            label: const Text('Add'),
          ),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  'Hello, ${state.userName}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              _SummaryCard(
                state: state,
                month: now,
                income: income,
                expense: expense,
                onTap: () => _push(context, StatsScreen(state: state)),
                onBudgetTap: () => _push(context, BudgetsScreen(state: state)),
              ),
              if (entries.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      'No entries yet.\nTap Add to record your first income or expense.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                ..._buildGroupedList(context, entries),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildGroupedList(BuildContext context, List<Entry> entries) {
    final widgets = <Widget>[];
    DateTime? lastDay;
    for (final e in entries) {
      final day = DateTime(e.date.year, e.date.month, e.date.day);
      if (lastDay != day) {
        widgets.add(Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            _dayLabel(day),
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ));
        lastDay = day;
      }
      widgets.add(EntryTile(
        entry: e,
        state: state,
        onTap: () => _openForm(context, entry: e),
      ));
    }
    return widgets;
  }

  String _dayLabel(DateTime day) {
    final today = DateTime.now();
    final t = DateTime(today.year, today.month, today.day);
    if (day == t) return 'Today';
    if (day == DateTime(t.year, t.month, t.day - 1)) return 'Yesterday';
    return DateFormat('EEE, d MMM y').format(day);
  }

  void _openForm(BuildContext context, {Entry? entry}) {
    _push(context, EntryFormScreen(state: state, entry: entry));
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.state,
    required this.month,
    required this.income,
    required this.expense,
    required this.onTap,
    required this.onBudgetTap,
  });

  final AppState state;
  final DateTime month;
  final int income;
  final int expense;
  final VoidCallback onTap;
  final VoidCallback onBudgetTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final balance = income - expense;
    final limit = state.monthlyBudgetMinor;
    final over = state.overBudgetCategories(month);
    return Card(
      margin: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(DateFormat('MMMM y').format(month),
                      style: theme.textTheme.labelLarge),
                  const Spacer(),
                  Icon(Icons.chevron_right,
                      size: 18, color: theme.colorScheme.outline),
                ],
              ),
              const SizedBox(height: 4),
              Text('Balance', style: theme.textTheme.bodySmall),
              Text(
                state.formatMoney(balance),
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: balance < 0 ? kExpenseColor : null,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _Stat(
                      label: 'Income',
                      value: state.formatMoney(income),
                      color: kIncomeColor,
                    ),
                  ),
                  Expanded(
                    child: _Stat(
                      label: 'Expenses',
                      value: state.formatMoney(expense),
                      color: kExpenseColor,
                    ),
                  ),
                ],
              ),
              if (limit > 0 || over.isNotEmpty) ...[
                const SizedBox(height: 14),
                InkWell(
                  onTap: onBudgetTap,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (limit > 0)
                          BudgetBar(
                            state: state,
                            spent: expense,
                            limit: limit,
                            label: 'Monthly budget',
                          ),
                        if (over.isNotEmpty) ...[
                          if (limit > 0) const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded,
                                  size: 18, color: kWarningColor),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  over.length == 1
                                      ? '${over.first.name} is over its limit'
                                      : '${over.length} categories are over their limit',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      color: kWarningColor,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall),
        Text(
          value,
          style: theme.textTheme.titleMedium
              ?.copyWith(color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
