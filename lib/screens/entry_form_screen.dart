import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../models.dart';
import '../utils/amount_parser.dart';
import '../widgets/entry_tile.dart'
    show kIncomeColor, kExpenseColor, deleteEntryWithUndo;
import 'categories_screen.dart';

/// Add a new entry, or edit an existing one when [entry] is given.
class EntryFormScreen extends StatefulWidget {
  const EntryFormScreen({super.key, required this.state, this.entry});

  final AppState state;
  final Entry? entry;

  @override
  State<EntryFormScreen> createState() => _EntryFormScreenState();
}

class _EntryFormScreenState extends State<EntryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;

  late EntryType _type;
  late String _category;
  late DateTime _date;
  IncomePeriod _period = IncomePeriod.monthly;

  bool get _isEditing => widget.entry != null;

  List<String> get _categories {
    final names =
        widget.state.categoriesFor(_type).map((c) => c.name).toList();
    return names.isEmpty ? [kOtherCategory] : names;
  }

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _type = e?.type ?? EntryType.expense;
    _date = e?.date ?? DateTime.now();
    _category = e?.category ?? _categories.first;
    _period = e?.period ?? IncomePeriod.monthly;
    _amountController = TextEditingController(
      text: e == null ? '' : (e.amountMinor / 100).toStringAsFixed(2),
    );
    _noteController = TextEditingController(text: e?.note ?? '');
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
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

  /// Inserts an operator (or bracket) at the cursor in the amount field.
  void _insert(String text) {
    final c = _amountController;
    final sel = c.selection;
    final start = sel.isValid ? sel.start : c.text.length;
    final end = sel.isValid ? sel.end : c.text.length;
    final newText = c.text.replaceRange(start, end, text);
    c.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + text.length),
    );
    setState(() {});
  }

  /// Replaces a calculation like "120+45" with its result "165.00".
  void _applyResult() {
    final v = evaluateAmount(_amountController.text);
    if (v == null) return;
    final text = v.toStringAsFixed(2);
    _amountController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    setState(() {});
  }

  Future<void> _delete() async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this entry?'),
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
    if (ok != true || !mounted) return;
    Navigator.of(context).pop();
    await deleteEntryWithUndo(messenger, widget.state, widget.entry!);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = evaluateAmount(_amountController.text)!;
    final messenger = ScaffoldMessenger.of(context);
    final entry = Entry(
      id: widget.entry?.id,
      type: _type,
      amountMinor: (amount * 100).round(),
      category: _category,
      date: _date,
      note: _noteController.text.trim(),
      period: _type == EntryType.income ? _period : null,
    );
    if (_isEditing) {
      await widget.state.updateEntry(entry);
    } else {
      await widget.state.addEntry(entry);
    }
    final warning = widget.state.budgetWarningFor(entry);
    if (mounted) Navigator.of(context).pop();
    if (warning != null) {
      messenger.showSnackBar(SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.amber),
            const SizedBox(width: 12),
            Expanded(child: Text(warning)),
          ],
        ),
        duration: const Duration(seconds: 5),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _type == EntryType.income ? kIncomeColor : kExpenseColor;
    final categoryNames = _categories;
    if (!categoryNames.contains(_category)) {
      // The category was renamed or deleted in the meantime.
      _category = categoryNames.contains(kOtherCategory)
          ? kOtherCategory
          : categoryNames.first;
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit entry' : 'New entry'),
        actions: [
          if (_isEditing)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<EntryType>(
              segments: const [
                ButtonSegment(
                  value: EntryType.expense,
                  label: Text('Expense'),
                  icon: Icon(Icons.north_east),
                ),
                ButtonSegment(
                  value: EntryType.income,
                  label: Text('Income'),
                  icon: Icon(Icons.south_west),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() {
                _type = s.first;
                _category = _categories.first;
              }),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _amountController,
              autofocus: !_isEditing,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,+\-*/×÷()]')),
              ],
              style: TextStyle(
                  color: color, fontSize: 24, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: '${widget.state.currency.symbol} ',
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
              validator: (v) {
                final parsed = evaluateAmount(v ?? '');
                if (parsed == null || parsed <= 0) {
                  return 'Enter an amount greater than 0';
                }
                if ((parsed * 100).round() <= 0) {
                  return 'Amount is too small';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            _CalculatorRow(
              onInsert: _insert,
              onEquals: _applyResult,
              result: isCalculation(_amountController.text)
                  ? evaluateAmount(_amountController.text)
                  : null,
              currencySymbol: widget.state.currency.symbol,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              // The key rebuilds the field when Income/Expense is switched or
              // the category list changes, because initialValue is read once.
              key: ValueKey('$_type|${categoryNames.join('|')}'),
              initialValue: _category,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final c in categoryNames)
                  DropdownMenuItem(
                    value: c,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 6,
                          backgroundColor: widget.state.colorFor(c, _type),
                        ),
                        const SizedBox(width: 10),
                        Text(c),
                      ],
                    ),
                  ),
              ],
              onChanged: (c) => setState(() => _category = c ?? _category),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.tune, size: 18),
                label: const Text('Manage categories'),
                onPressed: () async {
                  await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => CategoriesScreen(
                      state: widget.state,
                      initialType: _type,
                    ),
                  ));
                  if (mounted) setState(() {});
                },
              ),
            ),
            if (_type == EntryType.income) ...[
              const SizedBox(height: 16),
              Text('This income is', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 6),
              SegmentedButton<IncomePeriod>(
                segments: const [
                  ButtonSegment(
                      value: IncomePeriod.daily, label: Text('Daily')),
                  ButtonSegment(
                      value: IncomePeriod.weekly, label: Text('Weekly')),
                  ButtonSegment(
                      value: IncomePeriod.monthly, label: Text('Monthly')),
                ],
                selected: {_period},
                onSelectionChanged: (s) => setState(() => _period = s.first),
              ),
            ],
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
            TextFormField(
              controller: _noteController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _save,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Operator buttons under the amount field, and the live result.
class _CalculatorRow extends StatelessWidget {
  const _CalculatorRow({
    required this.onInsert,
    required this.onEquals,
    required this.result,
    required this.currencySymbol,
  });

  final ValueChanged<String> onInsert;
  final VoidCallback onEquals;
  final double? result;
  final String currencySymbol;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget op(String label, String insert, String tooltip) => Tooltip(
          message: tooltip,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(48, 44),
              padding: EdgeInsets.zero,
            ),
            onPressed: () => onInsert(insert),
            child: Text(label, style: const TextStyle(fontSize: 18)),
          ),
        );
    return Row(
      children: [
        op('+', '+', 'Add'),
        const SizedBox(width: 6),
        op('−', '-', 'Subtract'),
        const SizedBox(width: 6),
        op('×', '×', 'Multiply'),
        const SizedBox(width: 6),
        op('÷', '÷', 'Divide'),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: result == null
                ? const SizedBox.shrink()
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    child: TextButton(
                      onPressed: onEquals,
                      child: Text(
                        '= $currencySymbol ${result!.toStringAsFixed(2)}',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
