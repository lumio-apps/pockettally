import 'package:flutter_test/flutter_test.dart';
import 'package:pockettally/app_state.dart';
import 'package:pockettally/backup.dart';
import 'package:pockettally/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('bill photos go through a backup, with their entries', () {
    final b = BackupData(
      userName: 'A',
      currencyCode: 'INR',
      weekStartsOnSunday: false,
      monthlyBudgetMinor: 0,
      categories: const [],
      entries: [
        Entry(
            type: EntryType.expense,
            amountMinor: 500,
            category: 'Food',
            date: DateTime(2026, 10, 1),
            photo: 'bill_1.jpg'),
        Entry(
            type: EntryType.expense,
            amountMinor: 700,
            category: 'Food',
            date: DateTime(2026, 10, 2),
            photo: 'bill_gone.jpg'),
      ],
      photos: {
        'bill_1.jpg': [1, 2, 3, 255],
      },
    );
    final back = BackupData.fromJsonString(b.toJsonString());
    expect(back.photos['bill_1.jpg'], [1, 2, 3, 255]);
    expect(back.entries.first.photo, 'bill_1.jpg');
    // A photo that was not packed is not referenced.
    expect(back.entries.last.photo, isNull);
  });

  test('photo names with a path are refused', () {
    final text = BackupData(
      userName: 'A',
      currencyCode: 'INR',
      weekStartsOnSunday: false,
      monthlyBudgetMinor: 0,
      categories: const [],
      entries: const [],
      photos: {'ok.jpg': [1]},
    ).toJsonString().replaceFirst('"ok.jpg"', '"../evil.jpg"');
    expect(BackupData.fromJsonString(text).photos, isEmpty);
  });

  test('unused monthly budget carries over one month', () async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState(await SharedPreferences.getInstance());
    await state.setMonthlyBudget(30000);
    state.entries = [
      Entry(
          type: EntryType.expense,
          amountMinor: 25800,
          category: 'Food',
          date: DateTime(2026, 9, 10)),
    ];
    final oct = DateTime(2026, 10, 5);
    expect(state.carriedOverInto(oct), 0); // off by default
    await state.setBudgetRollover(true);
    expect(state.carriedOverInto(oct), 4200);
    expect(state.monthlyLimitFor(oct), 34200);
    // No entries in August: nothing to carry into September.
    expect(state.carriedOverInto(DateTime(2026, 9, 1)), 0);
  });
}
