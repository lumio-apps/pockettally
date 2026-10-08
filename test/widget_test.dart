import 'package:pockettally/models.dart';
import 'package:flutter_test/flutter_test.dart';

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

  test('Unknown currency code falls back to the first currency', () {
    expect(currencyByCode('XXX').code, kCurrencies.first.code);
    expect(currencyByCode('USD').symbol, r'$');
  });
}
