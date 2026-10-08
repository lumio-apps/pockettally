import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../models.dart';
import 'entry_form_screen.dart';
import 'settings_screen.dart';

const Color kIncomeColor = Color(0xFF2E9E5B);
const Color kExpenseColor = Color(0xFFD64545);

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.state});

  final AppState state;

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
                tooltip: 'Settings',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => SettingsScreen(state: state)),
                ),
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
      widgets.add(_EntryTile(
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
    if (day == t.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat('EEE, d MMM y').format(day);
  }

  void _openForm(BuildContext context, {Entry? entry}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EntryFormScreen(state: state, entry: entry),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.state,
    required this.month,
    required this.income,
    required this.expense,
  });

  final AppState state;
  final DateTime month;
  final int income;
  final int expense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final balance = income - expense;
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DateFormat('MMMM y').format(month),
                style: theme.textTheme.labelLarge),
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
          ],
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

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.entry,
    required this.state,
    required this.onTap,
  });

  final Entry entry;
  final AppState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = entry.isIncome ? kIncomeColor : kExpenseColor;
    final sign = entry.isIncome ? '+' : '-';

    final subtitleParts = <String>[
      if (entry.isIncome && entry.period != null)
        '${_periodLabel(entry.period!)} income',
      if (entry.note.isNotEmpty) entry.note,
    ];

    return Dismissible(
      key: ValueKey('entry_${entry.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: kExpenseColor,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) async {
        final messenger = ScaffoldMessenger.of(context);
        await state.deleteEntry(entry);
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: const Text('Entry deleted'),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () => state.restoreEntry(entry),
              ),
            ),
          );
      },
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(
            entry.isIncome ? Icons.south_west : Icons.north_east,
            color: color,
            size: 20,
          ),
        ),
        title: Text(entry.category),
        subtitle: subtitleParts.isEmpty ? null : Text(subtitleParts.join(' · ')),
        trailing: Text(
          '$sign ${state.formatMoney(entry.amountMinor)}',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  String _periodLabel(IncomePeriod p) {
    switch (p) {
      case IncomePeriod.daily:
        return 'Daily';
      case IncomePeriod.weekly:
        return 'Weekly';
      case IncomePeriod.monthly:
        return 'Monthly';
    }
  }
}
