import 'package:flutter_test/flutter_test.dart';
import 'package:pockettally/app_state.dart';
import 'package:pockettally/models.dart';
import 'package:pockettally/pdf_text.dart';
import 'package:pockettally/report_options.dart';
import 'package:pockettally/report_pdf.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Entry entry(EntryType type, int amount, String category, DateTime date,
          {int id = 0}) =>
      Entry(
          id: id,
          type: type,
          amountMinor: amount,
          category: category,
          date: date);

  test('scripts the PDF font cannot write are drawn as pictures', () {
    expect(needsPicture('Food 120.50 · INR'), isFalse);
    expect(needsPicture('Метро'), isFalse);
    expect(needsPicture('Ծախս'), isFalse);
    expect(needsPicture('Café – €'), isFalse);
    expect(needsPicture('दूध'), isTrue);
    expect(needsPicture('খরচ'), isTrue);
    expect(needsPicture('مصروف'), isTrue);
    expect(needsPicture('支出'), isTrue);
    expect(needsPicture('Food 🍕'), isTrue);
  });

  test('options pick the right entries', () {
    final all = [
      entry(EntryType.expense, 100, 'Food', DateTime(2026, 10, 3), id: 1),
      entry(EntryType.expense, 200, 'Rent', DateTime(2026, 10, 1), id: 2),
      entry(EntryType.income, 900, 'Salary', DateTime(2026, 10, 1), id: 3),
      entry(EntryType.expense, 50, 'Food', DateTime(2026, 11, 1), id: 4),
    ];
    final october = ReportOptions(
        start: DateTime(2026, 10, 1), end: DateTime(2026, 11, 1));
    expect(october.pick(all).map((e) => e.id), [2, 3, 1]);
    final food = ReportOptions(
      start: DateTime(2026, 10, 1),
      end: DateTime(2026, 11, 1),
      type: ReportType.expenses,
      categories: {'Food'},
    );
    expect(food.pick(all).map((e) => e.id), [1]);
    final income = ReportOptions(
      start: DateTime(2026, 10, 1),
      end: DateTime(2026, 12, 1),
      type: ReportType.income,
    );
    expect(income.pick(all).map((e) => e.id), [3]);
  });

  test('months of a period, whole month and longer periods', () {
    final october = ReportOptions(
        start: DateTime(2026, 10, 1), end: DateTime(2026, 11, 1));
    expect(october.isWholeMonth, isTrue);
    expect(october.spansMonths, isFalse);
    expect(october.months, [(DateTime(2026, 10, 1), DateTime(2026, 11, 1))]);
    final custom = ReportOptions(
        start: DateTime(2026, 9, 15), end: DateTime(2026, 11, 11));
    expect(custom.isWholeMonth, isFalse);
    expect(custom.spansMonths, isTrue);
    expect(custom.months, [
      (DateTime(2026, 9, 15), DateTime(2026, 10, 1)),
      (DateTime(2026, 10, 1), DateTime(2026, 11, 1)),
      (DateTime(2026, 11, 1), DateTime(2026, 11, 11)),
    ]);
    final year =
        ReportOptions(start: DateTime(2026, 1, 1), end: DateTime(2027, 1, 1));
    expect(year.months.length, 12);
  });

  test('the type and sections are remembered', () {
    final options = ReportOptions(
      start: DateTime(2026, 10, 1),
      end: DateTime(2026, 11, 1),
      type: ReportType.income,
      sections: const {ReportSection.summary, ReportSection.entries},
    );
    final back = ReportOptions.remembered(options.rememberJson(),
        start: DateTime(2026, 1, 1), end: DateTime(2027, 1, 1));
    expect(back.type, ReportType.income);
    expect(back.sections, {ReportSection.summary, ReportSection.entries});
    expect(back.start, DateTime(2026, 1, 1));
    final fresh = ReportOptions.remembered(null,
        start: DateTime(2026, 1, 1), end: DateTime(2027, 1, 1));
    expect(fresh.type, ReportType.all);
    expect(fresh.sections, ReportOptions.allSections);
  });

  test('a yearly PDF with every section is made', () async {
    SharedPreferences.setMockInitialValues({
      'user_name': 'Riya',
      'currency': 'EUR',
    });
    final state = AppState(await SharedPreferences.getInstance());
    state.entries = [
      for (var m = 1; m <= 12; m++) ...[
        entry(EntryType.income, 300000, 'Salary', DateTime(2026, m, 1),
            id: m * 2),
        entry(EntryType.expense, 12000 + m * 100, 'Food', DateTime(2026, m, 5),
            id: m * 2 + 1),
      ],
    ];
    final bytes = await ReportPdf.build(
      state: state,
      options:
          ReportOptions(start: DateTime(2026, 1, 1), end: DateTime(2027, 1, 1)),
      periodLabel: '2026',
    );
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    expect(bytes.length, greaterThan(2000));
  });
}
