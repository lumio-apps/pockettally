import 'package:flutter_test/flutter_test.dart';
import 'package:pockettally/backup.dart';
import 'package:pockettally/models.dart';

Subscription sub({
  RepeatEvery every = RepeatEvery.monthly,
  int amount = 1200,
  DateTime? next,
  int remind = 1,
}) {
  final d = next ?? DateTime(2026, 10, 31);
  return Subscription(
    name: 'Netflix',
    amountMinor: amount,
    every: every,
    nextDate: d,
    anchorDay: d.day,
    remindDays: remind,
  );
}

void main() {
  test('Monthly cost of each kind of subscription', () {
    expect(sub().monthlyMinor, 1200);
    expect(sub(every: RepeatEvery.yearly, amount: 12000).monthlyMinor, 1000);
    expect(sub(every: RepeatEvery.weekly, amount: 1200).monthlyMinor, 5200);
    expect(sub().yearlyMinor, 14400);
  });

  test('Paying moves the due date on and never into the past', () {
    final s = sub(next: DateTime(2026, 1, 31));
    expect(s.nextAfterPaying(DateTime(2026, 1, 31)), DateTime(2026, 2, 28));
    // Very late: lands on the first due date from today on.
    expect(s.nextAfterPaying(DateTime(2026, 5, 10)), DateTime(2026, 5, 31));
  });

  test('Reminder time and days until due', () {
    final s = sub(next: DateTime(2026, 10, 20), remind: 3);
    expect(s.remindAt, DateTime(2026, 10, 17, 9));
    expect(sub(remind: -1).remindAt, isNull);
    expect(s.daysUntilDue(DateTime(2026, 10, 18, 15)), 2);
    expect(s.daysUntilDue(DateTime(2026, 10, 22)), -2);
  });

  test('Subscription survives the database map and the backup', () {
    final s = sub(every: RepeatEvery.yearly);
    final back = Subscription.fromMap({...s.toMap(), 'id': 4});
    expect(back.every, RepeatEvery.yearly);
    expect(back.id, 4);
    final b = BackupData.fromJsonString(BackupData(
      userName: 'A',
      currencyCode: 'INR',
      weekStartsOnSunday: false,
      monthlyBudgetMinor: 0,
      categories: const [],
      entries: const [],
      subscriptions: [s],
    ).toJsonString());
    expect(b.subscriptions.single.name, 'Netflix');
    expect(b.subscriptions.single.remindDays, 1);
  });
}
