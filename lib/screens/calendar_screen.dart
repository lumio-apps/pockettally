import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../l10n/l10n.dart';
import '../models.dart';
import '../widgets/entry_tile.dart';
import 'entry_form_screen.dart';
import '../widgets/neo.dart';

/// A month as a calendar: each day shows what was spent or earned.
/// Tap a day to see its entries.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, required this.state});

  final AppState state;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _month;
  late DateTime _selected;

  AppState get state => widget.state;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month, 1);
    _selected = DateTime(now.year, now.month, now.day);
  }

  void _shift(int months) {
    setState(() {
      _month = DateTime(_month.year, _month.month + months, 1);
      _selected = _month;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.calendar)),
      body: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          final first = _month;
          final daysInMonth = DateTime(first.year, first.month + 1, 0).day;
          // Empty cells before day 1, following the week-start setting.
          final lead = state.weekStartsOnSunday
              ? first.weekday % 7
              : first.weekday - 1;

          // Net amount (income - expense) and whether anything happened.
          final net = <int, int>{};
          final spent = <int, int>{};
          for (final e in state.entriesInMonth(first)) {
            net[e.date.day] =
                (net[e.date.day] ?? 0) + (e.isIncome ? e.amountMinor : -e.amountMinor);
            if (!e.isIncome) {
              spent[e.date.day] = (spent[e.date.day] ?? 0) + e.amountMinor;
            }
          }
          final dayEntries = state.entries
              .where((e) =>
                  e.date.year == _selected.year &&
                  e.date.month == _selected.month &&
                  e.date.day == _selected.day)
              .toList();
          final compact = NumberFormat.compact(locale: state.currency.locale);
          final weekdayStart = state.weekStartsOnSunday
              ? DateTime(2023, 1, 1) // a Sunday
              : DateTime(2023, 1, 2); // a Monday
          final today = DateTime.now();

          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: l.previous,
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => _shift(-1),
                  ),
                  Expanded(
                    child: Text(
                      DateFormat.yMMMM().format(first),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: l.next,
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => _shift(1),
                  ),
                ],
              ),
              Row(
                children: [
                  for (var i = 0; i < 7; i++)
                    Expanded(
                      child: Center(
                        child: Text(
                          DateFormat.E().format(
                              weekdayStart.add(Duration(days: i))),
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: lead + daysInMonth,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                  childAspectRatio: 0.8,
                ),
                itemBuilder: (context, i) {
                  if (i < lead) return const SizedBox.shrink();
                  final day = i - lead + 1;
                  final date = DateTime(first.year, first.month, day);
                  final selected = date == _selected;
                  final isToday = date.year == today.year &&
                      date.month == today.month &&
                      date.day == today.day;
                  final value = net[day];
                  return Material(
                    color: selected
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => setState(() => _selected = date),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Column(
                          children: [
                            Text(
                              '$day',
                              style: TextStyle(
                                fontWeight:
                                    isToday ? FontWeight.w900 : FontWeight.w600,
                                decoration: isToday
                                    ? TextDecoration.underline
                                    : null,
                              ),
                            ),
                            const Spacer(),
                            if (value != null)
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  (spent[day] ?? 0) > 0
                                      ? '-${compact.format((spent[day] ?? 0) / 100)}'
                                      : '+${compact.format(value / 100)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: (spent[day] ?? 0) > 0
                                        ? kExpenseColor
                                        : kIncomeColor,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(DateFormat.yMMMMEEEEd().format(_selected),
                    style: theme.textTheme.titleSmall),
              ),
              const SizedBox(height: 6),
              if (dayEntries.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(l.noEntriesThisDay, textAlign: TextAlign.center),
                )
              else
                NeoCard(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (final e in dayEntries)
                        EntryTile(
                          entry: e,
                          state: state,
                          onTap: () =>
                              Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) =>
                                EntryFormScreen(state: state, entry: e),
                          )),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.add),
                label: Text(l.addEntry),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => _EntryOnDay(state: state, date: _selected),
                )),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The entry form, starting on the chosen calendar day.
class _EntryOnDay extends StatelessWidget {
  const _EntryOnDay({required this.state, required this.date});

  final AppState state;
  final DateTime date;

  @override
  Widget build(BuildContext context) =>
      EntryFormScreen(state: state, initialType: EntryType.expense, initialDate: date);
}
