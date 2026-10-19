import 'package:flutter/material.dart';

import '../app_state.dart';
import '../l10n/l10n.dart';
import '../models.dart';
import '../widgets/entry_tile.dart' show kIncomeColor, kExpenseColor;
import '../widgets/neo.dart';

/// Deleted entries. They stay here for [kTrashDays] days; tap one to put it
/// back or to remove it for good.
class TrashScreen extends StatelessWidget {
  const TrashScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final items = state.trash;
        return Scaffold(
          appBar: AppBar(
            title: Text(l.trash),
            actions: [
              if (items.isNotEmpty)
                IconButton(
                  tooltip: l.emptyTrash,
                  icon: const Icon(Icons.delete_forever_outlined),
                  onPressed: () => _emptyTrash(context, items.length),
                ),
            ],
          ),
          body: items.isEmpty
              ? _Empty(text: l.trashIsEmpty, hint: l.trashHint)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                      child: Text(
                        l.trashHint,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ),
                    for (final t in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _TrashTile(state: state, item: t),
                      ),
                  ],
                ),
        );
      },
    );
  }

  Future<void> _emptyTrash(BuildContext context, int count) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.emptyTrash),
        content: Text(l.emptyTrashQuestion(count)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.cancel)),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: kExpenseColor),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.deleteForever)),
        ],
      ),
    );
    if (ok == true) await state.emptyTrash();
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text, required this.hint});

  final String text;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline,
                size: 56, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(text, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(hint,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _TrashTile extends StatelessWidget {
  const _TrashTile({required this.state, required this.item});

  final AppState state;
  final TrashedEntry item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    final e = item.entry;
    final left = item.daysLeft();
    final sign = e.isIncome ? '+' : '-';
    final parts = <String>[
      MaterialLocalizations.of(context).formatMediumDate(e.date),
      if (e.note.isNotEmpty) e.note,
      left == 0 ? l.trashLastDay : l.trashDaysLeft(left),
    ];
    return NeoCard(
      onTap: () => _actions(context),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: state.colorFor(e.category, e.type),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(state.iconFor(e.category, e.type),
              color: Colors.white, size: 21),
        ),
        title: Text(categoryLabel(l, e.category),
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(parts.join(' · '),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Text(
          '$sign ${state.formatMoney(e.amountMinor)}',
          style: TextStyle(
            color: e.isIncome ? kIncomeColor : kExpenseColor,
            fontWeight: FontWeight.w800,
            fontSize: 15,
            decoration: TextDecoration.lineThrough,
            decorationColor: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Future<void> _actions(BuildContext context) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.restore_from_trash_outlined),
              title: Text(l.restore),
              onTap: () => Navigator.pop(ctx, 'restore'),
            ),
            ListTile(
              leading:
                  const Icon(Icons.delete_forever_outlined, color: kExpenseColor),
              title: Text(l.deleteForever,
                  style: const TextStyle(color: kExpenseColor)),
              onTap: () => Navigator.pop(ctx, 'forever'),
            ),
          ],
        ),
      ),
    );
    if (action == 'restore') {
      await state.restoreEntry(item.entry);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.trashRestored)));
    }
    if (action == 'forever' && context.mounted) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l.deleteForever),
          content: Text(l.deleteForeverQuestion),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l.cancel)),
            FilledButton(
                style: FilledButton.styleFrom(backgroundColor: kExpenseColor),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l.deleteForever)),
          ],
        ),
      );
      if (ok == true) await state.deleteForever(item.entry);
    }
  }
}
