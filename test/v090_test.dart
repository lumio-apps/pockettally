import 'package:flutter_test/flutter_test.dart';
import 'package:pockettally/csv_io.dart';
import 'package:pockettally/insights.dart';
import 'package:pockettally/models.dart';

Entry _e(EntryType t, int minor, String cat, DateTime d,
        {String note = '', List<String> tags = const []}) =>
    Entry(type: t, amountMinor: minor, category: cat, date: d, note: note, tags: tags);

void main() {
  group('month insights', () {
    final entries = [
      // September: 200 food, 100 travel, income 1000
      _e(EntryType.expense, 20000, 'Food', DateTime(2026, 9, 5)),
      _e(EntryType.expense, 10000, 'Travel', DateTime(2026, 9, 6)),
      _e(EntryType.income, 100000, 'Salary', DateTime(2026, 9, 1)),
      // October: 150 food, 60 travel, income 1000
      _e(EntryType.expense, 15000, 'Food', DateTime(2026, 10, 5)),
      _e(EntryType.expense, 6000, 'Travel', DateTime(2026, 10, 6)),
      _e(EntryType.income, 100000, 'Salary', DateTime(2026, 10, 1)),
    ];

    test('a finished month compared with the one before', () {
      final list = monthInsights(entries, DateTime(2026, 10), DateTime(2026, 11, 15));
      final kinds = list.map((i) => i.kind).toList();
      expect(kinds.first, InsightKind.spentLess);
      expect(list.first.percent, 30); // 210 vs 300
      final top = list.firstWhere((i) => i.kind == InsightKind.topCategory);
      expect(top.category, 'Food');
      expect(top.percent, 71);
      expect(kinds, isNot(contains(InsightKind.categoryUp)));
      final avg = list.firstWhere((i) => i.kind == InsightKind.dailyAverage);
      expect(avg.amountMinor, (21000 / 31).round());
      final saved = list.firstWhere((i) => i.kind == InsightKind.savedShare);
      expect(saved.percent, 79);
    });

    test('the current month only counts the days so far', () {
      final list = monthInsights(entries, DateTime(2026, 10), DateTime(2026, 10, 5));
      // Up to 5 Oct: 150 spent; up to 5 Sep: 200 spent.
      expect(list.first.kind, InsightKind.spentLess);
      expect(list.first.percent, 25);
      final avg = list.firstWhere((i) => i.kind == InsightKind.dailyAverage);
      expect(avg.amountMinor, 3000);
    });

    test('spending more than earning', () {
      final list = monthInsights([
        _e(EntryType.income, 1000, 'Gift', DateTime(2026, 10, 1)),
        _e(EntryType.expense, 3000, 'Food', DateTime(2026, 10, 2)),
      ], DateTime(2026, 10), DateTime(2026, 11, 1));
      final over = list.firstWhere((i) => i.kind == InsightKind.overspent);
      expect(over.amountMinor, 2000);
    });

    test('nothing to say about an empty month', () {
      expect(monthInsights(const [], DateTime(2026, 10), DateTime(2026, 11)), isEmpty);
    });
  });

  test('monthly cost of repeating entries', () {
    RecurringRule r(RepeatEvery every, int minor) => RecurringRule(
        type: EntryType.expense,
        amountMinor: minor,
        category: 'Bills',
        every: every,
        anchorDay: 1,
        nextDate: DateTime(2026, 11, 1));
    expect(monthlyAmount(r(RepeatEvery.monthly, 1500)), 1500);
    expect(monthlyAmount(r(RepeatEvery.yearly, 12000)), 1000);
    expect(monthlyAmount(r(RepeatEvery.weekly, 1200)), 5200);
  });

  group('CSV', () {
    test('export then import gives the same entries', () {
      final list = [
        _e(EntryType.expense, 1250, 'Food', DateTime(2026, 10, 3),
            note: 'Lunch, with "Sam"', tags: ['work', 'trip']),
        Entry(
            type: EntryType.income,
            amountMinor: 300000,
            category: 'Salary',
            date: DateTime(2026, 10, 1),
            period: IncomePeriod.monthly),
        _e(EntryType.expense, 500, 'Other', DateTime(2026, 10, 4), note: '=SUM(A1)'),
      ];
      final csv = CsvIo.export(list);
      expect(csv, startsWith('date,type,category,amount,note,tags,period\r\n'));
      expect(csv, contains('2026-10-03,expense,Food,12.50,"Lunch, with ""Sam""",work;trip,'));
      expect(csv, contains("'=SUM(A1)"));

      final back = CsvIo.parse(csv);
      expect(back.skipped, 0);
      expect(back.entries.length, 3);
      final salary = back.entries.firstWhere((e) => e.isIncome);
      expect(salary.amountMinor, 300000);
      expect(salary.period, IncomePeriod.monthly);
      final food = back.entries.firstWhere((e) => e.category == 'Food');
      expect(food.note, 'Lunch, with "Sam"');
      expect(food.tags, ['work', 'trip']);
      expect(back.entries.firstWhere((e) => e.category == 'Other').note, '=SUM(A1)');
    });

    test('other column orders, decimal commas and bad rows', () {
      const text = 'Amount;x\n'; // not a usable header
      expect(() => CsvIo.parse(text), throwsFormatException);
      final r = CsvIo.parse('type,date,amount,category\n'
          'expense,2026-10-01,"1.234,50",Rent\n'
          'income,2026-10-02,99,\n'
          'transfer,2026-10-03,5,X\n'
          'expense,not a date,5,X\n');
      expect(r.entries.length, 2);
      expect(r.skipped, 2);
      expect(r.entries.first.amountMinor, 123450);
      expect(r.entries.last.category, kOtherCategory);
    });
  });
}
