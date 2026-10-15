import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Version 1.3.6 is set everywhere', () {
    expect(File('pubspec.yaml').readAsStringSync(),
        contains('version: 1.3.7+34'));
    expect(File('fastlane/metadata/android/en-US/changelogs/34.txt').existsSync(),
        isTrue);
    final recipe = File('fdroid/com.lumio.pockettally.yml').readAsStringSync();
    expect(recipe, contains('versionCode: 34'));
    expect(recipe, contains('commit: v1.3.7'));
  });

  test('The app is Android only', () {
    final workflow = File('.github/workflows/build.yml').readAsStringSync();
    expect(workflow, isNot(contains('windows-latest')));
    expect(workflow, isNot(contains('flutter build windows')));
    expect(workflow, isNot(contains('flutter build linux')));
    expect(File('tool/windows').existsSync(), isFalse);
    expect(File('tool/linux').existsSync(), isFalse);
    expect(File('tool/prepare_desktop.py').existsSync(), isFalse);
    expect(File('lib/platform.dart').existsSync(), isFalse);
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, isNot(contains('sqflite_common_ffi')));
    expect(pubspec, isNot(contains('sqlite3_flutter_libs')));
  });

  test('No Dart file still uses the desktop code', () {
    for (final f in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final text = f.readAsStringSync();
      expect(text, isNot(contains('isDesktop')), reason: f.path);
      expect(text, isNot(contains('sqflite_common_ffi')), reason: f.path);
      expect(text, isNot(contains('Platform.isWindows')), reason: f.path);
      expect(text, isNot(contains('Platform.isLinux')), reason: f.path);
    }
  });
}
