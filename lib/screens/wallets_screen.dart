import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../l10n/l10n.dart';
import '../models.dart';
import '../widgets/entry_tile.dart' show kIncomeColor, kExpenseColor;
import '../widgets/neo.dart';

/// Cash, bank, UPI, card: where the money is, and how much is in each.
class WalletsScreen extends StatelessWidget {
  const WalletsScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final wallets = state.wallets;
        final total = wallets.fold<int>(0, (s, w) => s + state.walletBalance(w));
        return Scaffold(
          appBar: AppBar(title: Text(l.wallets)),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => showWalletDialog(context, state),
            icon: const Icon(Icons.add),
            label: Text(l.addWallet),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                child: Text(
                  '${l.walletsTotal}: ${state.formatMoney(total)}',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              if (wallets.length > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48)),
                    icon: const Icon(Icons.swap_horiz),
                    label: Text(l.transfer),
                    onPressed: () => showTransferDialog(context, state),
                  ),
                ),
              for (final w in wallets)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: NeoCard(
                    onTap: () => showWalletDialog(context, state, existing: w),
                    child: ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 14),
                      leading: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                            color: Color(w.colorValue), shape: BoxShape.circle),
                        child: const Icon(Icons.account_balance_wallet_outlined,
                            color: Colors.white, size: 21),
                      ),
                      title: Text(w.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: w.openingMinor == 0
                          ? null
                          : Text(
                              '${l.openingBalance}: ${state.formatMoney(w.openingMinor)}'),
                      trailing: Text(
                        state.formatMoney(state.walletBalance(w)),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: state.walletBalance(w) < 0
                              ? kExpenseColor
                              : kIncomeColor,
                        ),
                      ),
                    ),
                  ),
                ),
              if (state.transfers.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
                  child: Text(
                    l.transfers,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w800),
                  ),
                ),
                for (final t in state.transfers.take(30))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: NeoCard(
                      child: ListTile(
                        contentPadding:
                            const EdgeInsets.only(left: 14, right: 4),
                        leading: const Icon(Icons.swap_horiz),
                        title: Text('${t.from} → ${t.to}',
                            overflow: TextOverflow.ellipsis,
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(
                          [
                            DateFormat.MMMEd().format(t.date),
                            if (t.note.isNotEmpty) t.note,
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(state.formatMoney(t.amountMinor),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800)),
                            IconButton(
                              tooltip: l.delete,
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _deleteTransfer(context, t),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteTransfer(BuildContext context, Transfer t) async {
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    await state.deleteTransfer(t);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        duration: const Duration(seconds: 3),
        persist: false,
        content: Text(l.transferDeleted),
        action: SnackBarAction(
          label: l.undo,
          onPressed: () => state.restoreTransfer(t),
        ),
      ));
  }
}

/// Dialog to move money from one wallet to another.
Future<void> showTransferDialog(BuildContext context, AppState state) {
  return showDialog<void>(
    context: context,
    builder: (_) => _TransferDialog(state: state),
  );
}

class _TransferDialog extends StatefulWidget {
  const _TransferDialog({required this.state});

  final AppState state;

  @override
  State<_TransferDialog> createState() => _TransferDialogState();
}

class _TransferDialogState extends State<_TransferDialog> {
  late String _from;
  late String _to;
  DateTime _date = DateTime.now();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    final names = widget.state.wallets.map((w) => w.name).toList();
    _from = widget.state.defaultWalletName;
    _to = names.firstWhere((n) => n != _from, orElse: () => names.first);
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _save() {
    final l = context.l10n;
    if (_from == _to) {
      setState(() => _error = l.transferSameWallet);
      return;
    }
    final amount = widget.state.parseMinor(_amount.text);
    if (amount == null || amount <= 0) {
      setState(() => _error = l.enterAmountAboveZero);
      return;
    }
    widget.state.addTransfer(Transfer(
      from: _from,
      to: _to,
      amountMinor: amount,
      date: _date,
      note: _note.text.trim(),
    ));
    Navigator.pop(context);
  }

  Widget _walletField(
      String label, String value, ValueChanged<String> onChanged) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
          labelText: label, border: const OutlineInputBorder()),
      items: [
        for (final w in widget.state.wallets)
          DropdownMenuItem(
              value: w.name,
              child: Text(w.name, overflow: TextOverflow.ellipsis)),
      ],
      onChanged: (v) {
        if (v == null) return;
        setState(() {
          _error = null;
          onChanged(v);
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.transfer),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _walletField(l.transferFrom, _from, (v) => _from = v),
            const SizedBox(height: 12),
            _walletField(l.transferTo, _to, (v) => _to = v),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l.amount,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l.noteOptional,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              icon: const Icon(Icons.calendar_today_outlined, size: 18),
              label: Text(DateFormat.MMMEd().format(_date)),
              onPressed: _pickDate,
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(_error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(onPressed: _save, child: Text(l.save)),
      ],
    );
  }
}

/// Dialog to add a wallet, or edit [existing] (rename, color, opening
/// balance, delete).
Future<void> showWalletDialog(BuildContext context, AppState state,
    {Wallet? existing}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _WalletDialog(state: state, existing: existing),
  );
}

class _WalletDialog extends StatefulWidget {
  const _WalletDialog({required this.state, this.existing});

  final AppState state;
  final Wallet? existing;

  @override
  State<_WalletDialog> createState() => _WalletDialogState();
}

class _WalletDialogState extends State<_WalletDialog> {
  late final TextEditingController _name;
  late final TextEditingController _opening;
  late int _color;
  String? _nameError;
  String? _openingError;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final w = widget.existing;
    _name = TextEditingController(text: w?.name ?? '');
    _opening = TextEditingController(
        text: w == null || w.openingMinor == 0
            ? ''
            : widget.state.amountInput(w.openingMinor));
    _color = w?.colorValue ??
        kCategoryPalette[widget.state.wallets.length % kCategoryPalette.length];
  }

  @override
  void dispose() {
    _name.dispose();
    _opening.dispose();
    super.dispose();
  }

  void _save() {
    final l = context.l10n;
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = l.enterName);
      return;
    }
    if (widget.state.walletNameTaken(name, except: widget.existing)) {
      setState(() => _nameError = l.walletNameTaken);
      return;
    }
    var opening = 0;
    if (_opening.text.trim().isNotEmpty) {
      final parsed = widget.state.parseMinor(_opening.text);
      if (parsed == null) {
        setState(() => _openingError = l.enterValidAmount);
        return;
      }
      opening = parsed;
    }
    final old = widget.existing;
    if (old == null) {
      widget.state.addWallet(Wallet(
          name: name, colorValue: _color, openingMinor: opening));
    } else {
      widget.state.updateWallet(
          old,
          old.copyWith(
              name: name, colorValue: _color, openingMinor: opening));
    }
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final l = context.l10n;
    final w = widget.existing!;
    final main = widget.state.mainWallet.name;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.delete),
        content: Text(l.deleteWalletQuestion(w.name, main)),
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
    await widget.state.deleteWallet(w);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(_isEditing ? l.editWallet : l.addWallet),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              autofocus: !_isEditing,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: l.walletName,
                errorText: _nameError,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) {
                if (_nameError != null) setState(() => _nameError = null);
              },
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _opening,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true, signed: true),
              decoration: InputDecoration(
                labelText: l.openingBalance,
                helperText: l.openingBalanceHint,
                helperMaxLines: 3,
                errorText: _openingError,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) {
                if (_openingError != null) setState(() => _openingError = null);
              },
            ),
            const SizedBox(height: 16),
            Text(l.color),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final c in kCategoryPalette)
                  GestureDetector(
                    onTap: () => setState(() => _color = c),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: Color(c),
                      child: c == _color
                          ? const Icon(Icons.check,
                              size: 18, color: Colors.white)
                          : null,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        if (_isEditing && !widget.existing!.main)
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
