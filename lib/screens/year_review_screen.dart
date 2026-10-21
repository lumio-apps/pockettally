import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../l10n/l10n.dart';
import '../widgets/entry_tile.dart' show kIncomeColor, kExpenseColor;
import '../widgets/neo.dart';
import '../year_review.dart';

/// A look back at one year: what you earned, spent and saved, your biggest
/// expense, top category and best and costliest months.
class YearReviewScreen extends StatefulWidget {
  const YearReviewScreen({super.key, required this.state});

  final AppState state;

  @override
  State<YearReviewScreen> createState() => _YearReviewScreenState();
}

class _YearReviewScreenState extends State<YearReviewScreen> {
  int _year = DateTime.now().year;

  AppState get state => widget.state;

  String _month(int m) => DateFormat.MMMM().format(DateTime(_year, m, 1));

  /// The review as plain text, for copying.
  String _summary(AppLocalizations l, YearReview r) {
    final lines = <String>[
      l.reviewTitle(_year),
      '${l.reviewTotalEarned}: ${state.formatMoney(r.income)}',
      '${l.reviewTotalSpent}: ${state.formatMoney(r.expense)}',
      '${l.reviewSaved}: ${state.formatMoney(r.saved)}',
      if (r.biggestExpense != null)
        '${l.reviewBiggest}: ${categoryLabel(l, r.biggestExpense!.category)} '
            '${state.formatMoney(r.biggestExpense!.amountMinor)}',
      if (r.topCategory != null)
        '${l.reviewTopCategory}: ${categoryLabel(l, r.topCategory!)} '
            '(${r.topCategoryPercent}%)',
      if (r.bestSavingMonth != null)
        '${l.reviewBestMonth}: ${_month(r.bestSavingMonth!)} '
            '(${state.formatMoney(r.bestSavingMinor)})',
      if (r.costliestMonth != null)
        '${l.reviewCostliestMonth}: ${_month(r.costliestMonth!)} '
            '(${state.formatMoney(r.costliestMinor)})',
      '${l.reviewAvgDaily}: ${state.formatMoney(r.avgDailyExpenseMinor)}',
      '${l.reviewNoSpendDays}: ${r.noSpendDays}',
      'PocketTally',
    ];
    return lines.join('\n');
  }

  Future<void> _copy(AppLocalizations l, YearReview r) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: _summary(l, r)));
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        duration: const Duration(seconds: 3),
        content: Text(l.reviewCopied),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final now = DateTime.now();
        final years = YearReview.yearsWithEntries(state.entries, now);
        if (!years.contains(_year)) _year = years.first;
        final r = YearReview.compute(state.entries, _year, now);
        final index = years.indexOf(_year);
        final hide = state.hideBalance;
        String money(int v) => hide ? '••••' : state.formatMoney(v);
        return Scaffold(
          appBar: AppBar(
            title: Text(l.yearInReview),
            actions: [
              if (!r.isEmpty)
                IconButton(
                  tooltip: l.reviewCopy,
                  icon: const Icon(Icons.copy_outlined),
                  onPressed: () => _copy(l, r),
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: l.previous,
                    icon: const Icon(Icons.chevron_left),
                    onPressed: index < years.length - 1
                        ? () => setState(() => _year = years[index + 1])
                        : null,
                  ),
                  Expanded(
                    child: Text('$_year',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800)),
                  ),
                  IconButton(
                    tooltip: l.next,
                    icon: const Icon(Icons.chevron_right),
                    onPressed: index > 0
                        ? () => setState(() => _year = years[index - 1])
                        : null,
                  ),
                ],
              ),
              if (r.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(l.reviewNoData(_year),
                      textAlign: TextAlign.center),
                )
              else ...[
                NeoCard(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.reviewTitle(_year),
                            style: theme.textTheme.titleSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 8),
                        Text(l.reviewSaved,
                            style: theme.textTheme.bodySmall),
                        Text(
                          money(r.saved),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: r.saved < 0 ? kExpenseColor : kIncomeColor,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _Stat(l.reviewTotalEarned, money(r.income),
                                  color: kIncomeColor),
                            ),
                            Expanded(
                              child: _Stat(l.reviewTotalSpent, money(r.expense),
                                  color: kExpenseColor),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _Stat(l.reviewAvgDaily,
                                  money(r.avgDailyExpenseMinor)),
                            ),
                            Expanded(
                              child: _Stat(
                                  l.reviewNoSpendDays, '${r.noSpendDays}'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (r.biggestExpense != null)
                  _Highlight(
                    icon: Icons.local_fire_department_outlined,
                    title: l.reviewBiggest,
                    value: money(r.biggestExpense!.amountMinor),
                    detail: [
                      categoryLabel(l, r.biggestExpense!.category),
                      DateFormat.MMMd().format(r.biggestExpense!.date),
                      if (r.biggestExpense!.note.isNotEmpty)
                        r.biggestExpense!.note,
                    ].join(' · '),
                  ),
                if (r.topCategory != null)
                  _Highlight(
                    icon: Icons.pie_chart_outline,
                    title: l.reviewTopCategory,
                    value: categoryLabel(l, r.topCategory!),
                    detail:
                        '${money(r.topCategoryMinor)} · ${r.topCategoryPercent}%',
                  ),
                if (r.bestSavingMonth != null)
                  _Highlight(
                    icon: Icons.savings_outlined,
                    title: l.reviewBestMonth,
                    value: _month(r.bestSavingMonth!),
                    detail: money(r.bestSavingMinor),
                  ),
                if (r.costliestMonth != null)
                  _Highlight(
                    icon: Icons.trending_up,
                    title: l.reviewCostliestMonth,
                    value: _month(r.costliestMonth!),
                    detail: money(r.costliestMinor),
                  ),
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  style:
                      OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                  icon: const Icon(Icons.copy_outlined, size: 18),
                  label: Text(l.reviewCopy),
                  onPressed: () => _copy(l, r),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, {this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 2),
        Text(value,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }
}

class _Highlight extends StatelessWidget {
  const _Highlight({
    required this.icon,
    required this.title,
    required this.value,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: NeoCard(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          leading: Icon(icon, color: theme.colorScheme.primary),
          title: Text(title,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant)),
          subtitle: Text(detail, maxLines: 2, overflow: TextOverflow.ellipsis),
          isThreeLine: false,
          trailing: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: Text(value,
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 16)),
          ),
        ),
      ),
    );
  }
}
