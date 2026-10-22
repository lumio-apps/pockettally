import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../l10n/l10n.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/entry_tile.dart';
import '../widgets/neo.dart';
import '../widgets/pie_chart.dart';
import '../widgets/profile_avatar.dart';
import 'app_page.dart';
import 'calendar_screen.dart';
import 'entry_form_screen.dart';
import 'goals_screen.dart';
import 'profile_screen.dart';
import 'wallets_screen.dart';

/// How many of the newest entries Home shows under "Recent".
const int kRecentEntries = 50;

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.state, required this.onOpenTab});

  final AppState state;

  /// Opens another page of the app (a tab, or its own screen).
  final ValueChanged<AppPage> onOpenTab;

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

        final sections = <Widget>[
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_greeting(l), style: theme.textTheme.bodyMedium),
                    Text(
                      name,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              IconButton.outlined(
                tooltip: l.calendar,
                icon: const Icon(Icons.calendar_month_outlined),
                onPressed: () => _push(context, CalendarScreen(state: state)),
              ),
              const SizedBox(width: 8),
              Semantics(
                button: true,
                label: l.profile,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => _push(context, ProfileScreen(state: state)),
                  child: ProfileAvatar(state: state, radius: 22),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _BalanceHero(
            state: state,
            month: now,
            onTap: () => onOpenTab(AppPage.insights),
          ),
          const SizedBox(height: 12),
          if (state.wallets.length > 1) ...[
            _WalletsCard(state: state),
            const SizedBox(height: 12),
          ],
          _OverviewCard(
            state: state,
            month: now,
            onBudgetTap: () => onOpenTab(AppPage.budgets),
            onTap: () => onOpenTab(AppPage.insights),
          ),
          const SizedBox(height: 18),
          Text(l.quickActions,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Row(
            children: [
              _QuickAction(
                icon: Icons.remove,
                label: l.expense,
                color: kExpenseColor,
                onTap: () => _push(context,
                    EntryFormScreen(state: state, initialType: EntryType.expense)),
              ),
              _QuickAction(
                icon: Icons.add,
                label: l.income,
                color: kIncomeColor,
                onTap: () => _push(context,
                    EntryFormScreen(state: state, initialType: EntryType.income)),
              ),
              _QuickAction(
                icon: Icons.handshake_outlined,
                label: l.lendBorrowShort,
                color: const Color(0xFF2F6BFF),
                onTap: () => onOpenTab(AppPage.lendBorrow),
              ),
              _QuickAction(
                icon: Icons.savings_outlined,
                label: l.goals,
                color: const Color(0xFF8E44AD),
                onTap: () => _push(context, GoalsScreen(state: state)),
              ),
            ],
          ),
          if (_upcoming(state).isNotEmpty) ...[
            const SizedBox(height: 16),
            _UpcomingCard(state: state, rules: _upcoming(state)),
          ],
          if (state.favorites.isNotEmpty) ...[
            const SizedBox(height: 16),
            _FavoritesRow(state: state),
          ],
          if (state.toReceiveMinor > 0 || state.toPayMinor > 0) ...[
            const SizedBox(height: 16),
            NeoCard(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onOpenTab(AppPage.lendBorrow),
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
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: Text(l.recent,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
              ),
              if (entries.isNotEmpty)
                TextButton(
                  onPressed: () => onOpenTab(AppPage.entries),
                  child: Text(l.seeAll),
                ),
            ],
          ),
          if (entries.isEmpty)
            NeoCard(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Text(l.noEntriesYet, textAlign: TextAlign.center),
              ),
            )
          else ...[
            // Only the newest entries, so Home stays fast with years of
            // data; the Entries tab shows everything.
            ..._buildGroupedList(
                context, entries.take(kRecentEntries).toList()),
            if (entries.length > kRecentEntries)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Center(
                  child: TextButton.icon(
                    icon: const Icon(Icons.list_alt_outlined),
                    label: Text(l.seeAllEntries),
                    onPressed: () => onOpenTab(AppPage.entries),
                  ),
                ),
              ),
          ],
        ];

        return Scaffold(
          body: SafeArea(
            child: ListView.builder(
              // Room at the bottom so the + button never covers the last
              // entry's amount.
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
              itemCount: sections.length,
              itemBuilder: (context, i) => sections[i],
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
      widgets.add(NeoCard(
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

/// This month's balance, income and expenses on one solid accent card, with
/// an eye button to hide the amounts (e.g. when others can see the screen).
class _BalanceHero extends StatelessWidget {
  const _BalanceHero({
    required this.state,
    required this.month,
    required this.onTap,
  });

  final AppState state;
  final DateTime month;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final brand = BrandColors.of(context).brand;
    final income = state.incomeIn(month);
    final expense = state.expenseIn(month);
    final balance = income - expense;
    final hidden = state.hideBalance;
    String money(int v) => hidden ? '••••' : state.formatMoney(v);
    Widget stat(String label, int amount, IconData icon) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 14, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(label,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(money(amount),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        );
    return Material(
      color: brand,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 8, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l.monthBalance(DateFormat.MMMM().format(month)),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    tooltip: hidden ? l.showBalance : l.hideBalance,
                    color: Colors.white,
                    icon: Icon(hidden
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    onPressed: () => state.setHideBalance(!hidden),
                  ),
                ],
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  hidden ? '••••••' : state.formatMoney(balance),
                  style: TextStyle(
                    color: balance < 0
                        ? const Color(0xFFFFD2CC)
                        : Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 12),
                child: Row(
                  children: [
                    stat(l.income, income, Icons.south_west),
                    const SizedBox(width: 12),
                    stat(l.expenses, expense, Icons.north_east),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One chip per wallet with what is in it (only shown when there is more
/// than one wallet).
class _WalletsCard extends StatelessWidget {
  const _WalletsCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final hide = state.hideBalance;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final w in state.wallets)
          ActionChip(
            avatar:
                CircleAvatar(radius: 6, backgroundColor: Color(w.colorValue)),
            label: Text(
                '${w.name}  ${hide ? '••••' : state.formatMoney(state.walletBalance(w))}'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => WalletsScreen(state: state))),
          ),
      ],
    );
  }
}

/// "Spending overview": a donut of this month's expenses by category, and
/// the monthly budget.
class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.state,
    required this.month,
    required this.onBudgetTap,
    required this.onTap,
  });

  final AppState state;
  final DateTime month;
  final VoidCallback onBudgetTap;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    final expense = state.expenseIn(month);
    final byCategory = <String, int>{};
    for (final e in state.entriesInMonth(month)) {
      if (e.isIncome) continue;
      byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amountMinor;
    }
    final rows = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final limit = state.monthlyLimitFor(month);
    final carried = state.carriedOverInto(month);
    final over = state.overBudgetCategories(month);

    return NeoCard(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.spendingOverview,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              if (rows.isEmpty)
                Text(l.noExpensesInPeriod, style: theme.textTheme.bodyMedium)
              else
                Row(
                  children: [
                    PieChart(
                      size: 104,
                      slices: [
                        for (final r in rows)
                          PieSlice(r.value.toDouble(),
                              state.colorFor(r.key, EntryType.expense)),
                      ],
                      center: Icon(Icons.pie_chart_outline,
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        children: [
                          for (final r in rows.take(4))
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 5,
                                    backgroundColor: state.colorFor(
                                        r.key, EntryType.expense),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(categoryLabel(l, r.key),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                  Text(
                                      '${(r.value * 100 / expense).round()}%',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              if (limit > 0 || over.isNotEmpty) ...[
                const SizedBox(height: 14),
                InkWell(
                  onTap: onBudgetTap,
                  borderRadius: BorderRadius.circular(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (limit > 0) ...[
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                carried > 0
                                    ? '${l.monthlyBudgetAmount(state.formatMoney(limit))}'
                                        ' (+${state.formatMoney(carried)})'
                                    : l.monthlyBudgetAmount(
                                        state.formatMoney(limit)),
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                            Text(
                              expense > limit
                                  ? l.overBy(state.formatMoney(expense - limit))
                                  : l.percentUsed(
                                      (expense / limit * 100).round().toString()),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: expense > limit ? kExpenseColor : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(
                                begin: 0,
                                end: (expense / limit).clamp(0.0, 1.0)),
                            duration: const Duration(milliseconds: 700),
                            curve: Curves.easeOutCubic,
                            builder: (context, v, _) => LinearProgressIndicator(
                              value: v,
                              minHeight: 8,
                              color: expense > limit ? kExpenseColor : kAccent,
                              backgroundColor:
                                  theme.colorScheme.surfaceContainerHighest,
                            ),
                          ),
                        ),
                      ],
                      if (over.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                size: 16, color: kExpenseColor),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                over.length == 1
                                    ? l.categoryOverLimit(
                                        categoryLabel(l, over.first.name))
                                    : l.categoriesOverLimit(over.length),
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: kExpenseColor,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
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

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: NeoCard(
          radius: 20,
          onTap: onTap,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Column(
            children: [
              NeoInset(
                radius: 20,
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(icon,
                      color:
                          dark ? Color.lerp(color, Colors.white, 0.4) : color),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
        duration: const Duration(seconds: 3),
        persist: false,
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

/// Recurring entries due in the next 7 days, soonest first (at most 3).
List<RecurringRule> _upcoming(AppState state) {
  final now = DateTime.now();
  final limit = DateTime(now.year, now.month, now.day + 8);
  final list = state.recurring
      .where((r) => !r.paused && r.nextDate.isBefore(limit))
      .toList()
    ..sort((a, b) => a.nextDate.compareTo(b.nextDate));
  return list.take(3).toList();
}

/// "Upcoming: Rent, tomorrow" so bills are not a surprise.
class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard({required this.state, required this.rules});

  final AppState state;
  final List<RecurringRule> rules;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    return NeoCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event_repeat,
                    size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(l.upcoming,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 6),
            for (final r in rules)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        r.note.isNotEmpty
                            ? r.note
                            : categoryLabel(l, r.category),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      r.nextDate == tomorrow
                          ? l.tomorrow
                          : DateFormat.MMMEd().format(r.nextDate),
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${r.type == EntryType.income ? '+' : '-'} '
                      '${state.formatMoney(r.amountMinor)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: r.type == EntryType.income
                            ? kIncomeColor
                            : kExpenseColor,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
