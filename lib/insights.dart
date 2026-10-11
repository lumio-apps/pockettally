import 'models.dart';

enum InsightKind {
  /// Spent [percent] % less than last month.
  spentLess,

  /// Spent [percent] % more than last month.
  spentMore,

  /// Most money went to [category]: [amountMinor], [percent] % of spending.
  topCategory,

  /// [category] went up by [amountMinor] compared with last month.
  categoryUp,

  /// Average spending per day: [amountMinor].
  dailyAverage,

  /// Kept [percent] % of the income.
  savedShare,

  /// Spent [amountMinor] more than the income.
  overspent,
}

class Insight {
  const Insight(this.kind, {this.category, this.amountMinor = 0, this.percent = 0});

  final InsightKind kind;
  final String? category;
  final int amountMinor;
  final int percent;

  @override
  String toString() => 'Insight($kind, $category, $amountMinor, $percent)';
}

/// Short, plain observations about [month], compared with the month
/// before. For the current month only the days so far are compared with
/// the same days of last month, so the comparison is fair.
List<Insight> monthInsights(List<Entry> all, DateTime month, DateTime now) {
  final start = DateTime(month.year, month.month, 1);
  final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
  final isCurrent = month.year == now.year && month.month == now.month;
  final days = isCurrent ? now.day : daysInMonth;
  final end = DateTime(month.year, month.month, days + 1);

  final prevStart = DateTime(month.year, month.month - 1, 1);
  final prevDays = DateTime(month.year, month.month, 0).day;
  final prevEnd = DateTime(prevStart.year, prevStart.month,
      (days < prevDays ? days : prevDays) + 1);

  bool inRange(Entry e, DateTime a, DateTime b) =>
      !e.date.isBefore(a) && e.date.isBefore(b);
  final current = all.where((e) => inRange(e, start, end)).toList();
  final previous = all.where((e) => inRange(e, prevStart, prevEnd)).toList();

  Map<String, int> byCategory(Iterable<Entry> list) {
    final m = <String, int>{};
    for (final e in list.where((e) => !e.isIncome)) {
      m[e.category] = (m[e.category] ?? 0) + e.amountMinor;
    }
    return m;
  }

  final spent = current
      .where((e) => !e.isIncome)
      .fold<int>(0, (s, e) => s + e.amountMinor);
  final earned = current
      .where((e) => e.isIncome)
      .fold<int>(0, (s, e) => s + e.amountMinor);
  final spentBefore = previous
      .where((e) => !e.isIncome)
      .fold<int>(0, (s, e) => s + e.amountMinor);

  final result = <Insight>[];

  if (spent > 0 && spentBefore > 0) {
    final change = ((spent - spentBefore) * 100 / spentBefore).round();
    if (change <= -5) {
      result.add(Insight(InsightKind.spentLess, percent: -change));
    } else if (change >= 5) {
      result.add(Insight(InsightKind.spentMore, percent: change));
    }
  }

  final cats = byCategory(current);
  if (cats.isNotEmpty) {
    final top = cats.entries.reduce((a, b) => a.value >= b.value ? a : b);
    result.add(Insight(
      InsightKind.topCategory,
      category: top.key,
      amountMinor: top.value,
      percent: (top.value * 100 / spent).round(),
    ));

    // The category that grew most, if the rise is noticeable.
    final before = byCategory(previous);
    MapEntry<String, int>? rise;
    for (final c in cats.entries) {
      final up = c.value - (before[c.key] ?? 0);
      if (before.containsKey(c.key) && up > 0 && (rise == null || up > rise.value)) {
        rise = MapEntry(c.key, up);
      }
    }
    if (rise != null && rise.value * 10 >= spent) {
      result.add(Insight(InsightKind.categoryUp,
          category: rise.key, amountMinor: rise.value));
    }
  }

  if (spent > 0) {
    result.add(Insight(InsightKind.dailyAverage,
        amountMinor: (spent / days).round()));
  }

  if (earned > 0) {
    if (earned >= spent) {
      result.add(Insight(InsightKind.savedShare,
          percent: ((earned - spent) * 100 / earned).round()));
    } else {
      result.add(Insight(InsightKind.overspent, amountMinor: spent - earned));
    }
  }
  return result;
}

/// How much a recurring rule costs (or brings in) per month, roughly.
int monthlyAmount(RecurringRule r) {
  switch (r.every) {
    case RepeatEvery.daily:
      return (r.amountMinor * 365 / 12).round();
    case RepeatEvery.weekly:
      return (r.amountMinor * 52 / 12).round();
    case RepeatEvery.monthly:
      return r.amountMinor;
    case RepeatEvery.yearly:
      return (r.amountMinor / 12).round();
  }
}
