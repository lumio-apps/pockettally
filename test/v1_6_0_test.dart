import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pockettally/models.dart';

void main() {
  TrashedEntry item(int daysAgo) => TrashedEntry(
        Entry(
          id: 1,
          type: EntryType.expense,
          amountMinor: 100,
          category: 'Food',
          date: DateTime(2026, 10, 1),
        ),
        DateTime.now().subtract(Duration(days: daysAgo)),
      );

  test('Trash keeps an entry for 30 days', () {
    expect(kTrashDays, 30);
    expect(item(0).daysLeft(), inInclusiveRange(29, 30));
    expect(item(10).daysLeft(), inInclusiveRange(19, 20));
    expect(item(45).daysLeft(), 0);
  });

  test('Database moves deleted entries to the Trash', () {
    final db = File('lib/db.dart').readAsStringSync();
    expect(db, contains("'deleted_at'"));
    expect(db, contains('deleted_at IS NULL'));
    expect(File('lib/screens/trash_screen.dart').existsSync(), isTrue);
  });

  test('All languages have the Trash strings', () {
    for (final f in Directory('lib/l10n')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.arb'))) {
      final s = f.readAsStringSync();
      for (final k in ['trash', 'trashHint', 'emptyTrash', 'deleteForever']) {
        expect(s, contains('"$k"'), reason: f.path);
      }
    }
  });
}
