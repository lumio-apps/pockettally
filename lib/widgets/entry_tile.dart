import 'package:flutter/material.dart';

import '../app_state.dart';
import '../l10n/l10n.dart';
import '../models.dart';

const Color kIncomeColor = Color(0xFF1B7A4C);
const Color kExpenseColor = Color(0xFFC0392B);

/// One income/expense row. Tap to edit, long-press for Edit/Delete,
/// swipe left to delete (with Undo).
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
    final theme = Theme.of(context);
    final l = context.l10n;
    final name = categoryLabel(l, entry.category);
    final color = entry.isIncome ? kIncomeColor : kExpenseColor;
    final sign = entry.isIncome ? '+' : '-';
    final categoryColor = state.colorFor(entry.category, entry.type);
    final dark = theme.brightness == Brightness.dark;
    final letterColor = HSLColor.fromColor(categoryColor)
        .withLightness(dark ? 0.75 : 0.28)
        .toColor();

    final subtitleParts = <String>[
      if (showDate) MaterialLocalizations.of(context).formatMediumDate(entry.date),
      if (entry.isIncome && entry.period != null)
        periodIncomeLabel(l, entry.period!),
      if (entry.note.isNotEmpty) entry.note,
      if (entry.tags.isNotEmpty) entry.tags.map((t) => '#$t').join(' '),
    ];

    return Dismissible(
      key: ValueKey('entry_${entry.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: kExpenseColor,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsetsDirectional.only(end: 24),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) =>
          deleteEntryWithUndo(ScaffoldMessenger.of(context), l, state, entry),
      child: ListTile(
        onTap: onTap,
        onLongPress: () => _showActions(context),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: categoryColor.withValues(alpha: dark ? 0.28 : 0.22),
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Text(
            name.isEmpty ? '?' : name.characters.first.toUpperCase(),
            style: TextStyle(
              color: letterColor,
              fontWeight: FontWeight.w800,
              fontSize: 17,
            ),
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (entry.photo != null) ...[
              const SizedBox(width: 6),
              Icon(Icons.receipt_long_outlined,
                  size: 16, color: theme.colorScheme.onSurfaceVariant),
            ],
          ],
        ),
        subtitle: subtitleParts.isEmpty
            ? null
            : Text(
                subtitleParts.join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
        trailing: Text(
          '$sign ${state.formatMoney(entry.amountMinor)}',
          style: TextStyle(
            color: dark
                ? (entry.isIncome ? const Color(0xFF7BE0B5) : const Color(0xFFFFB4A8))
                : color,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  /// Long press: Edit or Delete.
  Future<void> _showActions(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(l.edit),
              onTap: () => Navigator.pop(ctx, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: kExpenseColor),
              title: Text(l.delete,
                  style: const TextStyle(color: kExpenseColor)),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (action == 'edit') onTap();
    if (action == 'delete') {
      await deleteEntryWithUndo(messenger, l, state, entry);
    }
  }
}

/// Deletes [entry] and shows "Entry deleted" with an Undo button.
Future<void> deleteEntryWithUndo(ScaffoldMessengerState messenger,
    AppLocalizations l, AppState state, Entry entry) async {
  await state.deleteEntry(entry);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(l.entryDeleted),
        action: SnackBarAction(
          label: l.undo,
          onPressed: () => state.restoreEntry(entry),
        ),
      ),
    );
}
