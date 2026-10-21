import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../l10n/l10n.dart';
import '../net_worth.dart';
import '../widgets/entry_tile.dart' show kIncomeColor, kExpenseColor;
import '../widgets/line_chart.dart';
import '../widgets/neo.dart';

/// Everything you own minus everything you owe, in one number: the wallets,
/// plus what people owe you, minus what you owe.
class NetWorthScreen extends StatelessWidget {
  const NetWorthScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final net = state.netWorthMinor;
        final now = DateTime.now();
        final opening = state.wallets.fold<int>(0, (s, w) => s + w.openingMinor);
        final totals = monthEndTotals(state.entries, opening, now);
        final labels = [
          for (final d in lastMonthStarts(now)) DateFormat.MMM().format(d),
        ];
        final compact = NumberFormat.compact(locale: state.currency.locale);
        final hide = state.hideBalance;
        String money(int v) => hide ? '••••' : state.formatMoney(v);
        return Scaffold(
          appBar: AppBar(title: Text(l.netWorth)),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              NeoCard(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.netWorth,
                          style: theme.textTheme.titleSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 6),
                      Text(
                        money(net),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: net < 0 ? kExpenseColor : null,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _Row(l.inWallets, money(state.walletsTotalMinor)),
                      _Row(l.owedToYou, '+ ${money(state.toReceiveMinor)}',
                          color: kIncomeColor),
                      _Row(l.youOwe, '- ${money(state.toPayMinor)}',
                          color: kExpenseColor),
                    ],
                  ),
                ),
              ),
              if (state.goalsSavedMinor > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
                  child: Text(
                    '${l.setAsideGoals}: ${money(state.goalsSavedMinor)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              const SizedBox(height: 14),
              NeoCard(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsetsDirectional.only(start: 4),
                        child: Text(l.walletsOverTime,
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(height: 14),
                      if (hide)
                        const SizedBox(height: 60)
                      else
                        SimpleLineChart(
                          values: totals,
                          labels: labels,
                          color: theme.colorScheme.primary,
                          axisLabel: (minor) => compact.format(minor / 100),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value,
              style: TextStyle(fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}
