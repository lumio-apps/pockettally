import 'package:flutter_test/flutter_test.dart';
import 'package:pockettally/app_state.dart';
import 'package:pockettally/models.dart';

void main() {
  test('Entry survives a database map round trip', () {
    final entry = Entry(
      id: 7,
      type: EntryType.income,
      amountMinor: 123456,
      category: 'Salary',
      date: DateTime(2026, 10, 7),
      note: 'October pay',
      period: IncomePeriod.monthly,
    );

    final copy = Entry.fromMap(entry.toMap());

    expect(copy.id, 7);
    expect(copy.type, EntryType.income);
    expect(copy.amountMinor, 123456);
    expect(copy.category, 'Salary');
    expect(copy.date, DateTime(2026, 10, 7));
    expect(copy.note, 'October pay');
    expect(copy.period, IncomePeriod.monthly);
  });

  test('Category survives a database map round trip', () {
    const c = EntryCategory(
      id: 3,
      name: 'Coffee',
      type: EntryType.expense,
      colorValue: 0xFFFFB74D,
    );
    final copy = EntryCategory.fromMap(c.toMap());
    expect(copy.id, 3);
    expect(copy.name, 'Coffee');
    expect(copy.type, EntryType.expense);
    expect(copy.colorValue, 0xFFFFB74D);
    expect(copy.isOther, isFalse);
  });

  test('Both default category lists contain "Other"', () {
    expect(kDefaultExpenseCategories.map((c) => c.$1), contains(kOtherCategory));
    expect(kDefaultIncomeCategories.map((c) => c.$1), contains(kOtherCategory));
  });

  test('Income and expense sums', () {
    final list = [
      Entry(
          type: EntryType.income,
          amountMinor: 50000,
          category: 'Salary',
          date: DateTime(2026, 10, 1)),
      Entry(
          type: EntryType.expense,
          amountMinor: 1250,
          category: 'Food',
          date: DateTime(2026, 10, 2)),
      Entry(
          type: EntryType.expense,
          amountMinor: 750,
          category: 'Travel',
          date: DateTime(2026, 10, 3)),
    ];
    expect(AppState.sumIncome(list), 50000);
    expect(AppState.sumExpense(list), 2000);
  });

  test('Unknown currency code falls back to the first currency', () {
    expect(currencyByCode('XXX').code, kCurrencies.first.code);
    expect(currencyByCode('USD').symbol, r'$');
  });
}
