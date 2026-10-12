import 'package:flutter_test/flutter_test.dart';
import 'package:pockettally/app_state.dart';
import 'package:pockettally/backup.dart';
import 'package:pockettally/category_icons.dart';
import 'package:pockettally/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('entry time and category icon survive the database map', () {
    final e = Entry(
        type: EntryType.expense,
        amountMinor: 700,
        category: 'Food',
        date: DateTime(2026, 10, 12),
        minutes: 13 * 60 + 20);
    expect(Entry.fromMap(e.toMap()).minutes, 800);
    // Old rows have no time column value.
    final old = Map<String, Object?>.from(e.toMap())..remove('time');
    expect(Entry.fromMap(old).minutes, isNull);

    const c = EntryCategory(
        name: 'Gym', type: EntryType.expense, colorValue: 1, icon: 'fitness');
    expect(EntryCategory.fromMap(c.toMap()).icon, 'fitness');
  });

  test('time and icon go through a backup', () {
    final b = BackupData(
      userName: 'A',
      currencyCode: 'INR',
      weekStartsOnSunday: false,
      monthlyBudgetMinor: 0,
      categories: const [
        EntryCategory(
            name: 'Gym', type: EntryType.expense, colorValue: 1, icon: 'fitness'),
      ],
      entries: [
        Entry(
            type: EntryType.expense,
            amountMinor: 700,
            category: 'Gym',
            date: DateTime(2026, 10, 12),
            minutes: 75),
      ],
    );
    final back = BackupData.fromJsonString(b.toJsonString());
    expect(back.entries.single.minutes, 75);
    expect(back.categories.single.icon, 'fitness');
  });

  test('icons are guessed from category names', () {
    expect(categoryIconKey('Food'), 'food');
    expect(categoryIconKey('Metro card'), 'bus');
    expect(categoryIconKey('Salary'), 'salary');
    expect(categoryIconKey(kOtherCategory), 'other');
    expect(categoryIconKey('Xyz'), 'other');
    expect(categoryIconKey('Food', chosen: 'gift'), 'gift');
    expect(categoryIconKey('Food', chosen: 'unknown'), 'food');
  });

  test('quick categories: most used first, then the usual order', () async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState(await SharedPreferences.getInstance());
    state.categories = const [
      EntryCategory(name: 'Food', type: EntryType.expense, colorValue: 1),
      EntryCategory(name: 'Rent', type: EntryType.expense, colorValue: 1),
      EntryCategory(name: 'Bus', type: EntryType.expense, colorValue: 1),
      EntryCategory(name: kOtherCategory, type: EntryType.expense, colorValue: 1),
    ];
    final today = DateTime.now();
    state.entries = [
      for (var i = 0; i < 3; i++)
        Entry(
            type: EntryType.expense,
            amountMinor: 100,
            category: 'Bus',
            date: today),
    ];
    final top = state.topCategories(EntryType.expense, count: 3);
    expect(top.first, 'Bus');
    expect(top.length, 3);
  });
}
