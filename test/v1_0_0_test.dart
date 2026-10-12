import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:pockettally/app_state.dart';
import 'package:pockettally/backup.dart';
import 'package:pockettally/l10n/l10n.dart';
import 'package:pockettally/models.dart';
import 'package:pockettally/report_range.dart';
import 'package:pockettally/split.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('split bill', () {
    test('equal shares always add up to the total', () {
      expect(splitEqually(1000, 3), [334, 333, 333]);
      expect(splitEqually(1000, 3, unit: 100), [400, 300, 300]);
      expect(splitEqually(120000, 3, unit: 100), [40000, 40000, 40000]);
      expect(splitEqually(1050, 2, unit: 100), [550, 500]);
      expect(splitEqually(500, 0), isEmpty);
      for (final total in [1, 99, 100, 12345, 99999]) {
        for (final count in [1, 2, 3, 7]) {
          final shares = splitEqually(total, count);
          expect(shares.length, count);
          expect(shares.fold<int>(0, (a, b) => a + b), total);
        }
      }
    });

    test('custom shares must add up to the bill', () {
      const equal = SplitPlan(people: ['Rahul', 'Priya']);
      expect(equal.sharesFor(90000), [30000, 30000, 30000]);
      const custom = SplitPlan(
          people: ['Rahul', 'Priya'], equal: false, shares: [50000, 25000, 15000]);
      expect(custom.sharesFor(90000), [50000, 25000, 15000]);
      expect(custom.sharesFor(80000), isNull);
      const nobody = SplitPlan(people: []);
      expect(nobody.sharesFor(1000), isNull);
    });

    test('paid by me: the others owe me their shares', () {
      const plan = SplitPlan(people: ['Rahul', 'Priya']);
      final date = DateTime(2026, 10, 12);
      final debts = plan.debtsFor([400, 300, 300], date, 'Split bill: Dinner');
      expect(debts.length, 2);
      expect(debts.map((d) => d.person), ['Rahul', 'Priya']);
      expect(debts.every((d) => d.type == DebtType.lent), isTrue);
      expect(debts.every((d) => d.amountMinor == 300), isTrue);
      expect(debts.first.note, 'Split bill: Dinner');
      expect(debts.first.date, date);
      expect(SplitPlan.othersTotal([400, 300, 300]), 600);
    });

    test('paid by someone else: I owe the payer my share', () {
      const plan = SplitPlan(people: ['Rahul', 'Priya'], paidBy: 'Rahul');
      final debts = plan.debtsFor([400, 300, 300], DateTime(2026, 10, 12), 'x');
      expect(debts.length, 1);
      expect(debts.single.person, 'Rahul');
      expect(debts.single.type, DebtType.borrowed);
      expect(debts.single.amountMinor, 400);
    });

    test('nobody owes a zero share', () {
      const plan = SplitPlan(
          people: ['Rahul', 'Priya'], equal: false, shares: [1000, 0, 500]);
      final debts = plan.debtsFor([1000, 0, 500], DateTime(2026, 10, 12), 'x');
      expect(debts.single.person, 'Priya');
    });
  });

  group('lend & borrow reminders', () {
    test('the reminder survives the database map', () {
      final at = DateTime(2026, 10, 15, 10, 30);
      final d = Debt(
        person: 'Rahul',
        type: DebtType.lent,
        amountMinor: 50000,
        date: DateTime(2026, 10, 1),
        remindAt: at,
      );
      expect(Debt.fromMap(d.toMap()).remindAt, at);
      final none = d.copyWith(remindAt: () => null);
      expect(none.remindAt, isNull);
      expect(Debt.fromMap(none.toMap()).remindAt, isNull);
      // Other changes keep the reminder.
      expect(d.copyWith(paidMinor: 100).remindAt, at);
    });

    test('only open records with a time still to come have a reminder', () {
      final now = DateTime(2026, 10, 12, 12);
      final d = Debt(
        person: 'Rahul',
        type: DebtType.lent,
        amountMinor: 50000,
        date: DateTime(2026, 10, 1),
        remindAt: DateTime(2026, 10, 15, 10),
      );
      expect(d.hasUpcomingReminder(now), isTrue);
      expect(d.copyWith(paidMinor: 50000).hasUpcomingReminder(now), isFalse);
      expect(
          d
              .copyWith(remindAt: () => DateTime(2026, 10, 12, 9))
              .hasUpcomingReminder(now),
          isFalse);
      expect(d.copyWith(remindAt: () => null).hasUpcomingReminder(now), isFalse);
    });

    test('the reminder goes through a backup', () {
      final at = DateTime(2026, 10, 15, 10, 30);
      final b = BackupData(
        userName: 'A',
        currencyCode: 'INR',
        weekStartsOnSunday: false,
        monthlyBudgetMinor: 0,
        categories: const [],
        entries: const [],
        debts: [
          Debt(
            person: 'Rahul',
            type: DebtType.lent,
            amountMinor: 50000,
            date: DateTime(2026, 10, 1),
            remindAt: at,
          ),
          Debt(
            person: 'Priya',
            type: DebtType.borrowed,
            amountMinor: 1000,
            date: DateTime(2026, 10, 2),
          ),
        ],
      );
      final back = BackupData.fromJsonString(b.toJsonString());
      expect(back.debts.first.remindAt, at);
      expect(back.debts.last.remindAt, isNull);
    });

    test('reminder text and known people', () async {
      SharedPreferences.setMockInitialValues({});
      final state = AppState(await SharedPreferences.getInstance());
      state.debts = [
        Debt(
            person: 'Rahul',
            type: DebtType.lent,
            amountMinor: 50000,
            date: DateTime(2026, 10, 3),
            note: 'Dinner'),
        Debt(
            person: 'rahul ',
            type: DebtType.borrowed,
            amountMinor: 100,
            date: DateTime(2026, 10, 2)),
        Debt(
            person: 'Priya',
            type: DebtType.borrowed,
            amountMinor: 100,
            date: DateTime(2026, 10, 1)),
      ];
      expect(state.knownPeople, ['Rahul', 'Priya']);
      final l = lookupAppLocalizations(const Locale('en'));
      final text = state.debtReminderText(l, state.debts.first);
      expect(text, contains('Rahul'));
      expect(text, contains('500'));
      expect(text, endsWith('(Dinner)'));
    });

    test('every language has the new texts', () {
      for (final lang in kLanguages) {
        final l = lookupAppLocalizations(Locale(lang.code));
        expect(l.debtReminderLent('P1', 'A1'),
            allOf(contains('P1'), contains('A1')),
            reason: lang.code);
        expect(l.youOwePerson('P1', 'A1'), allOf(contains('P1'), contains('A1')),
            reason: lang.code);
        expect(l.splitSaved(3), contains('3'), reason: lang.code);
        expect(l.changeVsLastMonth('+5%'), contains('+5%'), reason: lang.code);
      }
    });
  });

  group('report periods', () {
    test('week, month and year around a day', () {
      // 14 Oct 2026 is a Wednesday.
      final wed = DateTime(2026, 10, 14, 18);
      expect(periodRange(ReportPeriod.week, wed),
          (DateTime(2026, 10, 12), DateTime(2026, 10, 19)));
      expect(periodRange(ReportPeriod.week, wed, weekStartsOnSunday: true),
          (DateTime(2026, 10, 11), DateTime(2026, 10, 18)));
      expect(periodRange(ReportPeriod.month, wed),
          (DateTime(2026, 10, 1), DateTime(2026, 11, 1)));
      expect(periodRange(ReportPeriod.year, wed),
          (DateTime(2026, 1, 1), DateTime(2027, 1, 1)));
    });

    test('a running period is compared with the same days before', () {
      final now = DateTime(2026, 10, 12, 15);
      expect(
          previousComparable(ReportPeriod.month, DateTime(2026, 10, 1),
              DateTime(2026, 11, 1), now),
          (DateTime(2026, 9, 1), DateTime(2026, 9, 13)));
      // A finished period is compared with the whole period before.
      expect(
          previousComparable(ReportPeriod.month, DateTime(2026, 9, 1),
              DateTime(2026, 10, 1), now),
          (DateTime(2026, 8, 1), DateTime(2026, 9, 1)));
      // Never more than the whole period before.
      expect(
          previousComparable(ReportPeriod.month, DateTime(2027, 3, 1),
              DateTime(2027, 4, 1), DateTime(2027, 3, 31, 9)),
          (DateTime(2027, 2, 1), DateTime(2027, 3, 1)));
      expect(
          previousComparable(ReportPeriod.year, DateTime(2026, 1, 1),
              DateTime(2027, 1, 1), now),
          (DateTime(2025, 1, 1), DateTime(2025, 10, 13)));
      expect(
          previousComparable(ReportPeriod.week, DateTime(2026, 10, 12),
              DateTime(2026, 10, 19), now),
          (DateTime(2026, 10, 5), DateTime(2026, 10, 6)));
    });

    test('the last few periods, oldest first', () {
      final months = lastPeriods(ReportPeriod.month, DateTime(2026, 10, 1), 6);
      expect(months.length, 6);
      expect(months.first, (DateTime(2026, 5, 1), DateTime(2026, 6, 1)));
      expect(months.last, (DateTime(2026, 10, 1), DateTime(2026, 11, 1)));
      expect(lastPeriods(ReportPeriod.week, DateTime(2026, 10, 12), 3), [
        (DateTime(2026, 9, 28), DateTime(2026, 10, 5)),
        (DateTime(2026, 10, 5), DateTime(2026, 10, 12)),
        (DateTime(2026, 10, 12), DateTime(2026, 10, 19)),
      ]);
    });

    test('change in percent', () {
      expect(percentChange(110, 100), 10);
      expect(percentChange(90, 100), -10);
      expect(percentChange(100, 100), 0);
      expect(percentChange(5, 0), isNull);
    });
  });
}
