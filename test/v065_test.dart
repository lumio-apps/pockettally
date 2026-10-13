import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockettally/app_state.dart';
import 'package:pockettally/l10n/l10n.dart';
import 'package:pockettally/models.dart';
import 'package:pockettally/screens/welcome_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('every language loads, with plurals and placeholders', () {
    expect(kLanguages.length, 20);
    for (final lang in kLanguages) {
      final l = lookupAppLocalizations(Locale(lang.code));
      expect(l.save, isNotEmpty, reason: lang.code);
      expect(l.entryCount(0), isNotEmpty, reason: lang.code);
      expect(l.entryCount(1), isNotEmpty, reason: lang.code);
      expect(l.entryCount(5), contains('5'), reason: lang.code);
      expect(l.entryCount(22), contains('22'), reason: lang.code);
      expect(l.amountOfTotal('A1', 'B2'), allOf(contains('A1'), contains('B2')),
          reason: lang.code);
      expect(l.entriesMovedTo(3, 'XX'), contains('XX'), reason: lang.code);
      expect(l.stepOf('1', '3'), allOf(contains('1'), contains('3')),
          reason: lang.code);
    }
  });

  test('built-in category names are translated, custom ones are not', () {
    final hi = lookupAppLocalizations(const Locale('hi'));
    expect(categoryLabel(hi, 'Food'), 'खाना');
    expect(categoryLabel(hi, kOtherCategory), 'अन्य');
    expect(categoryLabel(hi, 'Gym'), 'Gym');
    final en = lookupAppLocalizations(const Locale('en'));
    expect(categoryLabel(en, 'Salary'), 'Salary');
  });

  test('currency suggested from the country', () {
    expect(currencyForCountry('IN').code, 'INR');
    expect(currencyForCountry('AM').code, 'AMD');
    expect(currencyForCountry('DE').code, 'EUR');
    expect(currencyForCountry('jp').code, 'JPY');
    expect(currencyForCountry('XX').code, 'USD');
    expect(currencyForCountry(null).code, 'USD');
  });

  test('backup error codes have messages', () {
    final l = lookupAppLocalizations(const Locale('en'));
    expect(backupErrorMessage(l, 'too_new'), l.backupTooNew);
    expect(backupErrorMessage(l, 'something'), l.backupInvalid);
  });

  test('language setting', () async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState(await SharedPreferences.getInstance());
    expect(state.languageSetting, isNull);
    await state.setLanguage('hy');
    expect(state.languageCode, 'hy');
    await state.setLanguage('xx'); // unknown -> device language or English
    expect(kLanguages.any((l) => l.code == state.languageCode), isTrue);
  });

  for (final code in ['en', 'ar', 'hi', 'ja']) {
    testWidgets('welcome screen in $code', (tester) async {
      SharedPreferences.setMockInitialValues({'language': code});
      final state = AppState(await SharedPreferences.getInstance());
      await tester.pumpWidget(MaterialApp(
        locale: Locale(code),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: WelcomeScreen(state: state),
      ));
      await tester.pumpAndSettle();
      final l = lookupAppLocalizations(Locale(code));
      expect(find.text(l.welcomeTitle), findsOneWidget);

      // Step 2: name.
      await tester.tap(find.text(l.continueButton));
      await tester.pumpAndSettle();
      expect(find.text(l.whatToCallYou), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Alex');
      await tester.pumpAndSettle();

      // Step 3: currency, then finish.
      await tester.tap(find.text(l.continueButton));
      await tester.pumpAndSettle();
      expect(find.text(l.chooseYourCurrency), findsOneWidget);
      await tester.tap(find.text(l.getStarted));
      await tester.pumpAndSettle();
      expect(state.onboarded, isTrue);
      expect(state.userName, 'Alex');
    });
  }
}
