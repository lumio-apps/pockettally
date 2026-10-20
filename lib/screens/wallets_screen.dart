import 'package:flutter/material.dart';

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
            ],
          ),
        );
      },
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
