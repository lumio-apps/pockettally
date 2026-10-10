import 'package:flutter_test/flutter_test.dart';
import 'package:pockettally/backup.dart';
import 'package:pockettally/models.dart';

void main() {
  test('Debt remaining and settled', () {
    final d = Debt(
      person: 'Aman',
      type: DebtType.lent,
      amountMinor: 100000,
      paidMinor: 40000,
      date: DateTime(2026, 10, 1),
    );
    expect(d.remainingMinor, 60000);
    expect(d.isSettled, isFalse);
    final done = d.copyWith(paidMinor: 100000);
    expect(done.remainingMinor, 0);
    expect(done.isSettled, isTrue);
  });

  test('Debt and goal survive a database map round trip', () {
    final d = Debt(
      id: 4,
      person: 'Aman',
      type: DebtType.borrowed,
      amountMinor: 250000,
      paidMinor: 50000,
      date: DateTime(2026, 9, 30),
      note: 'Rent help',
    );
    final d2 = Debt.fromMap(d.toMap());
    expect(d2.person, 'Aman');
    expect(d2.type, DebtType.borrowed);
    expect(d2.paidMinor, 50000);
    expect(d2.date, DateTime(2026, 9, 30));

    const g = SavingsGoal(
        id: 2, name: 'Phone', targetMinor: 2000000, savedMinor: 500000, colorValue: 0xFF64B5F6);
    final g2 = SavingsGoal.fromMap(g.toMap());
    expect(g2.name, 'Phone');
    expect(g2.progress, closeTo(0.25, 0.0001));
    expect(g2.isReached, isFalse);
  });

  test('Backup keeps debts and goals', () {
    final b = BackupData(
      userName: 'Riya',
      currencyCode: 'INR',
      weekStartsOnSunday: false,
      monthlyBudgetMinor: 0,
      categories: const [],
      entries: const [],
      debts: [
        Debt(
          person: 'Aman',
          type: DebtType.lent,
          amountMinor: 100000,
          paidMinor: 20000,
          date: DateTime(2026, 10, 2),
        ),
      ],
      goals: const [
        SavingsGoal(
            name: 'Trip', targetMinor: 5000000, savedMinor: 100000, colorValue: 0xFFFFB74D),
      ],
    );
    final copy = BackupData.fromJsonString(b.toJsonString());
    expect(copy.debts.single.person, 'Aman');
    expect(copy.debts.single.paidMinor, 20000);
    expect(copy.goals.single.name, 'Trip');
    expect(copy.goals.single.savedMinor, 100000);
  });

  test('Old backups without debts and goals still load', () {
    const old = '{"app":"PocketTally","format":1,"settings":{},"categories":[],"entries":[]}';
    final b = BackupData.fromJsonString(old);
    expect(b.debts, isEmpty);
    expect(b.goals, isEmpty);
  });
}
