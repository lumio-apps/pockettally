/// The periods the Reports screen shows.
enum ReportPeriod { week, month, year }

/// Start (inclusive) and end (exclusive) of the [period] containing [day].
/// Weeks start on Monday, or on Sunday with [weekStartsOnSunday].
(DateTime, DateTime) periodRange(
  ReportPeriod period,
  DateTime day, {
  bool weekStartsOnSunday = false,
}) {
  final d = DateTime(day.year, day.month, day.day);
  switch (period) {
    case ReportPeriod.week:
      final back = weekStartsOnSunday ? d.weekday % 7 : d.weekday - 1;
      final start = DateTime(d.year, d.month, d.day - back);
      return (start, DateTime(start.year, start.month, start.day + 7));
    case ReportPeriod.month:
      return (DateTime(d.year, d.month, 1), DateTime(d.year, d.month + 1, 1));
    case ReportPeriod.year:
      return (DateTime(d.year, 1, 1), DateTime(d.year + 1, 1, 1));
  }
}

/// Start of the period before the one starting at [start].
DateTime previousStart(ReportPeriod period, DateTime start) {
  switch (period) {
    case ReportPeriod.week:
      return DateTime(start.year, start.month, start.day - 7);
    case ReportPeriod.month:
      return DateTime(start.year, start.month - 1, 1);
    case ReportPeriod.year:
      return DateTime(start.year - 1, 1, 1);
  }
}

/// The period before [start]..[end) to compare with. While the period is
/// still running ([now] is in it), only as many days of the period before
/// are used as have passed so far, so "this month so far" is compared with
/// the same days of last month.
(DateTime, DateTime) previousComparable(
  ReportPeriod period,
  DateTime start,
  DateTime end,
  DateTime now,
) {
  final prevStart = previousStart(period, start);
  final today = DateTime(now.year, now.month, now.day);
  if (today.isBefore(start) || !today.isBefore(end)) return (prevStart, start);
  // Counted on UTC dates, so a daylight saving change can't lose a day.
  final days = DateTime.utc(today.year, today.month, today.day)
          .difference(DateTime.utc(start.year, start.month, start.day))
          .inDays +
      1;
  final cut = DateTime(prevStart.year, prevStart.month, prevStart.day + days);
  return (prevStart, cut.isBefore(start) ? cut : start);
}

/// The [count] periods up to and including the one starting at [start],
/// oldest first.
List<(DateTime, DateTime)> lastPeriods(
    ReportPeriod period, DateTime start, int count) {
  final result = <(DateTime, DateTime)>[];
  for (var i = count - 1; i >= 0; i--) {
    final s = switch (period) {
      ReportPeriod.week => DateTime(start.year, start.month, start.day - 7 * i),
      ReportPeriod.month => DateTime(start.year, start.month - i, 1),
      ReportPeriod.year => DateTime(start.year - i, 1, 1),
    };
    final e = switch (period) {
      ReportPeriod.week => DateTime(s.year, s.month, s.day + 7),
      ReportPeriod.month => DateTime(s.year, s.month + 1, 1),
      ReportPeriod.year => DateTime(s.year + 1, 1, 1),
    };
    result.add((s, e));
  }
  return result;
}

/// Change from [before] to [now] in whole percent, or null when there is
/// nothing to compare with.
int? percentChange(int now, int before) {
  if (before <= 0) return null;
  return ((now - before) * 100 / before).round();
}
