import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:pockettally/l10n/l10n.dart';

/// Gujarati, Tamil, Telugu, Marathi, Kannada, Malayalam, Punjabi.
const _indian = ['gu', 'ta', 'te', 'mr', 'kn', 'ml', 'pa'];

void main() {
  test('the 7 Indian languages are offered once each', () {
    for (final code in _indian) {
      expect(kLanguages.where((l) => l.code == code), hasLength(1),
          reason: code);
    }
  });

  test('each one is translated, with plurals and placeholders', () {
    final en = lookupAppLocalizations(const Locale('en'));
    for (final code in _indian) {
      final l = lookupAppLocalizations(Locale(code));
      expect(l.save, isNot(en.save), reason: code);
      expect(l.catFood, isNot(en.catFood), reason: code);
      expect(l.lendAndBorrow, isNot(en.lendAndBorrow), reason: code);
      expect(l.entryCount(7), contains('7'), reason: code);
      expect(l.csvImported(12), contains('12'), reason: code);
      expect(l.debtReminderLent('Asha', 'R500'),
          allOf(contains('Asha'), contains('R500')),
          reason: code);
      expect(l.warningCategoryOver('Food', 'A1', 'B2'),
          allOf(contains('Food'), contains('A1'), contains('B2')),
          reason: code);
      expect(l.restoreDetails('31', '42', '53'),
          allOf(contains('31'), contains('42'), contains('53')),
          reason: code);
    }
  });

  test('Flutter and the date formats support them', () async {
    for (final code in _indian) {
      final locale = Locale(code);
      expect(GlobalMaterialLocalizations.delegate.isSupported(locale), isTrue,
          reason: code);
      expect(GlobalCupertinoLocalizations.delegate.isSupported(locale), isTrue,
          reason: code);
      await initializeDateFormatting(code);
      expect(DateFormat.yMMMM(code).format(DateTime(2026, 10, 1)), isNotEmpty,
          reason: code);
    }
  });
}
