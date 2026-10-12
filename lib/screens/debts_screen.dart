import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../l10n/l10n.dart';
import '../models.dart';
import '../reminder.dart';
import '../widgets/amount_dialog.dart';
import '../widgets/entry_tile.dart' show kIncomeColor, kExpenseColor;

/// "Thu, Oct 15, 10:00" in the user's language and clock format (with the
/// year when it is not this year).
String reminderLabel(BuildContext context, DateTime at) {
  final time = MaterialLocalizations.of(context).formatTimeOfDay(
    TimeOfDay.fromDateTime(at),
    alwaysUse24HourFormat: MediaQuery.of(context).alwaysUse24HourFormat,
  );
  final day = at.year == DateTime.now().year
      ? DateFormat.MMMEd().format(at)
      : DateFormat.yMMMEd().format(at);
  return '$day, $time';
}

/// Asks for permission to show notifications (Android 13 and newer), then
/// for a day and a time. Returns null when cancelled or not allowed.
Future<DateTime?> pickReminderTime(
    BuildContext context, DateTime? current) async {
  final l = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  if (!await ReminderService.requestPermission()) {
    messenger.showSnackBar(SnackBar(content: Text(l.notificationsBlocked)));
    return null;
  }
  if (!context.mounted) return null;
  final now = DateTime.now();
  // Tomorrow at 10:00 unless a reminder is already set.
  final start = current != null && current.isAfter(now)
      ? current
      : DateTime(now.year, now.month, now.day + 1, 10);
  final day = await showDatePicker(
    context: context,
    helpText: l.remindMe,
    initialDate: start,
    firstDate: DateTime(now.year, now.month, now.day),
    lastDate: DateTime(now.year + 5, 12, 31),
  );
  if (day == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    helpText: l.remindMe,
    initialTime: TimeOfDay.fromDateTime(start),
  );
  if (time == null) return null;
  final at = DateTime(day.year, day.month, day.day, time.hour, time.minute);
  if (!at.isAfter(DateTime.now())) {
    messenger.showSnackBar(SnackBar(content: Text(l.reminderInPast)));
    return null;
  }
  return at;
}

/// Money lent to and borrowed from people, and how much is still open.
class DebtsScreen extends StatelessWidget {
  const DebtsScreen({super.key, required this.state, this.showAddButton = true});

  final AppState state;

  /// False when shown as a phone tab: the app's + button adds instead.
  final bool showAddButton;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return DefaultTabController(
      length: 2,
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(l.lendAndBorrow),
            bottom: TabBar(
              tabs: [Tab(text: l.iLent), Tab(text: l.iBorrowed)],
            ),
          ),
          floatingActionButton: !showAddButton
              ? null
              : FloatingActionButton.extended(
            icon: const Icon(Icons.add),
            label: Text(l.add),
            onPressed: () {
              final tab = DefaultTabController.of(context).index;
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => DebtFormScreen(
                  state: state,
                  initialType: tab == 0 ? DebtType.lent : DebtType.borrowed,
                ),
              ));
            },
          ),
          body: ListenableBuilder(
            listenable: state,
            builder: (context, _) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: _Total(
                              label: l.youWillGetBack,
                              value: state.formatMoney(state.toReceiveMinor),
                              color: kIncomeColor,
                            ),
                          ),
                          Expanded(
                            child: _Total(
                              label: l.youOwe,
                              value: state.formatMoney(state.toPayMinor),
                              color: kExpenseColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _DebtList(state: state, type: DebtType.lent),
                      _DebtList(state: state, type: DebtType.borrowed),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(value,
              style: TextStyle(
                  color: color, fontSize: 18, fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}

class _DebtList extends StatelessWidget {
  const _DebtList({required this.state, required this.type});

  final AppState state;
  final DebtType type;

  @override
  Widget build(BuildContext context) {
    final list = state.debts.where((d) => d.type == type).toList()
      ..sort((a, b) {
        if (a.isSettled != b.isSettled) return a.isSettled ? 1 : -1;
        return b.date.compareTo(a.date);
      });
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            type == DebtType.lent
                ? context.l10n.nobodyOwesYou
                : context.l10n.youOweNobody,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _DebtCard(state: state, debt: list[i]),
    );
  }
}

class _DebtCard extends StatelessWidget {
  const _DebtCard({required this.state, required this.debt});

  final AppState state;
  final Debt debt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    final color = debt.type == DebtType.lent ? kIncomeColor : kExpenseColor;
    final progress =
        debt.amountMinor <= 0 ? 0.0 : (debt.paidMinor / debt.amountMinor).clamp(0.0, 1.0);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showActions(context),
        child: Opacity(
          opacity: debt.isSettled ? 0.6 : 1,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: color.withValues(alpha: 0.15),
                      child: Text(
                        debt.person.isEmpty
                            ? '?'
                            : debt.person.characters.first.toUpperCase(),
                        style: TextStyle(color: color, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(debt.person,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 16)),
                          Text(
                            [
                              DateFormat.yMMMd().format(debt.date),
                              if (debt.note.isNotEmpty) debt.note,
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    debt.isSettled
                        ? Chip(
                            avatar: const Icon(Icons.check, size: 16),
                            label: Text(l.settled),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(l.left, style: theme.textTheme.bodySmall),
                              Text(
                                state.formatMoney(debt.remainingMinor),
                                style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15),
                              ),
                            ],
                          ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    color: color,
                    backgroundColor: color.withValues(alpha: 0.15),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l.paidBackOf(state.formatMoney(debt.paidMinor),
                      state.formatMoney(debt.amountMinor)),
                  style: theme.textTheme.bodySmall,
                ),
                if (debt.hasUpcomingReminder(DateTime.now())) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.notifications_active_outlined,
                          size: 16, color: theme.colorScheme.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          l.reminderAt(reminderLabel(context, debt.remindAt!)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showActions(BuildContext context) async {
    final l = context.l10n;
    final hasReminder = debt.hasUpcomingReminder(DateTime.now());
    final action = await showModalBottomSheet<String>(
      context: context,
      // Taller than usual on small phones, and scrolls if still too tall.
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!debt.isSettled) ...[
                ListTile(
                  leading: const Icon(Icons.payments_outlined),
                  title: Text(l.addPayment),
                  subtitle: Text(l.addPaymentHint),
                  onTap: () => Navigator.pop(ctx, 'pay'),
                ),
                if (ReminderService.supported)
                  ListTile(
                    leading: const Icon(Icons.notifications_outlined),
                    title: Text(hasReminder ? l.changeReminder : l.setReminder),
                    subtitle: Text(hasReminder
                        ? reminderLabel(ctx, debt.remindAt!)
                        : l.remindMeHint),
                    onTap: () => Navigator.pop(ctx, 'remind'),
                  ),
                if (hasReminder)
                  ListTile(
                    leading: const Icon(Icons.notifications_off_outlined),
                    title: Text(l.removeReminder),
                    onTap: () => Navigator.pop(ctx, 'unremind'),
                  ),
                ListTile(
                  leading: const Icon(Icons.check_circle_outline),
                  title: Text(l.markSettled),
                  onTap: () => Navigator.pop(ctx, 'settle'),
                ),
              ] else
                ListTile(
                  leading: const Icon(Icons.undo),
                  title: Text(l.reopen),
                  onTap: () => Navigator.pop(ctx, 'reopen'),
                ),
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
      ),
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case 'pay':
        final paid = await askAmount(
          context,
          state,
          title: l.paymentFrom(debt.person),
          helper: l.stillOpen(state.formatMoney(debt.remainingMinor)),
          maxMinor: debt.remainingMinor,
        );
        if (paid != null) {
          await state.saveDebt(debt.copyWith(paidMinor: debt.paidMinor + paid));
        }
      case 'remind':
        final at = await pickReminderTime(context, debt.remindAt);
        if (at != null) await state.saveDebt(debt.copyWith(remindAt: () => at));
      case 'unremind':
        await state.saveDebt(debt.copyWith(remindAt: () => null));
      case 'settle':
        // Nothing left to remind about.
        await state.saveDebt(
            debt.copyWith(paidMinor: debt.amountMinor, remindAt: () => null));
      case 'reopen':
        await state.saveDebt(debt.copyWith(paidMinor: 0));
      case 'edit':
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => DebtFormScreen(state: state, debt: debt),
        ));
      case 'delete':
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l.deleteRecordFor(debt.person)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(l.cancel)),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(l.delete)),
            ],
          ),
        );
        if (ok == true) await state.deleteDebt(debt);
    }
  }
}

/// Add or edit a lend/borrow record.
class DebtFormScreen extends StatefulWidget {
  const DebtFormScreen({
    super.key,
    required this.state,
    this.debt,
    this.initialType = DebtType.lent,
  });

  final AppState state;
  final Debt? debt;
  final DebtType initialType;

  @override
  State<DebtFormScreen> createState() => _DebtFormScreenState();
}

class _DebtFormScreenState extends State<DebtFormScreen> {
  late final TextEditingController _person;
  late final TextEditingController _note;
  late DebtType _type;
  late DateTime _date;
  int? _amountMinor;
  String? _personError;
  String? _amountError;

  /// When to remind (date and time), or null for no reminder.
  DateTime? _remindAt;
  String? _remindError;

  @override
  void initState() {
    super.initState();
    final d = widget.debt;
    _person = TextEditingController(text: d?.person ?? '');
    _note = TextEditingController(text: d?.note ?? '');
    _type = d?.type ?? widget.initialType;
    _date = d?.date ?? DateTime.now();
    _amountMinor = d?.amountMinor;
    // A reminder that is over is not shown again.
    _remindAt =
        d != null && d.hasUpcomingReminder(DateTime.now()) ? d.remindAt : null;
  }

  Future<void> _setReminder(bool on) async {
    if (!on) {
      setState(() {
        _remindAt = null;
        _remindError = null;
      });
      return;
    }
    await _changeReminder();
  }

  Future<void> _changeReminder() async {
    final at = await pickReminderTime(context, _remindAt);
    if (at == null || !mounted) return;
    setState(() {
      _remindAt = at;
      _remindError = null;
    });
  }

  @override
  void dispose() {
    _person.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickAmount() async {
    final v = await askAmount(context, widget.state,
        title: context.l10n.amount, initialMinor: _amountMinor);
    if (v != null) {
      setState(() {
        _amountMinor = v;
        _amountError = null;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final l = context.l10n;
    final person = _person.text.trim();
    final remindAt = _remindAt;
    setState(() {
      _personError = person.isEmpty ? l.enterName : null;
      _amountError = _amountMinor == null ? l.enterTheAmount : null;
      _remindError = remindAt != null && !remindAt.isAfter(DateTime.now())
          ? l.reminderInPast
          : null;
    });
    if (_personError != null || _amountError != null || _remindError != null) {
      return;
    }
    final old = widget.debt;
    final debt = Debt(
      id: old?.id,
      person: person,
      type: _type,
      amountMinor: _amountMinor!,
      // Keep payments, but never more than the (possibly smaller) amount.
      paidMinor: old == null
          ? 0
          : (old.paidMinor > _amountMinor! ? _amountMinor! : old.paidMinor),
      date: _date,
      note: _note.text.trim(),
      remindAt: remindAt,
    );
    await widget.state.saveDebt(debt);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(widget.debt == null ? l.newRecord : l.editRecord)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SegmentedButton<DebtType>(
            segments: [
              ButtonSegment(value: DebtType.lent, label: Text(l.iLent)),
              ButtonSegment(value: DebtType.borrowed, label: Text(l.iBorrowed)),
            ],
            showSelectedIcon: false,
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _person,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: _type == DebtType.lent ? l.lentTo : l.borrowedFrom,
              hintText: l.name,
              errorText: _personError,
              border: const OutlineInputBorder(),
            ),
          ),
          // People from earlier records, one tap away.
          if (widget.debt == null && widget.state.knownPeople.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final p in widget.state.knownPeople.take(6))
                  ActionChip(
                    avatar: const Icon(Icons.person_outline, size: 18),
                    label: Text(p),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() {
                      _person.text = p;
                      _personError = null;
                    }),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          InkWell(
            onTap: _pickAmount,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: l.amount,
                errorText: _amountError,
                border: const OutlineInputBorder(),
                suffixIcon: const Icon(Icons.edit_outlined),
              ),
              child: Text(_amountMinor == null
                  ? l.tapToEnter
                  : widget.state.formatMoney(_amountMinor!)),
            ),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _pickDate,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: l.date,
                border: const OutlineInputBorder(),
                suffixIcon: const Icon(Icons.calendar_today_outlined),
              ),
              child: Text(DateFormat.yMMMEd().format(_date)),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _note,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l.noteOptional,
              border: const OutlineInputBorder(),
            ),
          ),
          if (ReminderService.supported) ...[
            const SizedBox(height: 16),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.notifications_outlined),
                    title: Text(l.remindMe),
                    subtitle: Text(_remindAt == null
                        ? l.remindMeHint
                        : reminderLabel(context, _remindAt!)),
                    value: _remindAt != null,
                    onChanged: _setReminder,
                  ),
                  if (_remindAt != null)
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(
                            end: 8, bottom: 4),
                        child: TextButton.icon(
                          icon: const Icon(Icons.edit_calendar_outlined,
                              size: 18),
                          label: Text(l.changeReminder),
                          onPressed: _changeReminder,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (_remindError != null)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 6, 16, 0),
                child: Text(
                  _remindError!,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12),
                ),
              ),
          ],
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: Text(l.save)),
        ],
      ),
    );
  }
}
