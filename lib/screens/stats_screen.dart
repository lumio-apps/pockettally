import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../models.dart';
import '../report_pdf.dart';
import '../widgets/bar_chart.dart';
import '../widgets/entry_tile.dart' show kIncomeColor, kExpenseColor;
import '../widgets/pie_chart.dart';

enum StatsPeriod { day, week, month, year }

/// Totals for a day, week, month or year, a bar chart by month (year view)
/// and a pie chart by category.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key, required this.state});

  final AppState state;

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  StatsPeriod _period = StatsPeriod.month;
  DateTime _anchor = DateTime.now();
  EntryType _pieType = EntryType.expense;
  bool _exporting = false;

  AppState get state => widget.state;

  /// Start (inclusive) and end (exclusive) of the selected range.
  (DateTime, DateTime) get _range {
    final d = DateTime(_anchor.year, _anchor.month, _anchor.day);
    switch (_period) {
      case StatsPeriod.day:
        return (d, DateTime(d.year, d.month, d.day + 1));
      case StatsPeriod.week:
        // Monday or Sunday, as chosen in Settings.
        final start = state.startOfWeek(d);
        return (start, DateTime(start.year, start.month, start.day + 7));
      case StatsPeriod.month:
        return (
          DateTime(d.year, d.month, 1),
          DateTime(d.year, d.month + 1, 1),
        );
      case StatsPeriod.year:
        return (DateTime(d.year, 1, 1), DateTime(d.year + 1, 1, 1));
    }
  }

  void _shift(int direction) {
    setState(() {
      final a = _anchor;
      switch (_period) {
        case StatsPeriod.day:
          _anchor = DateTime(a.year, a.month, a.day + direction);
        case StatsPeriod.week:
          _anchor = DateTime(a.year, a.month, a.day + 7 * direction);
        case StatsPeriod.month:
          // Day 1 avoids skipping a month (e.g. 31 Jan + 1 month).
          _anchor = DateTime(a.year, a.month + direction, 1);
        case StatsPeriod.year:
          _anchor = DateTime(a.year + direction, 1, 1);
      }
    });
  }

  String _rangeLabel(DateTime start, DateTime end) {
    switch (_period) {
      case StatsPeriod.day:
        return DateFormat('EEE, d MMM y').format(start);
      case StatsPeriod.week:
        final last = DateTime(end.year, end.month, end.day - 1);
        return '${DateFormat('d MMM').format(start)} – ${DateFormat('d MMM y').format(last)}';
      case StatsPeriod.month:
        return DateFormat('MMMM y').format(start);
      case StatsPeriod.year:
        return '${start.year}';
    }
  }

  /// Opens one month of the year view.
  void _openMonth(int year, int month) {
    setState(() {
      _period = StatsPeriod.month;
      _anchor = DateTime(year, month, 1);
    });
  }

  Future<void> _exportPdf(DateTime start, DateTime end, String label) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _exporting = true);
    try {
      final saved = await ReportPdf.saveReport(
        state: state,
        start: start,
        end: end,
        periodLabel: label,
      );
      if (saved) {
        messenger.showSnackBar(
            const SnackBar(content: Text('PDF report saved')));
      }
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Could not create the PDF report.')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Widget _yearSection(ThemeData theme, int year) {
    final now = DateTime.now();
    final lastMonth = year == now.year ? now.month : 12;
    final groups = <BarGroup>[];
    final rows = <Widget>[];
    for (var m = 1; m <= 12; m++) {
      final list = state.entriesBetween(DateTime(year, m, 1), DateTime(year, m + 1, 1));
      final inc = AppState.sumIncome(list);
      final exp = AppState.sumExpense(list);
      groups.add(BarGroup(DateFormat('MMMMM').format(DateTime(year, m, 1)), inc, exp));
      if (m <= lastMonth && year <= now.year) {
        final bal = inc - exp;
        rows.add(ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(DateFormat('MMMM').format(DateTime(year, m, 1))),
          subtitle: Text.rich(TextSpan(children: [
            TextSpan(
                text: '+ ${state.formatMoney(inc)}',
                style: const TextStyle(color: kIncomeColor)),
            const TextSpan(text: '   '),
            TextSpan(
                text: '- ${state.formatMoney(exp)}',
                style: const TextStyle(color: kExpenseColor)),
          ])),
          trailing: Text(
            state.formatMoney(bal),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: bal < 0 ? kExpenseColor : null,
            ),
          ),
          onTap: () => _openMonth(year, m),
        ));
      }
    }
    final compact = NumberFormat.compact(locale: state.currency.locale);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Text('Month by month', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 16, 12),
            child: IncomeExpenseBarChart(
              groups: groups,
              incomeColor: kIncomeColor,
              expenseColor: kExpenseColor,
              axisLabel: (minor) => compact.format(minor / 100),
            ),
          ),
        ),
        const SizedBox(height: 8),
        ...rows.reversed,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final theme = Theme.of(context);
        final (start, end) = _range;
        final list = state.entriesBetween(start, end);
        final income = AppState.sumIncome(list);
        final expense = AppState.sumExpense(list);
        final balance = income - expense;
        // No "next" when the next range would start in the future.
        final canGoForward = !end.isAfter(DateTime.now());
        final pieEntries = list.where((e) => e.type == _pieType);

        // Total per category, biggest first.
        final byCategory = <String, int>{};
        for (final e in pieEntries) {
          byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amountMinor;
        }
        final rows = byCategory.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final pieTotal = rows.fold<int>(0, (s, r) => s + r.value);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Stats'),
            actions: [
              IconButton(
                tooltip: 'Save as PDF',
                icon: _exporting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.picture_as_pdf_outlined),
                onPressed: _exporting || list.isEmpty
                    ? null
                    : () => _exportPdf(start, end, _rangeLabel(start, end)),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              SegmentedButton<StatsPeriod>(
                segments: const [
                  ButtonSegment(value: StatsPeriod.day, label: Text('Day')),
                  ButtonSegment(value: StatsPeriod.week, label: Text('Week')),
                  ButtonSegment(value: StatsPeriod.month, label: Text('Month')),
                  ButtonSegment(value: StatsPeriod.year, label: Text('Year')),
                ],
                showSelectedIcon: false,
                selected: {_period},
                onSelectionChanged: (s) => setState(() {
                  _period = s.first;
                  _anchor = DateTime.now();
                }),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Previous',
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => _shift(-1),
                  ),
                  Expanded(
                    child: Text(
                      _rangeLabel(start, end),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next',
                    icon: const Icon(Icons.chevron_right),
                    onPressed: canGoForward ? () => _shift(1) : null,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _TotalRow('Income', state.formatMoney(income), kIncomeColor),
                      const SizedBox(height: 8),
                      _TotalRow('Expenses', state.formatMoney(expense), kExpenseColor),
                      const Divider(height: 24),
                      _TotalRow(
                        'Balance',
                        state.formatMoney(balance),
                        balance < 0 ? kExpenseColor : theme.colorScheme.onSurface,
                        bold: true,
                      ),
                    ],
                  ),
                ),
              ),
              if (_period == StatsPeriod.year) _yearSection(theme, start.year),
              const SizedBox(height: 24),
              Text('By category', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              SegmentedButton<EntryType>(
                segments: const [
                  ButtonSegment(value: EntryType.expense, label: Text('Expenses')),
                  ButtonSegment(value: EntryType.income, label: Text('Income')),
                ],
                showSelectedIcon: false,
                selected: {_pieType},
                onSelectionChanged: (s) => setState(() => _pieType = s.first),
              ),
              const SizedBox(height: 24),
              if (rows.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _pieType == EntryType.expense
                        ? 'No expenses in this period.'
                        : 'No income in this period.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                )
              else ...[
                Center(
                  child: PieChart(
                    size: 220,
                    slices: [
                      for (final r in rows)
                        PieSlice(r.value.toDouble(),
                            state.colorFor(r.key, _pieType)),
                    ],
                    center: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Total', style: theme.textTheme.bodySmall),
                        FittedBox(
                          child: Text(
                            state.formatMoney(pieTotal),
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                for (final r in rows)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 8,
                      backgroundColor: state.colorFor(r.key, _pieType),
                    ),
                    title: Text(r.key),
                    subtitle: Text(
                        '${(r.value / pieTotal * 100).toStringAsFixed(1)}%'),
                    trailing: Text(
                      state.formatMoney(r.value),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow(this.label, this.value, this.color, {this.bold = false});

  final String label;
  final String value;
  final Color color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleMedium?.copyWith(
          color: color,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
        );
    return Row(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyLarge),
        const Spacer(),
        Text(value, style: style),
      ],
    );
  }
}
