import 'package:flutter_test/flutter_test.dart';
import 'package:pockettally/backup.dart';
import 'package:pockettally/models.dart';
import 'package:pockettally/utils/amount_parser.dart';

void main() {
  group('evaluateAmount', () {
    test('plain numbers', () {
      expect(evaluateAmount('120'), 120);
      expect(evaluateAmount('12.5'), 12.5);
      expect(evaluateAmount('12,5'), 12.5);
      expect(evaluateAmount('1,500'), 1500);
      expect(evaluateAmount('1,234,567'), 1234567);
    });

    test('math', () {
      expect(evaluateAmount('120+45'), 165);
      expect(evaluateAmount('100-30'), 70);
      expect(evaluateAmount('3×40'), 120);
      expect(evaluateAmount('3*40'), 120);
      expect(evaluateAmount('90÷3'), 30);
      expect(evaluateAmount('10+2*3'), 16);
      expect(evaluateAmount('(10+2)*3'), 36);
      expect(evaluateAmount('1,500/2'), 750);
    });

    test('invalid input', () {
      expect(evaluateAmount(''), isNull);
      expect(evaluateAmount('12+'), isNull);
      expect(evaluateAmount('5/0'), isNull);
      expect(evaluateAmount('(1+2'), isNull);
      expect(evaluateAmount('1..2'), isNull);
    });

    test('isCalculation', () {
      expect(isCalculation('120'), isFalse);
      expect(isCalculation('120+45'), isTrue);
      expect(isCalculation('3×4'), isTrue);
    });
  });

  test('Armenian Dram is available', () {
    expect(currencyByCode('AMD').symbol, '֏');
  });

  test('Backup survives a JSON round trip', () {
    final backup = BackupData(
      userName: 'Riya',
      currencyCode: 'AMD',
      weekStartsOnSunday: true,
      monthlyBudgetMinor: 5000000,
      categories: const [
        EntryCategory(
            name: 'Food',
            type: EntryType.expense,
            colorValue: 0xFFFFB74D,
            budgetMinor: 1000000),
        EntryCategory(
            name: 'Salary', type: EntryType.income, colorValue: 0xFF81C784),
      ],
      entries: [
        Entry(
          type: EntryType.expense,
          amountMinor: 32000,
          category: 'Food',
          date: DateTime(2026, 10, 9),
          note: 'Lunch',
        ),
        Entry(
          type: EntryType.income,
          amountMinor: 140000,
          category: 'Salary',
          date: DateTime(2026, 10, 1),
          period: IncomePeriod.daily,
        ),
      ],
    );

    final copy = BackupData.fromJsonString(backup.toJsonString());

    expect(copy.userName, 'Riya');
    expect(copy.currencyCode, 'AMD');
    expect(copy.weekStartsOnSunday, isTrue);
    expect(copy.monthlyBudgetMinor, 5000000);
    expect(copy.categories.length, 2);
    expect(copy.categories.first.budgetMinor, 1000000);
    expect(copy.categories.last.budgetMinor, isNull);
    expect(copy.entries.length, 2);
    expect(copy.entries.first.date, DateTime(2026, 10, 9));
    expect(copy.entries.first.note, 'Lunch');
    expect(copy.entries.last.period, IncomePeriod.daily);
  });

  test('A random file is rejected', () {
    expect(() => BackupData.fromJsonString('hello'),
        throwsA(isA<FormatException>()));
    expect(() => BackupData.fromJsonString('{"app":"Other"}'),
        throwsA(isA<FormatException>()));
  });
}
