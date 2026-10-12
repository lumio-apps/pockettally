import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../l10n/l10n.dart';
import '../models.dart';
import '../split.dart';
import '../theme.dart';

/// Shares a bill between the user and other people: equally or with custom
/// amounts, paid by the user or by someone else. Returns a [SplitPlan].
class SplitBillScreen extends StatefulWidget {
  const SplitBillScreen({
    super.key,
    required this.state,
    required this.totalMinor,
    this.initial,
  });

  final AppState state;

  /// The whole bill, in minor units.
  final int totalMinor;

  /// The split chosen before, when it is opened again.
  final SplitPlan? initial;

  @override
  State<SplitBillScreen> createState() => _SplitBillScreenState();
}

class _SplitBillScreenState extends State<SplitBillScreen> {
  final List<String> _people = [];

  /// Custom amounts: the user's first, then one per person.
  final List<TextEditingController> _amounts = [TextEditingController()];
  final TextEditingController _newPerson = TextEditingController();
  bool _equal = true;
  String? _paidBy;
  String? _personError;

  AppState get state => widget.state;

  /// Whole units when amounts are shown without decimals.
  int get _unit => state.money.decimals == 0 ? 100 : 1;

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    if (p == null) return;
    _people.addAll(p.people);
    _equal = p.equal;
    _paidBy = p.paidBy;
    for (var i = 0; i < p.people.length; i++) {
      _amounts.add(TextEditingController());
    }
    if (!p.equal && p.shares.length == _amounts.length) {
      for (var i = 0; i < _amounts.length; i++) {
        _amounts[i].text = state.amountInput(p.shares[i]);
      }
    }
  }

  @override
  void dispose() {
    for (final c in _amounts) {
      c.dispose();
    }
    _newPerson.dispose();
    super.dispose();
  }

  List<int> get _customShares =>
      [for (final c in _amounts) state.parseMinor(c.text) ?? 0];

  /// Each person's share (the user's first), or null without people.
  List<int>? get _shares {
    if (_people.isEmpty) return null;
    return _equal
        ? splitEqually(widget.totalMinor, _people.length + 1, unit: _unit)
        : _customShares;
  }

  bool get _valid {
    if (_people.isEmpty) return false;
    if (_equal) return true;
    final shares = _customShares;
    return shares.every((s) => s >= 0) &&
        shares.fold<int>(0, (a, b) => a + b) == widget.totalMinor;
  }

  void _addPerson([String? name]) {
    final l = context.l10n;
    final n = (name ?? _newPerson.text).trim();
    if (n.isEmpty) return;
    final key = n.toLowerCase();
    if (key == l.you.toLowerCase() ||
        _people.any((p) => p.toLowerCase() == key)) {
      setState(() => _personError = l.nameExists);
      return;
    }
    setState(() {
      _people.add(n);
      _amounts.add(TextEditingController());
      _personError = null;
      if (name == null) _newPerson.clear();
    });
  }

  void _removePerson(int i) {
    final controller = _amounts[i + 1];
    setState(() {
      final removed = _people.removeAt(i);
      _amounts.removeAt(i + 1);
      if (_paidBy == removed) _paidBy = null;
    });
    // Disposed after the frame, once its text field is gone.
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
  }

  void _setEqual(bool equal) {
    setState(() {
      _equal = equal;
      if (!equal) {
        // Custom amounts start from the equal split.
        final shares = splitEqually(
            widget.totalMinor, _people.length + 1, unit: _unit);
        for (var i = 0; i < _amounts.length; i++) {
          _amounts[i].text = state.amountInput(shares[i]);
        }
      }
    });
  }

  void _done() {
    if (!_valid) return;
    Navigator.of(context).pop(SplitPlan(
      people: List<String>.of(_people),
      equal: _equal,
      shares: _equal ? const [] : _customShares,
      paidBy: _paidBy,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final brand = BrandColors.of(context);
    final shares = _shares;
    final known = state.knownPeople
        .where((p) => !_people.any((x) => x.toLowerCase() == p.toLowerCase()))
        .take(8)
        .toList();
    final titleStyle =
        theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800);

    return Scaffold(
      appBar: AppBar(title: Text(l.splitBill)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: brand.brand,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.receipt_long_outlined,
                              color: Colors.white),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l.billTotal,
                                  style: TextStyle(
                                      color: brand.label,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: AlignmentDirectional.centerStart,
                                child: Text(
                                  state.formatMoney(widget.totalMinor),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(l.splitWith, style: titleStyle),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _newPerson,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      hintText: l.addPerson,
                      errorText: _personError,
                      prefixIcon: const Icon(Icons.person_add_alt_1_outlined),
                      suffixIcon: IconButton(
                        tooltip: l.add,
                        icon: const Icon(Icons.add_circle),
                        onPressed: () => _addPerson(),
                      ),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onChanged: (_) {
                      if (_personError != null) {
                        setState(() => _personError = null);
                      }
                    },
                    onSubmitted: (_) => _addPerson(),
                  ),
                  if (known.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final p in known)
                          ActionChip(
                            avatar: const Icon(Icons.add, size: 16),
                            label: Text(p),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _addPerson(p),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(
                        value: true,
                        icon: const Icon(Icons.people_outline),
                        label: Text(l.splitEqually),
                      ),
                      ButtonSegment(
                        value: false,
                        icon: const Icon(Icons.tune),
                        label: Text(l.splitCustom),
                      ),
                    ],
                    showSelectedIcon: false,
                    selected: {_equal},
                    onSelectionChanged: (s) => _setEqual(s.first),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        children: [
                          _personRow(context, 0, l.you, shares),
                          for (var i = 0; i < _people.length; i++)
                            _personRow(context, i + 1, _people[i], shares,
                                onRemove: () => _removePerson(i)),
                        ],
                      ),
                    ),
                  ),
                  if (_people.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String?>(
                      // Rebuilt when the people change, so a removed payer
                      // is never selected.
                      key: ValueKey('paid-${_people.join('|')}-$_paidBy'),
                      initialValue: _paidBy,
                      decoration: InputDecoration(
                        labelText: l.paidBy,
                        prefixIcon:
                            const Icon(Icons.account_balance_wallet_outlined),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      items: [
                        DropdownMenuItem<String?>(
                            value: null, child: Text(l.you)),
                        for (final p in _people)
                          DropdownMenuItem<String?>(value: p, child: Text(p)),
                      ],
                      onChanged: (v) => setState(() => _paidBy = v),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _summary(context, shares),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _valid ? _done : null,
                  child: Text(l.done),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _personRow(
    BuildContext context,
    int index,
    String name,
    List<int>? shares, {
    VoidCallback? onRemove,
  }) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final me = index == 0;
    final color = me
        ? theme.colorScheme.primary
        : Color(kCategoryPalette[(index * 3) % kCategoryPalette.length]);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 4, 4, 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: 0.16),
            child: me
                ? Icon(Icons.person, size: 20, color: color)
                : Text(
                    name.characters.first.toUpperCase(),
                    style: TextStyle(color: color, fontWeight: FontWeight.w800),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontWeight: me ? FontWeight.w800 : FontWeight.w600),
            ),
          ),
          if (_equal)
            Text(
              shares == null ? '–' : state.formatMoney(shares[index]),
              style: const TextStyle(fontWeight: FontWeight.w700),
            )
          else
            SizedBox(
              width: 128,
              child: TextField(
                controller: _amounts[index],
                textAlign: TextAlign.end,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r"[0-9.,+*/×÷xX() ']")),
                ],
                decoration: InputDecoration(
                  isDense: true,
                  prefixText: '${state.currency.symbol} ',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          onRemove == null
              ? const SizedBox(width: 48)
              : IconButton(
                  tooltip: l.remove,
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: onRemove,
                ),
        ],
      ),
    );
  }

  /// What the split means: the user's share, and who owes whom.
  Widget _summary(BuildContext context, List<int>? shares) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lines = <Widget>[];
    var error = false;
    if (_people.isEmpty || shares == null) {
      lines.add(Text(l.splitAddPeopleHint));
    } else if (!_valid) {
      error = true;
      lines.add(Text(l.splitSharesMismatch(
          state.formatMoney(shares.fold<int>(0, (a, b) => a + b)),
          state.formatMoney(widget.totalMinor))));
    } else {
      final bold = theme.textTheme.titleSmall
          ?.copyWith(fontWeight: FontWeight.w800, color: scheme.primary);
      lines.add(Text(l.yourShare(state.formatMoney(shares[0])), style: bold));
      final payer = _paidBy;
      lines.add(const SizedBox(height: 2));
      lines.add(Text(
        payer == null
            ? l.othersOweYou(state.formatMoney(SplitPlan.othersTotal(shares)))
            : l.youOwePerson(payer, state.formatMoney(shares[0])),
        style: bold,
      ));
      lines.add(const SizedBox(height: 6));
      lines.add(Text(
        payer == null ? l.splitNoteIPaid : l.splitNoteOtherPaid,
        style: theme.textTheme.bodySmall,
      ));
    }
    final color = error ? scheme.error : scheme.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(error ? Icons.error_outline : Icons.call_split, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: DefaultTextStyle.merge(
              style: TextStyle(color: error ? scheme.error : null),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: lines,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
