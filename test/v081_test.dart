import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockettally/l10n/l10n.dart';

void main() {
  test('values land in the right place in messages', () {
    final l = lookupAppLocalizations(const Locale('en'));
    expect(l.warningCategoryOver('Food', '\$ 120', '\$ 100'),
        'Food is over its limit (\$ 120 of \$ 100)');
    expect(l.warningMonthlyOver('\$ 900', '\$ 800'),
        'Monthly budget exceeded (\$ 900 of \$ 800)');
    expect(l.restoreDetails('10', '5', '3'), startsWith('Entries in the backup: 10\nCategories in the backup: 5'));
    expect(l.paidBackOf('\$ 20', '\$ 50'), '\$ 20 of \$ 50 paid back');
  });
}
