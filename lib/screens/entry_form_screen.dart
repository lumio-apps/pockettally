import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../models.dart';
import 'home_screen.dart' show kIncomeColor, kExpenseColor;

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

  List<String> get _categories =>
      _type == EntryType.income ? kIncomeCategories : kExpenseCategories;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _type = e?.type ?? EntryType.expense;
    _date = e?.date ?? DateTime.now();
    _category = e?.category ?? _categories.first;
    if (!_categories.contains(_category)) {
      // Entry saved with a category that is not in the default list.
      _category = _categories.first;
    }
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.parse(_amountController.text.replaceAll(',', '.'));
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
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final color = _type == EntryType.income ? kIncomeColor : kExpenseColor;
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit entry' : 'New entry')),
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
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              style: TextStyle(
                  color: color, fontSize: 24, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: '${widget.state.currency.symbol} ',
                border: const OutlineInputBorder(),
              ),
              validator: (v) {
                final parsed = double.tryParse((v ?? '').replaceAll(',', '.'));
                if (parsed == null || parsed <= 0) {
                  return 'Enter an amount greater than 0';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final c in _categories)
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: (c) => setState(() => _category = c ?? _category),
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
