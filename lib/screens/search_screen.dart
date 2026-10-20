import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../l10n/l10n.dart';
import '../models.dart';
import '../widgets/entry_tile.dart';
import 'entry_form_screen.dart';

enum _TypeFilter { all, income, expense }

/// All entries: month by month, with search, type chips and more filters
/// (category, dates, amounts). A tab on phones; also opened by Search.
class EntriesScreen extends StatefulWidget {
  const EntriesScreen(
      {super.key, required this.state, this.searchFirst = false});

  final AppState state;

  /// Opened from a search button: the search field gets the keyboard.
  final bool searchFirst;

  @override
  State<EntriesScreen> createState() => _EntriesScreenState();
}

class _EntriesScreenState extends State<EntriesScreen> {
  final _query = TextEditingController();
  final _minAmount = TextEditingController();
  final _maxAmount = TextEditingController();

  _TypeFilter _type = _TypeFilter.all;
  String? _category; // null = all categories
  String? _wallet; // null = all wallets
  DateTimeRange? _dates;
  bool _showFilters = false;
  late DateTime _month;

  AppState get state => widget.state;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month, 1);
  }

  @override
  void dispose() {
    _query.dispose();
    _minAmount.dispose();
    _maxAmount.dispose();
    super.dispose();
  }

  /// Typing a search or picking dates looks through all months.
  bool get _allMonths => _query.text.trim().isNotEmpty || _dates != null;

  bool get _hasExtraFilters =>
      _category != null ||
      _wallet != null ||
      _dates != null ||
      _minAmount.text.isNotEmpty ||
      _maxAmount.text.isNotEmpty;

  void _clearFilters() {
    setState(() {
      _category = null;
      _dates = null;
      _minAmount.clear();
      _maxAmount.clear();
    });
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

  List<Entry> _results(AppLocalizations l) {
    final q = _query.text.trim().toLowerCase();
    final tag = q.replaceAll('#', '');
    final min = state.parseMinor(_minAmount.text);
    final max = state.parseMinor(_maxAmount.text);
    final DateTime from;
    final DateTime to;
    if (_dates != null) {
      from = _dates!.start;
      // The end date counts too.
      to = DateTime(_dates!.end.year, _dates!.end.month, _dates!.end.day + 1);
    } else if (_allMonths) {
      from = DateTime(1900);
      to = DateTime(3000);
    } else {
      from = _month;
      to = DateTime(_month.year, _month.month + 1, 1);
    }

    return state.entries.where((e) {
      if (_type == _TypeFilter.income && !e.isIncome) return false;
      if (_type == _TypeFilter.expense && e.isIncome) return false;
      if (e.date.isBefore(from) || !e.date.isBefore(to)) return false;
      if (_category != null && e.category != _category) return false;
      if (_wallet != null && state.walletNameOf(e) != _wallet) return false;
      if (min != null && e.amountMinor < min) return false;
      if (max != null && e.amountMinor > max) return false;
      if (q.isNotEmpty &&
          !e.note.toLowerCase().contains(q) &&
          !e.category.toLowerCase().contains(q) &&
          !categoryLabel(l, e.category).toLowerCase().contains(q) &&
          !e.tags.any((t) => t.contains(tag))) {
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

  String _dayLabel(AppLocalizations l, DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (day == today) return l.today;
    if (day == DateTime(today.year, today.month, today.day - 1)) {
      return l.yesterday;
    }
    return DateFormat.yMMMEd().format(day);
  }

  Widget _filters(AppLocalizations l, List<String> options) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String?>(
            key: ValueKey('cat|$_type|$_category|${options.join('|')}'),
            initialValue: _category,
            decoration: InputDecoration(
              labelText: l.category,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              DropdownMenuItem<String?>(
                  value: null, child: Text(l.allCategories)),
              for (final c in options)
                DropdownMenuItem<String?>(
                    value: c, child: Text(categoryLabel(l, c))),
            ],
            onChanged: (c) => setState(() => _category = c),
          ),
          if (state.wallets.length > 1) ...[
            const SizedBox(height: 10),
            DropdownButtonFormField<String?>(
              key: ValueKey('wallet|$_wallet'),
              initialValue: _wallet,
              decoration: InputDecoration(
                labelText: l.wallet,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                DropdownMenuItem<String?>(value: null, child: Text(l.all)),
                for (final w in state.wallets)
                  DropdownMenuItem<String?>(value: w.name, child: Text(w.name)),
              ],
              onChanged: (v) => setState(() => _wallet = v),
            ),
          ],
          const SizedBox(height: 10),
          OutlinedButton.icon(
            icon: const Icon(Icons.date_range, size: 18),
            label: Text(_dates == null
                ? l.anyDate
                : '${DateFormat.yMMMd().format(_dates!.start)} – '
                    '${DateFormat.yMMMd().format(_dates!.end)}'),
            onPressed: _pickDates,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _amountField(_minAmount, l.minAmount)),
              const SizedBox(width: 10),
              Expanded(child: _amountField(_maxAmount, l.maxAmount)),
            ],
          ),
          if (_hasExtraFilters)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: _clearFilters,
                child: Text(l.clearFilters),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final l = context.l10n;
        final options = _categoryOptions;
        if (_category != null && !options.contains(_category)) {
          _category = null;
        }
        final results = _results(l);
        final income = AppState.sumIncome(results);
        final expense = AppState.sumExpense(results);

        // Day headers and entries in one flat list, built while scrolling.
        final rows = <Object>[];
        DateTime? lastDay;
        for (final e in results) {
          final day = DateTime(e.date.year, e.date.month, e.date.day);
          if (day != lastDay) {
            rows.add(day);
            lastDay = day;
          }
          rows.add(e);
        }
        final now = DateTime.now();
        final canGoForward =
            _month.isBefore(DateTime(now.year, now.month, 1));

        final header = Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _query,
                autofocus: widget.searchFirst,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: l.searchHint,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_query.text.isNotEmpty)
                        IconButton(
                          tooltip: l.clear,
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(_query.clear),
                        ),
                      IconButton(
                        tooltip: l.moreFilters,
                        isSelected: _showFilters || _hasExtraFilters,
                        icon: const Icon(Icons.tune),
                        onPressed: () =>
                            setState(() => _showFilters = !_showFilters),
                      ),
                    ],
                  ),
                  filled: true,
                  fillColor: scheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  for (final (t, label) in [
                    (_TypeFilter.all, l.all),
                    (_TypeFilter.income, l.income),
                    (_TypeFilter.expense, l.expense),
                  ])
                    ChoiceChip(
                      label: Text(label),
                      selected: _type == t,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _type = t),
                    ),
                ],
              ),
              // More filters slide open below the chips.
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: _showFilters
                    ? _filters(l, options)
                    : const SizedBox(width: double.infinity),
              ),
              const SizedBox(height: 10),
              if (!_allMonths)
                Material(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: l.previous,
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () => setState(() => _month =
                            DateTime(_month.year, _month.month - 1, 1)),
                      ),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Text(
                            DateFormat.yMMMM().format(_month),
                            key: ValueKey(_month),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: l.next,
                        icon: const Icon(Icons.chevron_right),
                        onPressed: canGoForward
                            ? () => setState(() => _month =
                                DateTime(_month.year, _month.month + 1, 1))
                            : null,
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  Text(l.resultCount(results.length),
                      style: theme.textTheme.labelLarge),
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
            ],
          ),
        );

        return Scaffold(
          appBar: AppBar(title: Text(l.entries)),
          body: ListView.builder(
            // Room at the bottom for the + button.
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: 1 + (rows.isEmpty ? 1 : rows.length),
            itemBuilder: (context, i) {
              if (i == 0) return header;
              if (rows.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(child: Text(l.nothingFound)),
                );
              }
              final row = rows[i - 1];
              if (row is DateTime) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                  child: Text(_dayLabel(l, row),
                      style: theme.textTheme.labelLarge
                          ?.copyWith(color: scheme.onSurfaceVariant)),
                );
              }
              final e = row as Entry;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: EntryTile(
                  key: ValueKey('entries_${e.id}'),
                  entry: e,
                  state: state,
                  showDate: _allMonths,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => EntryFormScreen(state: state, entry: e),
                  )),
                ),
              );
            },
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
