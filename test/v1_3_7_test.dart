import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pockettally/update_checker.dart';

void main() {
  group('update check', () {
    test('newer version is detected', () {
      expect(UpdateChecker.isNewer('1.3.10', '1.3.9'), isTrue);
      expect(UpdateChecker.isNewer('1.4.0', '1.3.10'), isTrue);
      expect(UpdateChecker.isNewer('1.3.9', '1.3.9'), isFalse);
      expect(UpdateChecker.isNewer('1.3.8', '1.3.9'), isFalse);
      expect(UpdateChecker.isNewer('2.0', '1.9.9+40'), isTrue);
    });

    test('the APK of the release is picked', () {
      const v = 'https://x/';
      expect(
        UpdateChecker.pickApkUrl({
          'pockettally-v1.4.0-android.apk': '${v}apk',
          'notes.txt': '${v}txt',
        }),
        '${v}apk',
      );
      expect(UpdateChecker.pickApkUrl({'old.APK': '${v}old'}), '${v}old');
      expect(UpdateChecker.pickApkUrl({'a.txt': '${v}a'}), isNull);
      expect(UpdateChecker.pickApkUrl({}), isNull);
    });
  });

  test('Settings has the update button and the manifest gets the permissions',
      () {
    final settings = File('lib/screens/settings_screen.dart').readAsStringSync();
    expect(settings, contains('UpdateChecker.check()'));
    final script = File('tool/prepare_android.py').readAsStringSync();
    expect(script, contains('android.permission.INTERNET"/>'));
    expect(script, contains('android.permission.REQUEST_INSTALL_PACKAGES"/>'));
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('http:'));
    expect(pubspec, contains('open_filex'));
  });
}
