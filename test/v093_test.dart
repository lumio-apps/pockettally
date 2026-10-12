import 'package:flutter_test/flutter_test.dart';
import 'package:pockettally/backup.dart';

void main() {
  BackupData backup({List<int>? photo}) => BackupData(
        userName: 'Adity',
        currencyCode: 'AMD',
        weekStartsOnSunday: false,
        monthlyBudgetMinor: 0,
        categories: const [],
        entries: const [],
        profilePhoto: photo,
      );

  test('the profile photo goes through a backup', () {
    final photo = [0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3, 250];
    final back = BackupData.fromJsonString(backup(photo: photo).toJsonString());
    expect(back.profilePhoto, photo);
    expect(back.userName, 'Adity');
  });

  test('a backup without a photo has none', () {
    final text = backup().toJsonString();
    expect(text, isNot(contains('profilePhoto')));
    expect(BackupData.fromJsonString(text).profilePhoto, isNull);
  });

  test('a damaged photo does not stop a restore', () {
    final text = backup(photo: [1, 2, 3])
        .toJsonString()
        .replaceFirst(RegExp(r'"profilePhoto": "[^"]*"'), '"profilePhoto": "%%%"');
    final back = BackupData.fromJsonString(text);
    expect(back.profilePhoto, isNull);
    expect(back.userName, 'Adity');
  });
}
