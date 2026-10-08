import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../models.dart';
import '../widgets/entry_tile.dart';
import 'entry_form_screen.dart';

enum _TypeFilter { all, income, expense }

/// Search entries by text and filter by type, category, date and amount.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.state});

  final AppState state;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _query = TextEditingController();
  final _minAmount = TextEditingController();
  final _maxAmount = TextEditingController();

  _TypeFilter _type = _TypeFilter.all;
  String? _category; // null = all categories
  DateTimeRange? _dates;

  AppState get state => widget.state;

  @override
  void dispose() {
    _query.dispose();
    _minAmount.dispose();
    _maxAmount.dispose();
    super.dispose();
  }

  bool get _hasFilters =>
      _type != _TypeFilter.all ||
      _category != null ||
      _dates != null ||
      _minAmount.text.isNotEmpty ||
      _maxAmount.text.isNotEmpty;

  void _clearFilters() {
    setState(() {
      _type = _TypeFilter.all;
      _category = null;
      _dates = null;
      _minAmount.clear();
      _maxAmount.clear();
    });
  }

  /// Parses an amount field into minor units, or null when empty/invalid.
  int? _parseAmount(TextEditingController c) {
    final v = double.tryParse(c.text.replaceAll(',', '.'));
    return v == null ? null : (v * 100).round();
  }

  List<String> get _categoryOptions {
    final types = switch (_type) {
      _TypeFilter.all => [EntryType.expense, EntryType.income],
      _TypeFilter.income => [EntryType.income],
      _TypeFilter.expense => [EntryType.expense],
    };
    final names = <String>{};
    for (final t in types) {
      names.addAll(state.categoriesFor(t).map((c) => c.name));
    }
    return names.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  List<Entry> _results() {
    final q = _query.text.trim().toLowerCase();
    final min = _parseAmount(_minAmount);
    final max = _parseAmount(_maxAmount);
    final from = _dates?.start;
    // The end date is inclusive for the user, so compare with the next day.
    final to = _dates == null
        ? null
        : DateTime(_dates!.end.year, _dates!.end.month, _dates!.end.day + 1);

    return state.entries.where((e) {
      if (_type == _TypeFilter.income && !e.isIncome) return false;
      if (_type == _TypeFilter.expense && e.isIncome) return false;
      if (_category != null && e.category != _category) return false;
      if (from != null && e.date.isBefore(from)) return false;
      if (to != null && !e.date.isBefore(to)) return false;
      if (min != null && e.amountMinor < min) return false;
      if (max != null && e.amountMinor > max) return false;
      if (q.isNotEmpty &&
          !e.note.toLowerCase().contains(q) &&
          !e.category.toLowerCase().contains(q)) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _dates,
    );
    if (picked != null) setState(() => _dates = picked);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final theme = Theme.of(context);
        final options = _categoryOptions;
        if (_category != null && !options.contains(_category)) {
          _category = null;
        }
        final results = _results();
        final income = AppState.sumIncome(results);
        final expense = AppState.sumExpense(results);
        final dateFmt = DateFormat('d MMM y');

        return Scaffold(
          appBar: AppBar(
            title: TextField(
              controller: _query,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Search notes or categories',
                border: InputBorder.none,
              ),
              onChanged: (_) => setState(() {}),
            ),
            actions: [
              if (_query.text.isNotEmpty)
                IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(_query.clear),
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SegmentedButton<_TypeFilter>(
                      segments: const [
                        ButtonSegment(value: _TypeFilter.all, label: Text('All')),
                        ButtonSegment(
                            value: _TypeFilter.income, label: Text('Income')),
                        ButtonSegment(
                            value: _TypeFilter.expense, label: Text('Expense')),
                      ],
                      showSelectedIcon: false,
                      selected: {_type},
                      onSelectionChanged: (s) =>
                          setState(() => _type = s.first),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      key: ValueKey('cat|$_type|$_category|${options.join('|')}'),
                      initialValue: _category,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                            value: null, child: Text('All categories')),
                        for (final c in options)
                          DropdownMenuItem<String?>(value: c, child: Text(c)),
                      ],
                      onChanged: (c) => setState(() => _category = c),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.date_range, size: 18),
                      label: Text(_dates == null
                          ? 'Any date'
                          : '${dateFmt.format(_dates!.start)} – ${dateFmt.format(_dates!.end)}'),
                      onPressed: _pickDates,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _amountField(_minAmount, 'Min amount')),
                        const SizedBox(width: 12),
                        Expanded(child: _amountField(_maxAmount, 'Max amount')),
                      ],
                    ),
                    if (_hasFilters)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _clearFilters,
                          child: const Text('Clear filters'),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    Text(
                      results.length == 1 ? '1 result' : '${results.length} results',
                      style: theme.textTheme.labelLarge,
                    ),
                    if (income > 0)
                      Text('+ ${state.formatMoney(income)}',
                          style: const TextStyle(
                              color: kIncomeColor, fontWeight: FontWeight.w600)),
                    if (expense > 0)
                      Text('- ${state.formatMoney(expense)}',
                          style: const TextStyle(
                              color: kExpenseColor, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (results.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('Nothing found.')),
                )
              else
                for (final e in results)
                  EntryTile(
                    entry: e,
                    state: state,
                    showDate: true,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => EntryFormScreen(state: state, entry: e),
                    )),
                  ),
            ],
          ),
        );
      },
    );
  }

  Widget _amountField(TextEditingController c, String label) {
    return TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      decoration: InputDecoration(
        labelText: label,
        prefixText: '${state.currency.symbol} ',
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: (_) => setState(() {}),
    );
  }
}
