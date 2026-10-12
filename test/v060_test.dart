import 'package:flutter_test/flutter_test.dart';
import 'package:pockettally/app_state.dart';
import 'package:pockettally/backup.dart';
import 'package:pockettally/models.dart';
import 'package:pockettally/theme.dart';
import 'package:pockettally/update_checker.dart';
import 'package:pockettally/utils/amount_parser.dart';
import 'package:pockettally/utils/money_format.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('MoneyFormatter', () {
    MoneyFormatter f(NumberStyle s, [int d = 2]) =>
        MoneyFormatter(style: s, decimals: d);

    test('number styles', () {
      expect(f(NumberStyle.commaDot).number(123456789), '1,234,567.89');
      expect(f(NumberStyle.dotComma).number(123456789), '1.234.567,89');
      expect(f(NumberStyle.spaceComma).number(123456789),
          '1 234 567,89');
      expect(f(NumberStyle.apostropheDot).number(123456789), "1'234'567.89");
      expect(f(NumberStyle.indian).number(123456789), '12,34,567.89');
      expect(f(NumberStyle.indian).number(1234500), '12,345.00');
      expect(f(NumberStyle.commaDot).number(5), '0.05');
      expect(f(NumberStyle.commaDot).number(-150000), '-1,500.00');
    });

    test('no decimals rounds to whole units', () {
      expect(f(NumberStyle.commaDot, 0).number(123450), '1,235');
      expect(f(NumberStyle.commaDot, 0).number(123449), '1,234');
      expect(f(NumberStyle.commaDot, 0).number(-20), '0');
      expect(f(NumberStyle.commaDot, 0).toMinor(499.6), 50000);
      expect(f(NumberStyle.commaDot).toMinor(12.5), 1250);
    });

    test('money puts the minus sign before the symbol', () {
      expect(f(NumberStyle.commaDot).money(-1250, r'$'), r'-$ 12.50');
      expect(f(NumberStyle.dotComma).money(1250, '€'), '€ 12,50');
    });

    test('input text for editing', () {
      expect(f(NumberStyle.commaDot).input(1250), '12.5');
      expect(f(NumberStyle.commaDot).input(32000), '320');
      expect(f(NumberStyle.dotComma).input(1205), '12,05');
      expect(f(NumberStyle.commaDot, 0).input(32000), '320');
    });

    test('parse with decimal comma', () {
      final de = f(NumberStyle.dotComma);
      expect(de.parse('12,5'), 12.5);
      expect(de.parse('1.500'), 1500);
      expect(de.parse('1.500,25'), 1500.25);
      expect(de.parse('12.5'), 12.5);
      expect(de.parse('10,5+2'), 12.5);
    });
  });

  test('evaluateAmount ignores spaces and apostrophes', () {
    expect(evaluateAmount("1'500.50"), 1500.5);
    expect(evaluateAmount('1 500,5', decimalComma: true), 1500.5);
  });

  test('currencies: decimals and automatic number style', () {
    expect(currencyByCode('JPY').decimals, 0);
    expect(currencyByCode('KRW').decimals, 0);
    expect(currencyByCode('USD').decimals, 2);
    expect(currencyByCode('INR').numberStyle, NumberStyle.indian);
    expect(currencyByCode('EUR').numberStyle, NumberStyle.dotComma);
  });

  test('settings change formatting', () async {
    SharedPreferences.setMockInitialValues({
      'user_name': 'Alex',
      'currency': 'JPY',
    });
    final state = AppState(await SharedPreferences.getInstance());
    expect(state.formatMoney(150000), '¥ 1,500');
    expect(state.parseMinor('1500'), 150000);

    await state.setDecimals(2);
    expect(state.formatMoney(150000), '¥ 1,500.00');

    await state.setNumberStyle(NumberStyle.dotComma);
    expect(state.formatMoney(150000), '¥ 1.500,00');
    expect(state.formatMoney(150000, symbol: 'JPY'), 'JPY 1.500,00');

    expect(state.palette.id, 'blue'); // the default since 1.0.0
    await state.setPalette(paletteById('ocean'));
    expect(state.palette.name, 'Ocean');
  });

  test('categories follow the user order, Other last, hidden filtered', () async {
    SharedPreferences.setMockInitialValues({'user_name': 'Alex'});
    final state = AppState(await SharedPreferences.getInstance());
    state.categories = const [
      EntryCategory(
          id: 1, name: 'Food', type: EntryType.expense, colorValue: 1),
      EntryCategory(
          id: 2,
          name: kOtherCategory,
          type: EntryType.expense,
          colorValue: 1),
      EntryCategory(
          id: 3,
          name: 'Bills',
          type: EntryType.expense,
          colorValue: 1,
          position: 1),
      EntryCategory(
          id: 4,
          name: 'Travel',
          type: EntryType.expense,
          colorValue: 1,
          position: 2,
          hidden: true),
    ];
    // Never-reordered (position 0) first, alphabetically; then by position.
    expect(state.categoriesFor(EntryType.expense).map((c) => c.name),
        ['Food', 'Bills', 'Travel', kOtherCategory]);
    expect(
        state
            .categoriesFor(EntryType.expense, includeHidden: false)
            .map((c) => c.name),
        ['Food', 'Bills', kOtherCategory]);
    expect(
        state
            .categoriesFor(EntryType.expense,
                includeHidden: false, keep: 'Travel')
            .map((c) => c.name),
        ['Food', 'Bills', 'Travel', kOtherCategory]);
  });

  test('category copyWith keeps order and hidden', () {
    const c = EntryCategory(
        id: 7,
        name: 'Food',
        type: EntryType.expense,
        colorValue: 1,
        budgetMinor: 500,
        position: 3,
        hidden: true);
    final renamed = c.copyWith(name: 'Meals', budgetMinor: () => null);
    expect(renamed.id, 7);
    expect(renamed.name, 'Meals');
    expect(renamed.position, 3);
    expect(renamed.hidden, isTrue);
    expect(renamed.budgetMinor, isNull);
    expect(EntryCategory.fromMap(c.toMap()).hidden, isTrue);
  });

  test('backup keeps new settings and category order', () {
    final b = BackupData(
      userName: 'Alex',
      currencyCode: 'EUR',
      weekStartsOnSunday: false,
      monthlyBudgetMinor: 0,
      numberStyle: 'dotComma',
      decimals: 0,
      palette: 'plum',
      categories: const [
        EntryCategory(
            name: 'Food',
            type: EntryType.expense,
            colorValue: 1,
            position: 2,
            hidden: true),
      ],
      entries: const [],
    );
    final copy = BackupData.fromJsonString(b.toJsonString());
    expect(copy.numberStyle, 'dotComma');
    expect(copy.decimals, 0);
    expect(copy.palette, 'plum');
    expect(copy.categories.single.position, 2);
    expect(copy.categories.single.hidden, isTrue);
  });

  group('update APK choice', () {
    const v = 'https://example.com/';
    final assets = {
      'pockettally-v0.6.0-universal.apk': '${v}u',
      'pockettally-v0.6.0-arm64-v8a.apk': '${v}a64',
      'pockettally-v0.6.0-armeabi-v7a.apk': '${v}a32',
      'pockettally-v0.6.0-x86_64.apk': '${v}x64',
    };

    test('split APK for the phone', () {
      expect(UpdateChecker.pickApkUrl(assets, 'arm64-v8a'), '${v}a64');
      expect(UpdateChecker.pickApkUrl(assets, 'armeabi-v7a'), '${v}a32');
      expect(UpdateChecker.pickApkUrl(assets, 'x86_64'), '${v}x64');
    });

    test('universal when the chip is unknown', () {
      expect(UpdateChecker.pickApkUrl(assets, null), '${v}u');
    });

    test('old single-APK releases', () {
      expect(
          UpdateChecker.pickApkUrl(
              {'pockettally-v0.5.0.apk': '${v}old', 'notes.txt': '${v}n'},
              'arm64-v8a'),
          '${v}old');
      expect(UpdateChecker.pickApkUrl({}, 'arm64-v8a'), isNull);
    });
  });
}
