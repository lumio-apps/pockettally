import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../l10n/l10n.dart';
import '../models.dart';
import '../widgets/entry_tile.dart' show kExpenseColor;
import '../widgets/neo.dart';
import '../widgets/reminder_permission.dart';

/// Bills you pay again and again (Netflix, rent, insurance): what is due
/// next, what they cost per month, and a reminder before each one.
class SubscriptionsScreen extends StatelessWidget {
  const SubscriptionsScreen({super.key, required this.state});

  final AppState state;

  static String dueLabel(AppLocalizations l, int days) {
    if (days < 0) return l.overdueDays(-days);
    if (days == 0) return l.dueToday;
    if (days == 1) return l.dueTomorrow;
    return l.dueInDays(days);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final list = state.subscriptions;
        final today = DateTime.now();
        // Active ones by due date, paused ones last.
        final sorted = [...list]..sort((a, b) {
            if (a.paused != b.paused) return a.paused ? 1 : -1;
            return a.nextDate.compareTo(b.nextDate);
          });
        final monthly = state.subscriptionsMonthlyMinor;
        return Scaffold(
          appBar: AppBar(title: Text(l.subscriptions)),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => showSubscriptionDialog(context, state),
            icon: const Icon(Icons.add),
            label: Text(l.addSubscription),
          ),
          body: list.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(l.noSubscriptions, textAlign: TextAlign.center),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  children: [
                    NeoCard(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: _Total(
                                  label: l.perMonthTotal,
                                  value: state.formatMoney(monthly)),
                            ),
                            Expanded(
                              child: _Total(
                                  label: l.perYearTotal,
                                  value: state.formatMoney(monthly * 12)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final s in sorted)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: NeoCard(
                          onTap: () =>
                              showSubscriptionDialog(context, state, existing: s),
                          child: ListTile(
                            contentPadding:
                                const EdgeInsets.only(left: 14, right: 4),
                            title: Text(s.name,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: s.paused
                                      ? theme.colorScheme.onSurfaceVariant
                                      : null,
                                )),
                            subtitle: Text(
                              s.paused
                                  ? l.paused
                                  : '${dueLabel(l, s.daysUntilDue(today))} · '
                                      '${DateFormat.MMMEd().format(s.nextDate)}',
                              style: TextStyle(
                                color: !s.paused && s.daysUntilDue(today) < 0
                                    ? kExpenseColor
                                    : null,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(state.formatMoney(s.amountMinor),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800)),
                                    Text(everyShort(l, s.every),
                                        style: theme.textTheme.bodySmall),
                                  ],
                                ),
                                if (!s.paused)
                                  IconButton(
                                    tooltip: l.markPaid,
                                    icon: const Icon(Icons.check_circle_outline),
                                    onPressed: () => _pay(context, s),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        );
      },
    );
  }

  static String everyShort(AppLocalizations l, RepeatEvery e) {
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

  Future<void> _pay(BuildContext context, Subscription s) async {
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    final next = await state.paySubscription(s);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        duration: const Duration(seconds: 3),
        content: Text(l.subscriptionPaidNext(DateFormat.MMMEd().format(next))),
      ));
  }
}

class _Total extends StatelessWidget {
  const _Total({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        Text(value,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800)),
      ],
    );
  }
}

/// Dialog to add a subscription, or edit [existing].
Future<void> showSubscriptionDialog(BuildContext context, AppState state,
    {Subscription? existing}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _SubscriptionDialog(state: state, existing: existing),
  );
}

class _SubscriptionDialog extends StatefulWidget {
  const _SubscriptionDialog({required this.state, this.existing});

  final AppState state;
  final Subscription? existing;

  @override
  State<_SubscriptionDialog> createState() => _SubscriptionDialogState();
}

class _SubscriptionDialogState extends State<_SubscriptionDialog> {
  late final TextEditingController _name;
  late final TextEditingController _amount;
  late RepeatEvery _every;
  late DateTime _next;
  late String _category;
  late String _wallet;
  late int _remindDays;
  late bool _paused;
  String? _nameError;
  String? _amountError;

  bool get _isEditing => widget.existing != null;

  List<String> get _categories {
    final names = widget.state
        .categoriesFor(EntryType.expense,
            includeHidden: false, keep: widget.existing?.category)
        .map((c) => c.name)
        .toList();
    return names.isEmpty ? [kOtherCategory] : names;
  }

  @override
  void initState() {
    super.initState();
    final s = widget.existing;
    final now = DateTime.now();
    _name = TextEditingController(text: s?.name ?? '');
    _amount = TextEditingController(
        text: s == null ? '' : widget.state.amountInput(s.amountMinor));
    _every = s?.every ?? RepeatEvery.monthly;
    _next = s?.nextDate ?? DateTime(now.year, now.month, now.day + 1);
    final names = _categories;
    _category = s != null && names.contains(s.category)
        ? s.category
        : (names.contains(kOtherCategory) ? kOtherCategory : names.first);
    _wallet = s?.wallet != null &&
            widget.state.wallets.any((w) => w.name == s!.wallet)
        ? s!.wallet!
        : widget.state.mainWallet.name;
    _remindDays = s?.remindDays ?? 1;
    _paused = s?.paused ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _next,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5, 12, 31),
    );
    if (picked != null) setState(() => _next = picked);
  }

  Future<void> _save() async {
    final l = context.l10n;
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = l.enterName);
      return;
    }
    final amount = widget.state.parseMinor(_amount.text);
    if (amount == null || amount <= 0) {
      setState(() => _amountError = l.enterAmountAboveZero);
      return;
    }
    var remind = _remindDays;
    if (remind >= 0 && !await askReminderPermissions(context)) remind = -1;
    if (!mounted) return;
    final s = Subscription(
      id: widget.existing?.id,
      name: name,
      amountMinor: amount,
      every: _every,
      nextDate: DateTime(_next.year, _next.month, _next.day),
      anchorDay: _next.day,
      category: _category,
      wallet: _wallet,
      remindDays: remind,
      paused: _paused,
    );
    await widget.state.saveSubscription(s);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.delete),
        content: Text(widget.existing!.name),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.cancel)),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: kExpenseColor),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.delete)),
        ],
      ),
    );
    if (ok != true) return;
    await widget.state.deleteSubscription(widget.existing!);
    if (mounted) Navigator.pop(context);
  }

  String _remindLabel(AppLocalizations l, int days) {
    switch (days) {
      case -1:
        return l.remindOff;
      case 0:
        return l.remindSameDay;
      case 1:
        return l.remind1Day;
      case 3:
        return l.remind3Days;
      default:
        return l.remind7Days;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(_isEditing ? l.editSubscription : l.addSubscription),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _name,
              autofocus: !_isEditing,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: l.subscriptionName,
                errorText: _nameError,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) {
                if (_nameError != null) setState(() => _nameError = null);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l.amount,
                errorText: _amountError,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) {
                if (_amountError != null) setState(() => _amountError = null);
              },
            ),
            const SizedBox(height: 12),
            SegmentedButton<RepeatEvery>(
              segments: [
                ButtonSegment(
                    value: RepeatEvery.weekly, label: Text(l.weekly)),
                ButtonSegment(
                    value: RepeatEvery.monthly, label: Text(l.monthly)),
                ButtonSegment(value: RepeatEvery.yearly, label: Text(l.year)),
              ],
              showSelectedIcon: false,
              selected: {_every},
              onSelectionChanged: (s) => setState(() => _every = s.first),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              icon: const Icon(Icons.calendar_today_outlined, size: 18),
              label: Text('${l.nextDue}: ${DateFormat.MMMEd().format(_next)}'),
              onPressed: _pickDate,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _category,
              isExpanded: true,
              decoration: InputDecoration(
                  labelText: l.category, border: const OutlineInputBorder()),
              items: [
                for (final c in _categories)
                  DropdownMenuItem(
                      value: c,
                      child: Text(categoryLabel(l, c),
                          overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _category = v);
              },
            ),
            if (widget.state.wallets.length > 1) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _wallet,
                isExpanded: true,
                decoration: InputDecoration(
                    labelText: l.wallet, border: const OutlineInputBorder()),
                items: [
                  for (final w in widget.state.wallets)
                    DropdownMenuItem(
                        value: w.name,
                        child: Text(w.name, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _wallet = v);
                },
              ),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _remindDays,
              isExpanded: true,
              decoration: InputDecoration(
                  labelText: l.remindMe, border: const OutlineInputBorder()),
              items: [
                for (final d in const [-1, 0, 1, 3, 7])
                  DropdownMenuItem(value: d, child: Text(_remindLabel(l, d))),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _remindDays = v);
              },
            ),
            if (_isEditing)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.paused),
                value: _paused,
                onChanged: (v) => setState(() => _paused = v),
              ),
          ],
        ),
      ),
      actions: [
        if (_isEditing)
          TextButton(
            onPressed: _delete,
            child: Text(l.delete, style: const TextStyle(color: kExpenseColor)),
          ),
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(onPressed: _save, child: Text(l.save)),
      ],
    );
  }
}
