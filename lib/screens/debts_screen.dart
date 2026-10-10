import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../models.dart';
import '../widgets/amount_dialog.dart';
import '../widgets/entry_tile.dart' show kIncomeColor, kExpenseColor;

/// Money lent to and borrowed from people, and how much is still open.
class DebtsScreen extends StatelessWidget {
  const DebtsScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Lend & Borrow'),
            bottom: const TabBar(
              tabs: [Tab(text: 'I lent'), Tab(text: 'I borrowed')],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            icon: const Icon(Icons.add),
            label: const Text('Add'),
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
                              label: "You'll get back",
                              value: state.formatMoney(state.toReceiveMinor),
                              color: kIncomeColor,
                            ),
                          ),
                          Expanded(
                            child: _Total(
                              label: 'You owe',
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
          alignment: Alignment.centerLeft,
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
                ? 'Nobody owes you money.\nTap Add when you lend money to someone.'
                : 'You owe nobody.\nTap Add when you borrow money from someone.',
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
                        debt.person.isEmpty ? '?' : debt.person[0].toUpperCase(),
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
                              DateFormat('d MMM y').format(debt.date),
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
                        ? const Chip(
                            avatar: Icon(Icons.check, size: 16),
                            label: Text('Settled'),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('Left', style: theme.textTheme.bodySmall),
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
                  '${state.formatMoney(debt.paidMinor)} of ${state.formatMoney(debt.amountMinor)} paid back',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showActions(BuildContext context) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!debt.isSettled) ...[
              ListTile(
                leading: const Icon(Icons.payments_outlined),
                title: const Text('Add a payment'),
                subtitle: const Text('Part of the money was paid back'),
                onTap: () => Navigator.pop(ctx, 'pay'),
              ),
              ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: const Text('Mark as settled'),
                onTap: () => Navigator.pop(ctx, 'settle'),
              ),
            ] else
              ListTile(
                leading: const Icon(Icons.undo),
                title: const Text('Reopen'),
                onTap: () => Navigator.pop(ctx, 'reopen'),
              ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              onTap: () => Navigator.pop(ctx, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: kExpenseColor),
              title: const Text('Delete', style: TextStyle(color: kExpenseColor)),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case 'pay':
        final paid = await askAmount(
          context,
          state,
          title: 'Payment from ${debt.person}',
          helper: '${state.formatMoney(debt.remainingMinor)} is still open',
          maxMinor: debt.remainingMinor,
        );
        if (paid != null) {
          await state.saveDebt(debt.copyWith(paidMinor: debt.paidMinor + paid));
        }
      case 'settle':
        await state.saveDebt(debt.copyWith(paidMinor: debt.amountMinor));
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
            title: Text('Delete the record for ${debt.person}?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Delete')),
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

  @override
  void initState() {
    super.initState();
    final d = widget.debt;
    _person = TextEditingController(text: d?.person ?? '');
    _note = TextEditingController(text: d?.note ?? '');
    _type = d?.type ?? widget.initialType;
    _date = d?.date ?? DateTime.now();
    _amountMinor = d?.amountMinor;
  }

  @override
  void dispose() {
    _person.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickAmount() async {
    final v = await askAmount(context, widget.state,
        title: 'Amount', initialMinor: _amountMinor);
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
    final person = _person.text.trim();
    setState(() {
      _personError = person.isEmpty ? 'Enter a name' : null;
      _amountError = _amountMinor == null ? 'Enter the amount' : null;
    });
    if (_personError != null || _amountError != null) return;
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
    );
    await widget.state.saveDebt(debt);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.debt == null ? 'New record' : 'Edit record')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SegmentedButton<DebtType>(
            segments: const [
              ButtonSegment(value: DebtType.lent, label: Text('I lent')),
              ButtonSegment(value: DebtType.borrowed, label: Text('I borrowed')),
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
              labelText: _type == DebtType.lent ? 'Lent to' : 'Borrowed from',
              hintText: 'Name',
              errorText: _personError,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _pickAmount,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Amount',
                errorText: _amountError,
                border: const OutlineInputBorder(),
                suffixIcon: const Icon(Icons.edit_outlined),
              ),
              child: Text(_amountMinor == null
                  ? 'Tap to enter'
                  : widget.state.formatMoney(_amountMinor!)),
            ),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _pickDate,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Date',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today_outlined),
              ),
              child: Text(DateFormat('EEE, d MMM y').format(_date)),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _note,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
    );
  }
}
