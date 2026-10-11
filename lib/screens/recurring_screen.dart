import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../l10n/l10n.dart';
import '../models.dart';
import '../widgets/entry_tile.dart' show kIncomeColor, kExpenseColor;

/// Entries that repeat (salary, rent…): pause, resume or stop them.
/// New ones are made with "Repeat" in the entry form.
class RecurringScreen extends StatelessWidget {
  const RecurringScreen({super.key, required this.state});

  final AppState state;

  static String everyLabel(AppLocalizations l, RepeatEvery e) {
    switch (e) {
      case RepeatEvery.daily:
        return l.everyDay;
      case RepeatEvery.weekly:
        return l.everyWeek;
      case RepeatEvery.monthly:
        return l.everyMonth;
      case RepeatEvery.yearly:
        return l.everyYear;
    }
  }

  Future<void> _stop(BuildContext context, RecurringRule r) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.stopRepeatingQuestion),
        content: Text(l.stopRepeatingNote),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.stopRepeating)),
        ],
      ),
    );
    if (ok == true) await state.deleteRecurring(r);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.recurringEntries)),
      body: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          final rules = state.recurring;
          if (rules.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(l.noRecurring, textAlign: TextAlign.center),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            itemCount: rules.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final r = rules[i];
              final income = r.type == EntryType.income;
              final name = r.note.isNotEmpty
                  ? '${categoryLabel(l, r.category)} · ${r.note}'
                  : categoryLabel(l, r.category);
              return Card(
                child: ListTile(
                  contentPadding:
                      const EdgeInsetsDirectional.fromSTEB(16, 6, 8, 6),
                  leading: Icon(Icons.repeat,
                      color: income ? kIncomeColor : kExpenseColor),
                  title: Text(name,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text([
                    '${income ? '+' : '-'} ${state.formatMoney(r.amountMinor)}',
                    everyLabel(l, r.every),
                    r.paused
                        ? l.paused
                        : l.nextOn(DateFormat.yMMMd().format(r.nextDate)),
                  ].join(' · ')),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: !r.paused,
                        onChanged: (on) => state.setRecurringPaused(r, !on),
                      ),
                      IconButton(
                        tooltip: l.stopRepeating,
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _stop(context, r),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
