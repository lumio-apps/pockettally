import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../l10n/l10n.dart';
import '../models.dart';
import '../report_options.dart';
import '../report_pdf.dart';

enum _Preset { thisMonth, lastMonth, thisYear, lastYear, custom }

/// "PDF report": choose the period, which entries, which categories and
/// which parts go into the PDF, then save it.
class ReportOptionsScreen extends StatefulWidget {
  const ReportOptionsScreen({
    super.key,
    required this.state,
    required this.start,
    required this.end,
  });

  final AppState state;

  /// The period shown on Reports, used at first (end is exclusive).
  final DateTime start;
  final DateTime end;

  @override
  State<ReportOptionsScreen> createState() => _ReportOptionsScreenState();
}

class _ReportOptionsScreenState extends State<ReportOptionsScreen> {
  late DateTime _start;
  late DateTime _end;
  late _Preset _preset;
  late ReportType _type;
  late Set<ReportSection> _sections;

  /// Chosen categories; null = all.
  Set<String>? _categories;
  bool _busy = false;

  AppState get state => widget.state;

  @override
  void initState() {
    super.initState();
    _start = widget.start;
    _end = widget.end;
    _preset = _matchPreset(_start, _end);
    final remembered = ReportOptions.remembered(state.pdfOptions,
        start: _start, end: _end);
    _type = remembered.type;
    _sections = {...remembered.sections};
  }

  (DateTime, DateTime) _rangeOf(_Preset p) {
    final now = DateTime.now();
    switch (p) {
      case _Preset.thisMonth:
        return (DateTime(now.year, now.month, 1),
            DateTime(now.year, now.month + 1, 1));
      case _Preset.lastMonth:
        return (DateTime(now.year, now.month - 1, 1),
            DateTime(now.year, now.month, 1));
      case _Preset.thisYear:
        return (DateTime(now.year, 1, 1), DateTime(now.year + 1, 1, 1));
      case _Preset.lastYear:
        return (DateTime(now.year - 1, 1, 1), DateTime(now.year, 1, 1));
      case _Preset.custom:
        return (_start, _end);
    }
  }

  _Preset _matchPreset(DateTime start, DateTime end) {
    for (final p in _Preset.values) {
      if (p == _Preset.custom) continue;
      final (s, e) = _rangeOf(p);
      if (s == start && e == end) return p;
    }
    return _Preset.custom;
  }

  String _presetLabel(AppLocalizations l, _Preset p) => switch (p) {
        _Preset.thisMonth => l.periodThisMonth,
        _Preset.lastMonth => l.periodLastMonth,
        _Preset.thisYear => l.periodThisYear,
        _Preset.lastYear => l.periodLastYear,
        _Preset.custom => l.periodCustom,
      };

  DateTime get _lastDay => DateTime(_end.year, _end.month, _end.day - 1);

  /// "October 2026", "2026" or "1 Oct 2026 – 15 Nov 2026".
  String get _periodLabel {
    final last = _lastDay;
    if (_start.day == 1 && _end == DateTime(_start.year, _start.month + 1, 1)) {
      return DateFormat.yMMMM().format(_start);
    }
    if (_start == DateTime(_start.year, 1, 1) &&
        _end == DateTime(_start.year + 1, 1, 1)) {
      return '${_start.year}';
    }
    if (_start == last) return DateFormat.yMMMd().format(_start);
    return '${DateFormat.yMMMd().format(_start)} – ${DateFormat.yMMMd().format(last)}';
  }

  void _pickPreset(_Preset p) {
    if (p == _Preset.custom) {
      _pickDates();
      return;
    }
    final (s, e) = _rangeOf(p);
    setState(() {
      _preset = p;
      _start = s;
      _end = e;
    });
  }

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: DateTimeRange(start: _start, end: _lastDay),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _start = DateTime(picked.start.year, picked.start.month, picked.start.day);
      _end = DateTime(picked.end.year, picked.end.month, picked.end.day + 1);
      _preset = _matchPreset(_start, _end);
    });
  }

  /// Category names offered for the chosen kind of entries, in the user's
  /// order; the same name of both kinds ("Other") once.
  List<String> get _categoryNames {
    final types = switch (_type) {
      ReportType.all => [EntryType.expense, EntryType.income],
      ReportType.expenses => [EntryType.expense],
      ReportType.income => [EntryType.income],
    };
    final names = <String>[];
    for (final t in types) {
      for (final c in state.categoriesFor(t)) {
        if (!names.contains(c.name)) names.add(c.name);
      }
    }
    return names;
  }

  void _toggleCategory(String name) {
    setState(() {
      final current = _categories;
      if (current == null) {
        _categories = {name};
      } else if (current.contains(name)) {
        current.remove(name);
        // Nothing ticked means all again.
        if (current.isEmpty) _categories = null;
      } else {
        current.add(name);
      }
    });
  }

  Future<void> _create() async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final cats = _categories;
    final options = ReportOptions(
      start: _start,
      end: _end,
      type: _type,
      // Only categories that still fit the chosen kind of entries.
      categories: cats?.where(_categoryNames.contains).toSet(),
      sections: _sections,
    );
    setState(() => _busy = true);
    try {
      await state.setPdfOptions(options.rememberJson());
      final saved = await ReportPdf.saveReport(
        state: state,
        options: options,
        periodLabel: _periodLabel,
      );
      if (saved) {
        messenger.showSnackBar(SnackBar(duration: const Duration(seconds: 3), content: Text(l.pdfSaved)));
      }
    } catch (_) {
      messenger.showSnackBar(SnackBar(duration: const Duration(seconds: 3), content: Text(l.couldNotCreatePdf)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final label = theme.textTheme.labelLarge?.copyWith(
        color: theme.colorScheme.primary, fontWeight: FontWeight.w800);
    final names = _categoryNames;
    final cats = _categories;
    final spansMonths =
        _end.isAfter(DateTime(_start.year, _start.month + 1, 1));
    final wholeMonth =
        _start.day == 1 && _end == DateTime(_start.year, _start.month + 1, 1);

    Widget heading(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
          child: Text(text, style: label),
        );

    Widget sectionTile(ReportSection s, String title,
            {String? subtitle, bool enabled = true}) =>
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(title,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: subtitle == null ? null : Text(subtitle),
          value: _sections.contains(s),
          onChanged: !enabled || _busy
              ? null
              : (v) => setState(() {
                    if (v == true) {
                      _sections.add(s);
                    } else {
                      _sections.remove(s);
                    }
                  }),
        );

    return Scaffold(
      appBar: AppBar(title: Text(l.pdfReport)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  heading(l.period),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final p in _Preset.values)
                        ChoiceChip(
                          label: Text(_presetLabel(l, p)),
                          selected: _preset == p,
                          onSelected: _busy ? null : (_) => _pickPreset(p),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48)),
                    icon: const Icon(Icons.date_range_outlined, size: 18),
                    label: Text(_periodLabel),
                    onPressed: _busy ? null : _pickDates,
                  ),
                  heading(l.show),
                  SegmentedButton<ReportType>(
                    segments: [
                      ButtonSegment(value: ReportType.all, label: Text(l.all)),
                      ButtonSegment(
                          value: ReportType.expenses, label: Text(l.expenses)),
                      ButtonSegment(
                          value: ReportType.income, label: Text(l.income)),
                    ],
                    showSelectedIcon: false,
                    selected: {_type},
                    onSelectionChanged: _busy
                        ? null
                        : (s) => setState(() => _type = s.first),
                  ),
                  heading(l.categories),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilterChip(
                        label: Text(l.all),
                        selected: cats == null,
                        onSelected: _busy
                            ? null
                            : (_) => setState(() => _categories = null),
                      ),
                      for (final n in names)
                        FilterChip(
                          avatar: CircleAvatar(
                            backgroundColor: state.colorFor(
                                n,
                                state.categoryRecord(n, EntryType.expense) !=
                                        null
                                    ? EntryType.expense
                                    : EntryType.income),
                            radius: 6,
                          ),
                          label: Text(categoryLabel(l, n)),
                          selected: cats != null && cats.contains(n),
                          onSelected: _busy ? null : (_) => _toggleCategory(n),
                        ),
                    ],
                  ),
                  heading(l.sections),
                  sectionTile(ReportSection.summary, l.pdfSummary),
                  sectionTile(
                    ReportSection.categories,
                    _type == ReportType.income
                        ? l.pdfIncomeByCategory
                        : l.pdfExpensesByCategory,
                  ),
                  sectionTile(
                    ReportSection.budget,
                    l.navBudgets,
                    subtitle: wholeMonth ? null : l.budgetSectionHint,
                    enabled: wholeMonth && _type != ReportType.income,
                  ),
                  sectionTile(
                    ReportSection.months,
                    l.monthByMonth,
                    subtitle: spansMonths ? null : l.monthByMonthHint,
                    enabled: spansMonths,
                  ),
                  sectionTile(ReportSection.entries, l.allEntries,
                      subtitle: l.allEntriesHint),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.picture_as_pdf_outlined),
                  label: Text(_busy ? l.creatingPdf : l.createPdf),
                  onPressed: _busy || _sections.isEmpty ? null : _create,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
