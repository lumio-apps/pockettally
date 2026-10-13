import 'dart:convert';

import 'models.dart';

/// Which entries a PDF report shows.
enum ReportType { all, expenses, income }

/// The parts of a PDF report, in the order they appear.
enum ReportSection { summary, categories, budget, months, entries }

/// What the user chose for a PDF report.
class ReportOptions {
  const ReportOptions({
    required this.start,
    required this.end,
    this.type = ReportType.all,
    this.categories,
    this.sections = allSections,
  });

  static const Set<ReportSection> allSections = {
    ReportSection.summary,
    ReportSection.categories,
    ReportSection.budget,
    ReportSection.months,
    ReportSection.entries,
  };

  /// First day (inclusive) and the day after the last (exclusive).
  final DateTime start;
  final DateTime end;
  final ReportType type;

  /// Category names to include; null means all.
  final Set<String>? categories;
  final Set<ReportSection> sections;

  bool has(ReportSection s) => sections.contains(s);

  /// True when the period is exactly one calendar month.
  bool get isWholeMonth =>
      start.day == 1 && end == DateTime(start.year, start.month + 1, 1);

  /// True when the period reaches past the month it starts in.
  bool get spansMonths => end.isAfter(DateTime(start.year, start.month + 1, 1));

  bool includes(Entry e) {
    if (e.date.isBefore(start) || !e.date.isBefore(end)) return false;
    if (type == ReportType.expenses && e.isIncome) return false;
    if (type == ReportType.income && !e.isIncome) return false;
    final cats = categories;
    return cats == null || cats.contains(e.category);
  }

  /// The entries of the report, oldest first (same day: by time).
  List<Entry> pick(List<Entry> all) {
    final list = all.where(includes).toList()
      ..sort((a, b) {
        final d = a.date.compareTo(b.date);
        if (d != 0) return d;
        final t = (a.minutes ?? -1).compareTo(b.minutes ?? -1);
        return t != 0 ? t : (a.id ?? 0).compareTo(b.id ?? 0);
      });
    return list;
  }

  /// The months the period touches: (first day, day after the last),
  /// cut to the period.
  List<(DateTime, DateTime)> get months {
    final result = <(DateTime, DateTime)>[];
    var m = DateTime(start.year, start.month, 1);
    while (m.isBefore(end)) {
      final next = DateTime(m.year, m.month + 1, 1);
      result.add((m.isBefore(start) ? start : m, next.isAfter(end) ? end : next));
      m = next;
    }
    return result;
  }

  /// The parts that are remembered for next time (not the dates or the
  /// categories, which change with what is looked at).
  String rememberJson() => jsonEncode({
        'type': type.name,
        'sections': [for (final s in sections) s.name],
      });

  /// [json] from [rememberJson]; anything unreadable falls back to the
  /// defaults.
  static ReportOptions remembered(String? json,
      {required DateTime start, required DateTime end}) {
    var type = ReportType.all;
    var sections = allSections;
    try {
      final m = jsonDecode(json ?? '') as Map<String, dynamic>;
      type = ReportType.values.firstWhere((t) => t.name == m['type'],
          orElse: () => ReportType.all);
      final names = (m['sections'] as List<dynamic>).cast<String>();
      sections = {
        for (final s in ReportSection.values)
          if (names.contains(s.name)) s,
      };
    } catch (_) {
      // Nothing saved yet.
    }
    return ReportOptions(start: start, end: end, type: type, sections: sections);
  }
}
