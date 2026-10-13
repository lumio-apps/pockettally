import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../insights.dart';
import '../l10n/l10n.dart';
import '../models.dart';
import '../report_range.dart';
import '../theme.dart';
import '../widgets/appear.dart';
import '../widgets/bar_chart.dart';
import '../widgets/pie_chart.dart';
import 'report_options_screen.dart';

/// Reports for a week, a month or a year: net savings with the change from
/// the period before, where the money went, and income against expenses
/// over time.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key, required this.state});

  final AppState state;

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  ReportPeriod _period = ReportPeriod.month;
  DateTime _anchor = DateTime.now();
  EntryType _pieType = EntryType.expense;

  AppState get state => widget.state;

  /// Start (inclusive) and end (exclusive) of the selected period.
  (DateTime, DateTime) get _range => periodRange(_period, _anchor,
      weekStartsOnSunday: state.weekStartsOnSunday);

  void _shift(int direction) {
    final (start, _) = _range;
    setState(() {
      _anchor = switch (_period) {
        ReportPeriod.week =>
          DateTime(start.year, start.month, start.day + 7 * direction),
        ReportPeriod.month => DateTime(start.year, start.month + direction, 1),
        ReportPeriod.year => DateTime(start.year + direction, 1, 1),
      };
    });
  }

  /// "October 2026" etc.
  String _rangeLabel(DateTime start, DateTime end) {
    switch (_period) {
      case ReportPeriod.week:
        final last = DateTime(end.year, end.month, end.day - 1);
        return '${DateFormat.MMMd().format(start)} – '
            '${DateFormat.yMMMd().format(last)}';
      case ReportPeriod.month:
        return DateFormat.yMMMM().format(start);
      case ReportPeriod.year:
        return '${start.year}';
    }
  }

  /// "+₹ 2,300 vs last month".
  String _vs(AppLocalizations l, String change) {
    switch (_period) {
      case ReportPeriod.week:
        return l.changeVsLastWeek(change);
      case ReportPeriod.month:
        return l.changeVsLastMonth(change);
      case ReportPeriod.year:
        return l.changeVsLastYear(change);
    }
  }

  /// Opens one month of the year view.
  void _openMonth(int year, int month) {
    setState(() {
      _period = ReportPeriod.month;
      _anchor = DateTime(year, month, 1);
    });
  }

  /// Opens the PDF page for the period shown.
  void _openPdf(DateTime start, DateTime end) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          ReportOptionsScreen(state: state, start: start, end: end),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final theme = Theme.of(context);
        final l = context.l10n;
        final now = DateTime.now();
        final (start, end) = _range;
        final list = state.entriesBetween(start, end);
        final (prevStart, prevEnd) =
            previousComparable(_period, start, end, now);
        final previous = state.entriesBetween(prevStart, prevEnd);
        // No "next" when the next period would start in the future.
        final canGoForward = !end.isAfter(now);

        final sections = <Widget>[
          SegmentedButton<ReportPeriod>(
            segments: [
              ButtonSegment(value: ReportPeriod.week, label: Text(l.week)),
              ButtonSegment(value: ReportPeriod.month, label: Text(l.month)),
              ButtonSegment(value: ReportPeriod.year, label: Text(l.year)),
            ],
            showSelectedIcon: false,
            selected: {_period},
            onSelectionChanged: (s) => setState(() {
              _period = s.first;
              _anchor = DateTime.now();
            }),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                IconButton(
                  tooltip: l.previous,
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _shift(-1),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      _rangeLabel(start, end),
                      key: ValueKey(start),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l.next,
                  icon: const Icon(Icons.chevron_right),
                  onPressed: canGoForward ? () => _shift(1) : null,
                ),
              ],
            ),
          ),
          _SummaryCard(
            state: state,
            income: AppState.sumIncome(list),
            expense: AppState.sumExpense(list),
            previousIncome: AppState.sumIncome(previous),
            previousExpense: AppState.sumExpense(previous),
            hasPrevious: previous.isNotEmpty,
            vs: (change) => _vs(l, change),
          ),
          const SizedBox(height: 16),
          _CategoryCard(
            // A new key makes the donut draw itself again for a new period.
            key: ValueKey('cat-$_period-$start-$_pieType'),
            state: state,
            entries: list,
            type: _pieType,
            onType: (t) => setState(() => _pieType = t),
          ),
          const SizedBox(height: 16),
          _TrendCard(
            key: ValueKey('trend-$_period-$start'),
            state: state,
            period: _period,
            start: start,
          ),
          if (_period == ReportPeriod.month) ..._highlights(theme, l, start),
          if (_period == ReportPeriod.year) ..._monthRows(theme, l, start.year),
        ];

        return Scaffold(
          appBar: AppBar(
            title: Text(l.reports),
            actions: [
              IconButton(
                tooltip: l.saveAsPdf,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                onPressed: () => _openPdf(start, end),
              ),
            ],
          ),
          body: ListView.builder(
            // Room at the bottom for the + button.
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
            itemCount: sections.length,
            itemBuilder: (context, i) => Appear(index: i, child: sections[i]),
          ),
        );
      },
    );
  }

  String _insightText(AppLocalizations l, Insight i) {
    final cat = i.category == null ? '' : categoryLabel(l, i.category!);
    final amount = state.formatMoney(i.amountMinor);
    switch (i.kind) {
      case InsightKind.spentLess:
        return l.insightSpentLess(i.percent.toString());
      case InsightKind.spentMore:
        return l.insightSpentMore(i.percent.toString());
      case InsightKind.topCategory:
        return l.insightTopCategory(cat, amount, i.percent.toString());
      case InsightKind.categoryUp:
        return l.insightCategoryUp(cat, amount);
      case InsightKind.dailyAverage:
        return l.insightDailyAverage(amount);
      case InsightKind.savedShare:
        return l.insightSaved(i.percent.toString());
      case InsightKind.overspent:
        return l.insightOverspent(amount);
    }
  }

  IconData _insightIcon(InsightKind k) {
    switch (k) {
      case InsightKind.spentLess:
        return Icons.trending_down;
      case InsightKind.spentMore:
        return Icons.trending_up;
      case InsightKind.topCategory:
        return Icons.pie_chart_outline;
      case InsightKind.categoryUp:
        return Icons.arrow_upward;
      case InsightKind.dailyAverage:
        return Icons.today_outlined;
      case InsightKind.savedShare:
        return Icons.savings_outlined;
      case InsightKind.overspent:
        return Icons.warning_amber_rounded;
    }
  }

  /// "You spent 12% less than last month" and similar, for one month.
  List<Widget> _highlights(ThemeData theme, AppLocalizations l, DateTime month) {
    final list = monthInsights(state.entries, month, DateTime.now());
    if (list.isEmpty) return const [];
    return [
      const SizedBox(height: 16),
      Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.highlights,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              for (final i in list)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_insightIcon(i.kind),
                        size: 19, color: theme.colorScheme.primary),
                  ),
                  title: Text(_insightText(l, i),
                      style: theme.textTheme.bodyMedium),
                ),
            ],
          ),
        ),
      ),
    ];
  }

  /// Each month of [year] with its income, expenses and balance; a tap
  /// opens that month.
  List<Widget> _monthRows(ThemeData theme, AppLocalizations l, int year) {
    final now = DateTime.now();
    if (year > now.year) return const [];
    final lastMonth = year == now.year ? now.month : 12;
    final colors = ReportColors.of(context);
    final rows = <Widget>[];
    for (var m = lastMonth; m >= 1; m--) {
      final list = state.entriesBetween(
          DateTime(year, m, 1), DateTime(year, m + 1, 1));
      final inc = AppState.sumIncome(list);
      final exp = AppState.sumExpense(list);
      final bal = inc - exp;
      rows.add(ListTile(
        title: Text(DateFormat.MMMM().format(DateTime(year, m, 1)),
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text.rich(TextSpan(children: [
          TextSpan(
              text: '+ ${state.formatMoney(inc)}',
              style: TextStyle(color: colors.income)),
          const TextSpan(text: '   '),
          TextSpan(
              text: '- ${state.formatMoney(exp)}',
              style: TextStyle(color: colors.expense)),
        ])),
        trailing: Text(
          state.formatMoney(bal),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: bal < 0 ? colors.expense : null,
          ),
        ),
        onTap: () => _openMonth(year, m),
      ));
    }
    return [
      const SizedBox(height: 16),
      Card(
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(children: rows),
        ),
      ),
    ];
  }
}

/// Income and expense colors for charts, a little lighter in dark mode.
class ReportColors {
  const ReportColors(this.income, this.expense);

  final Color income;
  final Color expense;

  static ReportColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const ReportColors(Color(0xFF7BE0B5), Color(0xFFFFB4A8))
          : const ReportColors(Color(0xFF1E9E63), Color(0xFFE5533D));
}

/// The big colored card: net savings, the change from the period before,
/// and income and expenses with their change in percent.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.state,
    required this.income,
    required this.expense,
    required this.previousIncome,
    required this.previousExpense,
    required this.hasPrevious,
    required this.vs,
  });

  final AppState state;
  final int income;
  final int expense;
  final int previousIncome;
  final int previousExpense;

  /// False when the period before has no entries (nothing to compare).
  final bool hasPrevious;

  /// "{change} vs last month" for the selected period.
  final String Function(String change) vs;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final brand = BrandColors.of(context);
    final net = income - expense;
    final difference = net - (previousIncome - previousExpense);
    final labelStyle = TextStyle(
        color: brand.label, fontSize: 13, fontWeight: FontWeight.w600);
    final String rateText;
    if (income <= 0) {
      rateText = '';
    } else if (income >= expense) {
      rateText = l.insightSaved(((income - expense) * 100 / income).round().toString());
    } else {
      rateText = l.insightOverspent(state.formatMoney(expense - income));
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            brand.brand,
            Color.lerp(brand.brand, Colors.black, 0.28)!,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.savings_outlined, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.netSavings, style: labelStyle),
                    const SizedBox(height: 2),
                    CountUp(
                      value: net,
                      format: state.formatMoney,
                      style: TextStyle(
                        color: net < 0 ? const Color(0xFFFFC2B8) : Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hasPrevious) ...[
            const SizedBox(height: 10),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: _Pill(
                icon: difference >= 0 ? Icons.trending_up : Icons.trending_down,
                text: vs(difference >= 0
                    ? '+${state.formatMoney(difference)}'
                    : state.formatMoney(difference)),
                good: difference >= 0,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MiniTotal(
                  label: l.income,
                  icon: Icons.south_west,
                  amount: state.formatMoney(income),
                  change: hasPrevious ? percentChange(income, previousIncome) : null,
                  goodWhenUp: true,
                  vs: vs,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniTotal(
                  label: l.expenses,
                  icon: Icons.north_east,
                  amount: state.formatMoney(expense),
                  change:
                      hasPrevious ? percentChange(expense, previousExpense) : null,
                  goodWhenUp: false,
                  vs: vs,
                ),
              ),
            ],
          ),
          if (rateText.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(rateText, style: labelStyle),
          ],
        ],
      ),
    );
  }
}

/// A small rounded label on the colored card, green-ish when [good].
class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text, required this.good});

  final IconData icon;
  final String text;
  final bool good;

  @override
  Widget build(BuildContext context) {
    final color = good ? const Color(0xFFB9F6CA) : const Color(0xFFFFCDD2);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// Income or expenses inside the colored card, with the change in percent.
class _MiniTotal extends StatelessWidget {
  const _MiniTotal({
    required this.label,
    required this.icon,
    required this.amount,
    required this.change,
    required this.goodWhenUp,
    required this.vs,
  });

  final String label;
  final IconData icon;
  final String amount;

  /// Change in percent from the period before, or null.
  final int? change;

  /// Up is good for income, bad for expenses.
  final bool goodWhenUp;
  final String Function(String change) vs;

  @override
  Widget build(BuildContext context) {
    final brand = BrandColors.of(context);
    final c = change;
    final up = c != null && c > 0;
    final good = c == null || c == 0 || (up == goodWhenUp);
    final changeColor = good ? const Color(0xFFB9F6CA) : const Color(0xFFFFCDD2);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: brand.label),
              const SizedBox(width: 4),
              Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: brand.label,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(amount,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800)),
          ),
          if (c != null) ...[
            const SizedBox(height: 4),
            Semantics(
              label: vs('${c > 0 ? '+' : ''}$c%'),
              excludeSemantics: true,
              child: Row(
                children: [
                  Icon(
                    c > 0
                        ? Icons.arrow_upward
                        : c < 0
                            ? Icons.arrow_downward
                            : Icons.remove,
                    size: 14,
                    color: changeColor,
                  ),
                  const SizedBox(width: 2),
                  Text('${c.abs()}%',
                      style: TextStyle(
                          color: changeColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A donut of the period's expenses (or income) by category, and a row
/// per category with its share.
class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    super.key,
    required this.state,
    required this.entries,
    required this.type,
    required this.onType,
  });

  final AppState state;
  final List<Entry> entries;
  final EntryType type;
  final ValueChanged<EntryType> onType;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    final byCategory = <String, int>{};
    for (final e in entries) {
      if (e.type != type) continue;
      byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amountMinor;
    }
    final rows = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = rows.fold<int>(0, (s, r) => s + r.value);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.byCategory,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            SegmentedButton<EntryType>(
              segments: [
                ButtonSegment(value: EntryType.expense, label: Text(l.expenses)),
                ButtonSegment(value: EntryType.income, label: Text(l.income)),
              ],
              showSelectedIcon: false,
              selected: {type},
              onSelectionChanged: (s) => onType(s.first),
            ),
            const SizedBox(height: 16),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  type == EntryType.expense
                      ? l.noExpensesInPeriod
                      : l.noIncomeInPeriod,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              )
            else ...[
              Center(
                child: PieChart(
                  size: 184,
                  slices: [
                    for (final r in rows)
                      PieSlice(r.value.toDouble(), state.colorFor(r.key, type)),
                  ],
                  center: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l.total, style: theme.textTheme.bodySmall),
                      FittedBox(
                        child: Text(
                          state.formatMoney(total),
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              for (final r in rows)
                _CategoryRow(
                  label: categoryLabel(l, r.key),
                  icon: state.iconFor(r.key, type),
                  color: state.colorFor(r.key, type),
                  amount: state.formatMoney(r.value),
                  fraction: total <= 0 ? 0 : r.value / total,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.label,
    required this.icon,
    required this.color,
    required this.amount,
    required this.fraction,
  });

  final String label;
  final IconData icon;
  final Color color;
  final String amount;

  /// Share of the total, 0..1.
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = fraction * 100;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: color,
            child: Icon(icon, size: 17, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 8),
                    Text(amount,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: fraction.clamp(0.0, 1.0)),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) => LinearProgressIndicator(
                      value: v,
                      minHeight: 6,
                      color: color,
                      backgroundColor: color.withValues(alpha: 0.15),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 46,
            child: Text(
              '${percent.toStringAsFixed(percent < 10 ? 1 : 0)}%',
              textAlign: TextAlign.end,
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// Income against expenses: the last 6 weeks, the last 6 months, or the
/// 12 months of the year.
class _TrendCard extends StatelessWidget {
  const _TrendCard({
    super.key,
    required this.state,
    required this.period,
    required this.start,
  });

  final AppState state;
  final ReportPeriod period;
  final DateTime start;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    final colors = ReportColors.of(context);
    final List<(DateTime, DateTime)> ranges = switch (period) {
      ReportPeriod.week => lastPeriods(ReportPeriod.week, start, 6),
      ReportPeriod.month => lastPeriods(ReportPeriod.month, start, 6),
      ReportPeriod.year => [
          for (var m = 1; m <= 12; m++)
            (DateTime(start.year, m, 1), DateTime(start.year, m + 1, 1)),
        ],
    };
    final String subtitle = switch (period) {
      ReportPeriod.week => l.lastSixWeeks,
      ReportPeriod.month => l.lastSixMonths,
      ReportPeriod.year => l.monthByMonth,
    };
    final groups = <BarGroup>[];
    for (final (s, e) in ranges) {
      final list = state.entriesBetween(s, e);
      final label = switch (period) {
        ReportPeriod.week => DateFormat.MMMd().format(s),
        ReportPeriod.month => DateFormat.MMM().format(s),
        ReportPeriod.year => DateFormat('MMMMM').format(s),
      };
      groups.add(BarGroup(
          label, AppState.sumIncome(list), AppState.sumExpense(list)));
    }
    final compact = NumberFormat.compact(locale: state.currency.locale);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(l.incomeVsExpenses,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w800)),
                  ),
                  Text(subtitle, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(height: 14),
            IncomeExpenseBarChart(
              groups: groups,
              incomeColor: colors.income,
              expenseColor: colors.expense,
              height: 170,
              axisLabel: (minor) => compact.format(minor / 100),
            ),
          ],
        ),
      ),
    );
  }
}
