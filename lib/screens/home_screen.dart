import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/entry_tile.dart';
import 'debts_screen.dart';
import 'entry_form_screen.dart';
import 'goals_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.state, required this.onOpenTab});

  final AppState state;

  /// Switches the bottom navigation tab (1 = Insights, 2 = Budgets).
  final ValueChanged<int> onOpenTab;

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final theme = Theme.of(context);
        final now = DateTime.now();
        final entries = state.entries;
        final name = state.userName;

        return Scaffold(
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: kBrand,
                      child: Text(
                        name.isEmpty ? '?' : name[0].toUpperCase(),
                        style: const TextStyle(
                            color: kAccent,
                            fontWeight: FontWeight.w800,
                            fontSize: 18),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_greeting(), style: theme.textTheme.bodySmall),
                          Text(
                            name,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                    IconButton.outlined(
                      tooltip: 'Search',
                      icon: const Icon(Icons.search),
                      onPressed: () =>
                          _push(context, SearchScreen(state: state)),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _BalanceCard(
                  state: state,
                  month: now,
                  onTap: () => onOpenTab(1),
                  onBudgetTap: () => onOpenTab(2),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _QuickAction(
                      icon: Icons.remove,
                      label: 'Expense',
                      background: const Color(0xFFFFE3DE),
                      foreground: const Color(0xFFB3261E),
                      onTap: () => _push(
                          context,
                          EntryFormScreen(
                              state: state, initialType: EntryType.expense)),
                    ),
                    _QuickAction(
                      icon: Icons.add,
                      label: 'Income',
                      background: const Color(0xFFD7F3E6),
                      foreground: const Color(0xFF1B6E4C),
                      onTap: () => _push(
                          context,
                          EntryFormScreen(
                              state: state, initialType: EntryType.income)),
                    ),
                    _QuickAction(
                      icon: Icons.handshake_outlined,
                      label: 'Lend/Borrow',
                      background: const Color(0xFFDDE6FA),
                      foreground: const Color(0xFF2F4DA8),
                      onTap: () => _push(context, DebtsScreen(state: state)),
                    ),
                    _QuickAction(
                      icon: Icons.savings_outlined,
                      label: 'Goals',
                      background: const Color(0xFFFFF0CC),
                      foreground: const Color(0xFF8A5A00),
                      onTap: () => _push(context, GoalsScreen(state: state)),
                    ),
                  ],
                ),
                if (state.toReceiveMinor > 0 || state.toPayMinor > 0) ...[
                  const SizedBox(height: 16),
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => _push(context, DebtsScreen(state: state)),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Expanded(
                              child: _MiniStat(
                                label: "You'll get",
                                value: state.formatMoney(state.toReceiveMinor),
                                color: kIncomeColor,
                              ),
                            ),
                            Expanded(
                              child: _MiniStat(
                                label: 'You owe',
                                value: state.formatMoney(state.toPayMinor),
                                color: kExpenseColor,
                              ),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Text('Recent',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                if (entries.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(28),
                      child: Text(
                        'No entries yet.\nTap + to record your first income or expense.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  ..._buildGroupedList(context, entries),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildGroupedList(BuildContext context, List<Entry> entries) {
    final theme = Theme.of(context);
    final groups = <DateTime, List<Entry>>{};
    for (final e in entries) {
      final day = DateTime(e.date.year, e.date.month, e.date.day);
      groups.putIfAbsent(day, () => []).add(e);
    }
    final widgets = <Widget>[];
    for (final day in groups.keys) {
      widgets.add(Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
        child: Text(_dayLabel(day),
            style: theme.textTheme.labelLarge
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ));
      widgets.add(Card(
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              for (final e in groups[day]!)
                EntryTile(
                  entry: e,
                  state: state,
                  onTap: () => _push(
                      context, EntryFormScreen(state: state, entry: e)),
                ),
            ],
          ),
        ),
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
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.state,
    required this.month,
    required this.onTap,
    required this.onBudgetTap,
  });

  final AppState state;
  final DateTime month;
  final VoidCallback onTap;
  final VoidCallback onBudgetTap;

  @override
  Widget build(BuildContext context) {
    final income = state.incomeIn(month);
    final expense = state.expenseIn(month);
    final balance = income - expense;
    final limit = state.monthlyBudgetMinor;
    final over = state.overBudgetCategories(month);
    const label = TextStyle(color: Color(0xFFA9DCC8), fontSize: 13);

    return Material(
      color: kBrand,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${DateFormat('MMMM').format(month)} balance',
                  style: label.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  state.formatMoney(balance),
                  style: TextStyle(
                    color: balance < 0 ? const Color(0xFFFFB4A8) : Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _Tile(
                      label: 'Income',
                      value: '+ ${state.formatMoney(income)}',
                      color: kMint,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Tile(
                      label: 'Expenses',
                      value: '- ${state.formatMoney(expense)}',
                      color: const Color(0xFFFFB4A8),
                    ),
                  ),
                ],
              ),
              if (limit > 0 || over.isNotEmpty)
                InkWell(
                  onTap: onBudgetTap,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (limit > 0) ...[
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                    'Monthly budget ${state.formatMoney(limit)}',
                                    style: label),
                              ),
                              Text(
                                expense > limit
                                    ? 'Over by ${state.formatMoney(expense - limit)}'
                                    : '${(expense / limit * 100).round()}% used',
                                style: label.copyWith(
                                  color: expense > limit
                                      ? const Color(0xFFFFB4A8)
                                      : null,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (expense / limit).clamp(0.0, 1.0),
                              minHeight: 8,
                              color: expense > limit
                                  ? const Color(0xFFFF8A7A)
                                  : kAccent,
                              backgroundColor: kBrandSoft,
                            ),
                          ),
                        ],
                        if (over.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded,
                                  size: 16, color: kAccent),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  over.length == 1
                                      ? '${over.first.name} is over its limit'
                                      : '${over.length} categories are over their limit',
                                  style: label.copyWith(
                                      color: kAccent,
                                      fontWeight: FontWeight.w700),
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
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kBrandSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: Color(0xFFA9DCC8), fontSize: 12)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: TextStyle(
                    color: color, fontSize: 16, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: foreground),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat(
      {required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w800, fontSize: 15)),
        ),
      ],
    );
  }
}
