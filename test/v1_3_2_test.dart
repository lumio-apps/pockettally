import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pockettally/backup.dart';
import 'package:pockettally/csv_io.dart';
import 'package:pockettally/models.dart';
import 'package:pockettally/utils/amount_parser.dart';

BackupData _backup({Map<String, List<int>> photos = const {}}) => BackupData(
      userName: 'Adity',
      currencyCode: 'INR',
      weekStartsOnSunday: false,
      monthlyBudgetMinor: 0,
      categories: const [],
      entries: [
        Entry(
          type: EntryType.expense,
          amountMinor: 1250,
          category: 'Food',
          date: DateTime(2026, 10, 3),
          photo: 'a.jpg',
        ),
        Entry(
          type: EntryType.expense,
          amountMinor: 500,
          category: 'Food',
          date: DateTime(2026, 10, 4),
          photo: 'gone.jpg',
        ),
      ],
      photos: photos,
    );

void main() {
  group('amount limit', () {
    test('big but sensible amounts still work', () {
      expect(evaluateAmount('1000000000000'), 1000000000000);
      expect(evaluateAmount('1,500,000'), 1500000);
    });

    test('absurd amounts are refused, not stored', () {
      expect(evaluateAmount('1000000000001'), isNull);
      expect(evaluateAmount('99999999999999999999'), isNull);
      expect(evaluateAmount('-99999999999999999999'), isNull);
      expect(evaluateAmount('9999999999*9999999999'), isNull);
    });
  });

  group('CSV import', () {
    test('rows with NaN, Infinity or huge amounts are skipped, the rest stays',
        () {
      const text = 'date,type,category,amount\r\n'
          '2026-10-01,expense,Food,12.50\r\n'
          '2026-10-02,expense,Food,NaN\r\n'
          '2026-10-03,expense,Food,Infinity\r\n'
          '2026-10-04,income,Salary,1e999\r\n'
          '2026-10-05,expense,Food,99999999999999999999\r\n'
          '2026-10-06,expense,Food,7\r\n';
      final result = CsvIo.parse(text);
      expect(result.entries.map((e) => e.amountMinor), [1250, 700]);
      expect(result.skipped, 4);
    });
  });

  group('backup written photo by photo', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('pt_backup_'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('gives the same backup as the one-piece text', () async {
      final photo = List<int>.generate(2000, (i) => i % 251);
      final data = _backup(photos: {'a.jpg': photo});
      final file = File('${dir.path}/b.json');

      await data.writeToFile(
        file,
        photoNames: data.photos.keys,
        readPhoto: (name) => data.photos[name],
      );

      expect(File('${file.path}.tmp').existsSync(), isFalse);
      expect(jsonDecode(file.readAsStringSync()),
          jsonDecode(data.toJsonString()));
      final back = BackupData.fromJsonString(file.readAsStringSync());
      expect(back.photos['a.jpg'], photo);
      expect(back.entries.first.photo, 'a.jpg');
    });

    test('writes a valid file without photos too', () async {
      final file = File('${dir.path}/c.json');
      await _backup().writeToFile(file,
          photoNames: const [], readPhoto: (_) => null);
      final back = BackupData.fromJsonString(file.readAsStringSync());
      expect(back.photos, isEmpty);
      expect(back.entries, hasLength(2));
    });

    test('a photo that cannot be read does not break the file', () async {
      final file = File('${dir.path}/d.json');
      await _backup().writeToFile(file,
          photoNames: ['a.jpg', 'gone.jpg'], readPhoto: (_) => null);
      final back = BackupData.fromJsonString(file.readAsStringSync());
      expect(back.photos, isEmpty);
      expect(back.userName, 'Adity');
    });

    test('a failed write leaves no half file', () async {
      final file = File('${dir.path}/e.json');
      await expectLater(
        _backup().writeToFile(file, photoNames: ['a.jpg'], readPhoto: (_) {
          throw const FileSystemException('disk full');
        }),
        throwsA(isA<FileSystemException>()),
      );
      expect(file.existsSync(), isFalse);
      expect(File('${file.path}.tmp').existsSync(), isFalse);
    });
  });
}
