import 'models.dart';

/// Money in the wallets at the end of each of the last [months] months
/// (oldest first), counting every entry up to that month's end on top of
/// the wallets' opening balances. Transfers move money between wallets, so
/// they never change the total.
List<int> monthEndTotals(
  List<Entry> entries,
  int openingTotal,
  DateTime now, {
  int months = 12,
}) {
  final result = <int>[];
  for (var i = months - 1; i >= 0; i--) {
    final end = DateTime(now.year, now.month - i + 1, 1);
    var sum = openingTotal;
    for (final e in entries) {
      if (e.date.isBefore(end)) {
        sum += e.isIncome ? e.amountMinor : -e.amountMinor;
      }
    }
    result.add(sum);
  }
  return result;
}

/// The first day of each of the last [months] months (oldest first), to
/// label [monthEndTotals].
List<DateTime> lastMonthStarts(DateTime now, {int months = 12}) => [
      for (var i = months - 1; i >= 0; i--)
        DateTime(now.year, now.month - i, 1),
    ];
