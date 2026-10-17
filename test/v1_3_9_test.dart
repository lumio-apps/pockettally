import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Version 1.3.9 is set', () {
    expect(File('pubspec.yaml').readAsStringSync(),
        contains('version: 1.3.9+36'));
  });

  test('GitHub only: no store files and no bundle build', () {
    for (final p in ['fastlane', 'fdroid', 'docs/play-store']) {
      expect(Directory(p).existsSync(), isFalse, reason: p);
    }
    final wf = File('.github/workflows/build.yml').readAsStringSync();
    expect(wf, isNot(contains('appbundle')));
    expect(wf, contains('files: pockettally-*-android.apk'));
  });
}
