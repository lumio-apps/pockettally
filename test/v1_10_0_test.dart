import 'package:flutter_test/flutter_test.dart';
import 'package:pockettally/models.dart';
import 'package:pockettally/net_worth.dart';
import 'package:pockettally/year_review.dart';

Entry e(EntryType t, int amount, DateTime d, {String cat = 'Food'}) =>
    Entry(type: t, amountMinor: amount, category: cat, date: d);

void main() {
  final entries = [
    e(EntryType.income, 100000, DateTime(2026, 1, 5), cat: 'Salary'),
    e(EntryType.expense, 20000, DateTime(2026, 1, 9), cat: 'Rent'),
    e(EntryType.expense, 5000, DateTime(2026, 1, 9)),
    e(EntryType.income, 100000, DateTime(2026, 2, 5), cat: 'Salary'),
    e(EntryType.expense, 90000, DateTime(2026, 2, 20), cat: 'Rent'),
    e(EntryType.expense, 1000, DateTime(2025, 12, 31)),
  ];

  test('Month-end totals add entries to the opening balances', () {
    final totals =
        monthEndTotals(entries, 10000, DateTime(2026, 2, 15), months: 3);
    // End of Dec 2025, Jan 2026, Feb 2026.
    expect(totals, [9000, 9000 + 75000, 9000 + 75000 + 10000]);
    expect(lastMonthStarts(DateTime(2026, 2, 15), months: 3).first,
        DateTime(2025, 12, 1));
  });

  test('Year in review numbers', () {
    final r = YearReview.compute(entries, 2026, DateTime(2026, 2, 28));
    expect(r.income, 200000);
    expect(r.expense, 115000);
    expect(r.saved, 85000);
    expect(r.entryCount, 5);
    expect(r.biggestExpense!.amountMinor, 90000);
    expect(r.topCategory, 'Rent');
    expect(r.topCategoryMinor, 110000);
    expect(r.topCategoryPercent, 96);
    expect(r.bestSavingMonth, 1);
    expect(r.costliestMonth, 2);
    // 59 days so far (Jan 1 to Feb 28); spending on 2 different days.
    expect(r.noSpendDays, 57);
    expect(r.avgDailyExpenseMinor, (115000 / 59).round());
  });

  test('An empty year and the list of years', () {
    final r = YearReview.compute(entries, 2024, DateTime(2026, 2, 28));
    expect(r.isEmpty, isTrue);
    expect(r.biggestExpense, isNull);
    expect(YearReview.yearsWithEntries(entries, DateTime(2026, 2, 28)),
        [2026, 2025]);
  });
}
