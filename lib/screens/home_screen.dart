import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../l10n/l10n.dart';
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

  String _greeting(AppLocalizations l) {
    final h = DateTime.now().hour;
    if (h < 12) return l.goodMorning;
    if (h < 17) return l.goodAfternoon;
    return l.goodEvening;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final theme = Theme.of(context);
        final l = context.l10n;
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
                      backgroundColor: BrandColors.of(context).brand,
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
                          Text(_greeting(l), style: theme.textTheme.bodySmall),
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
                      tooltip: l.search,
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
                      label: l.expense,
                      background: const Color(0xFFFFE3DE),
                      foreground: const Color(0xFFB3261E),
                      onTap: () => _push(
                          context,
                          EntryFormScreen(
                              state: state, initialType: EntryType.expense)),
                    ),
                    _QuickAction(
                      icon: Icons.add,
                      label: l.income,
                      background: const Color(0xFFD7F3E6),
                      foreground: const Color(0xFF1B6E4C),
                      onTap: () => _push(
                          context,
                          EntryFormScreen(
                              state: state, initialType: EntryType.income)),
                    ),
                    _QuickAction(
                      icon: Icons.handshake_outlined,
                      label: l.lendBorrowShort,
                      background: const Color(0xFFDDE6FA),
                      foreground: const Color(0xFF2F4DA8),
                      onTap: () => _push(context, DebtsScreen(state: state)),
                    ),
                    _QuickAction(
                      icon: Icons.savings_outlined,
                      label: l.goals,
                      background: const Color(0xFFFFF0CC),
                      foreground: const Color(0xFF8A5A00),
                      onTap: () => _push(context, GoalsScreen(state: state)),
                    ),
                  ],
                ),
                if (state.favorites.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _FavoritesRow(state: state),
                ],
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
                                label: l.youWillGet,
                                value: state.formatMoney(state.toReceiveMinor),
                                color: kIncomeColor,
                              ),
                            ),
                            Expanded(
                              child: _MiniStat(
                                label: l.youOwe,
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
                Text(l.recent,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                if (entries.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Text(
                        l.noEntriesYet,
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
        child: Text(_dayLabel(context.l10n, day),
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

  String _dayLabel(AppLocalizations l, DateTime day) {
    final today = DateTime.now();
    final t = DateTime(today.year, today.month, today.day);
    if (day == t) return l.today;
    if (day == DateTime(t.year, t.month, t.day - 1)) return l.yesterday;
    return DateFormat.yMMMEd().format(day);
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
    final brand = BrandColors.of(context);
    final l = context.l10n;
    final label = TextStyle(color: brand.label, fontSize: 13);

    return Material(
      color: brand.brand,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.monthBalance(DateFormat.MMMM().format(month)),
                  style: label.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
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
                      label: l.income,
                      value: '+ ${state.formatMoney(income)}',
                      color: kMint,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Tile(
                      label: l.expenses,
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
                                    l.monthlyBudgetAmount(
                                        state.formatMoney(limit)),
                                    style: label),
                              ),
                              Text(
                                expense > limit
                                    ? l.overBy(
                                        state.formatMoney(expense - limit))
                                    : l.percentUsed(
                                        (expense / limit * 100).round().toString()),
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
                              backgroundColor: brand.brandSoft,
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
                                      ? l.categoryOverLimit(
                                          categoryLabel(l, over.first.name))
                                      : l.categoriesOverLimit(over.length),
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
    final brand = BrandColors.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: brand.brandSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: brand.label, fontSize: 12)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
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
          alignment: AlignmentDirectional.centerStart,
          child: Text(value,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w800, fontSize: 15)),
        ),
      ],
    );
  }
}

/// One-tap entries saved with the star in the entry form.
class _FavoritesRow extends StatelessWidget {
  const _FavoritesRow({required this.state});

  final AppState state;

  Future<void> _add(BuildContext context, Favorite f) async {
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    final entry = await state.addFromFavorite(f);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(l.favoriteAdded(
            '${categoryLabel(l, f.category)} ${state.formatMoney(f.amountMinor)}')),
        action: SnackBarAction(
          label: l.undo,
          onPressed: () => state.deleteEntry(entry),
        ),
      ));
  }

  Future<void> _remove(BuildContext context, Favorite f) async {
    final l = context.l10n;
    final name = f.note.isNotEmpty ? f.note : categoryLabel(l, f.category);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.removeFavoriteQuestion(name)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.remove)),
        ],
      ),
    );
    if (ok == true) await state.deleteFavorite(f);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(l.favorites,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(l.favoritesHint,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: state.favorites.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final f = state.favorites[i];
              final color = f.type == EntryType.income
                  ? kIncomeColor
                  : kExpenseColor;
              final label = f.note.isNotEmpty
                  ? f.note
                  : categoryLabel(l, f.category);
              return GestureDetector(
                onLongPress: () => _remove(context, f),
                child: ActionChip(
                  avatar: Icon(Icons.star_rounded, size: 18, color: color),
                  label: Text('$label  ${state.formatMoney(f.amountMinor)}'),
                  onPressed: () => _add(context, f),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
