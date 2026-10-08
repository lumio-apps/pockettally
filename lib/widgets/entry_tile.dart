import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';

const Color kIncomeColor = Color(0xFF2E9E5B);
const Color kExpenseColor = Color(0xFFD64545);

/// One income/expense row. Swipe left to delete (with Undo), tap to edit.
class EntryTile extends StatelessWidget {
  const EntryTile({
    super.key,
    required this.entry,
    required this.state,
    required this.onTap,
    this.showDate = false,
  });

  final Entry entry;
  final AppState state;
  final VoidCallback onTap;

  /// Show the date in the subtitle (used in search results).
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final color = entry.isIncome ? kIncomeColor : kExpenseColor;
    final sign = entry.isIncome ? '+' : '-';
    final categoryColor = state.colorFor(entry.category, entry.type);

    final subtitleParts = <String>[
      if (showDate) MaterialLocalizations.of(context).formatMediumDate(entry.date),
      if (entry.isIncome && entry.period != null)
        '${periodLabel(entry.period!)} income',
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
          backgroundColor: categoryColor.withValues(alpha: 0.25),
          child: Icon(
            entry.isIncome ? Icons.south_west : Icons.north_east,
            color: color,
            size: 20,
          ),
        ),
        title: Text(entry.category),
        subtitle:
            subtitleParts.isEmpty ? null : Text(subtitleParts.join(' · ')),
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
}

String periodLabel(IncomePeriod p) {
  switch (p) {
    case IncomePeriod.daily:
      return 'Daily';
    case IncomePeriod.weekly:
      return 'Weekly';
    case IncomePeriod.monthly:
      return 'Monthly';
  }
}
