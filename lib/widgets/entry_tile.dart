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
      onDismissed: (_) =>
          deleteEntryWithUndo(ScaffoldMessenger.of(context), state, entry),
      child: ListTile(
        onTap: onTap,
        onLongPress: () => _showActions(context),
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

  /// Long press: Edit or Delete.
  Future<void> _showActions(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              onTap: () => Navigator.pop(ctx, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: kExpenseColor),
              title: const Text('Delete',
                  style: TextStyle(color: kExpenseColor)),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (action == 'edit') onTap();
    if (action == 'delete') await deleteEntryWithUndo(messenger, state, entry);
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

/// Deletes [entry] and shows "Entry deleted" with an Undo button.
Future<void> deleteEntryWithUndo(
    ScaffoldMessengerState messenger, AppState state, Entry entry) async {
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
}
