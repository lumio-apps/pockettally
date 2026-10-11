import 'package:flutter_test/flutter_test.dart';
import 'package:pockettally/backup.dart';
import 'package:pockettally/models.dart';

void main() {
  test('tags are cleaned up', () {
    expect(parseTags('Trip, #office  food,trip'), ['trip', 'office', 'food']);
    expect(parseTags('  '), isEmpty);
  });

  test('entry keeps its tags through the database map', () {
    final e = Entry(
      id: 1,
      type: EntryType.expense,
      amountMinor: 500,
      category: 'Food',
      date: DateTime(2026, 10, 1),
      tags: const ['trip', 'family'],
    );
    expect(Entry.fromMap(e.toMap()).tags, ['trip', 'family']);
    final old = e.toMap()..remove('tags'); // rows from before 0.8.0
    expect(Entry.fromMap(old).tags, isEmpty);
  });

  group('next repeat date', () {
    test('daily and weekly', () {
      expect(nextRepeatDate(DateTime(2026, 12, 31), RepeatEvery.daily, 31),
          DateTime(2027, 1, 1));
      expect(nextRepeatDate(DateTime(2026, 10, 28), RepeatEvery.weekly, 28),
          DateTime(2026, 11, 4));
    });

    test('monthly keeps the day, shorter months use their last day', () {
      final jan31 = DateTime(2026, 1, 31);
      final feb = nextRepeatDate(jan31, RepeatEvery.monthly, 31);
      expect(feb, DateTime(2026, 2, 28));
      final mar = nextRepeatDate(feb, RepeatEvery.monthly, 31);
      expect(mar, DateTime(2026, 3, 31));
      expect(nextRepeatDate(DateTime(2026, 12, 15), RepeatEvery.monthly, 15),
          DateTime(2027, 1, 15));
    });

    test('yearly on 29 February', () {
      expect(nextRepeatDate(DateTime(2028, 2, 29), RepeatEvery.yearly, 29),
          DateTime(2029, 2, 28));
    });
  });

  test('recurring rule from an entry starts one step later', () {
    final e = Entry(
      type: EntryType.income,
      amountMinor: 300000,
      category: 'Salary',
      date: DateTime(2026, 10, 1),
      period: IncomePeriod.monthly,
    );
    final r = RecurringRule.fromEntry(e, RepeatEvery.monthly);
    expect(r.nextDate, DateTime(2026, 11, 1));
    expect(r.anchorDay, 1);
    final copy = RecurringRule.fromMap(r.toMap());
    expect(copy.every, RepeatEvery.monthly);
    expect(copy.period, IncomePeriod.monthly);
    expect(copy.entryOn(DateTime(2026, 11, 1)).amountMinor, 300000);
  });

  test('backup keeps recurring entries, favorites and tags', () {
    final b = BackupData(
      userName: 'Alex',
      currencyCode: 'USD',
      weekStartsOnSunday: false,
      monthlyBudgetMinor: 0,
      categories: const [],
      entries: [
        Entry(
          type: EntryType.expense,
          amountMinor: 450,
          category: 'Food',
          date: DateTime(2026, 10, 3),
          tags: const ['coffee'],
        ),
      ],
      recurring: [
        RecurringRule(
          type: EntryType.expense,
          amountMinor: 90000,
          category: 'Rent',
          every: RepeatEvery.monthly,
          anchorDay: 5,
          nextDate: DateTime(2026, 11, 5),
          paused: true,
        ),
      ],
      favorites: const [
        Favorite(
            type: EntryType.expense,
            amountMinor: 350,
            category: 'Food',
            note: 'Coffee'),
      ],
    );
    final copy = BackupData.fromJsonString(b.toJsonString());
    expect(copy.entries.single.tags, ['coffee']);
    expect(copy.recurring.single.nextDate, DateTime(2026, 11, 5));
    expect(copy.recurring.single.paused, isTrue);
    expect(copy.favorites.single.note, 'Coffee');
  });
}
