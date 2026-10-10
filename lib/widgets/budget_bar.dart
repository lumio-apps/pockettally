import 'package:flutter/material.dart';

import '../app_state.dart';
import 'entry_tile.dart' show kIncomeColor, kExpenseColor;

const Color kWarningColor = Color(0xFF9A6700);

/// Progress of spending against a limit: green, then amber from 80 %,
/// red when over.
class BudgetBar extends StatelessWidget {
  const BudgetBar({
    super.key,
    required this.state,
    required this.spent,
    required this.limit,
    this.label,
  });

  final AppState state;
  final int spent;
  final int limit;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = limit <= 0 ? 0.0 : spent / limit;
    final over = spent > limit;
    final color = over
        ? kExpenseColor
        : ratio >= 0.8
            ? kWarningColor
            : kIncomeColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (label != null)
              Expanded(child: Text(label!, style: theme.textTheme.bodySmall))
            else
              const Spacer(),
            Text(
              '${state.formatMoney(spent)} of ${state.formatMoney(limit)}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0),
            minHeight: 8,
            color: color,
            backgroundColor: color.withValues(alpha: 0.18),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          over
              ? 'Over by ${state.formatMoney(spent - limit)}'
              : '${state.formatMoney(limit - spent)} left',
          style: theme.textTheme.bodySmall?.copyWith(
            color: over ? kExpenseColor : null,
            fontWeight: over ? FontWeight.w600 : null,
          ),
        ),
      ],
    );
  }
}
