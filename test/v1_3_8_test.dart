import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Version 1.3.8 is set everywhere', () {
    expect(File('pubspec.yaml').readAsStringSync(),
        contains('version: 1.3.8+35'));
    expect(File('fastlane/metadata/android/en-US/changelogs/35.txt').existsSync(),
        isTrue);
    final recipe = File('fdroid/com.lumio.pockettally.yml').readAsStringSync();
    expect(recipe, contains('versionCode: 35'));
    expect(recipe, contains('commit: v1.3.8'));
  });

  test('README pictures exist', () {
    final readme = File('README.md').readAsStringSync();
    final pictures = RegExp(r'docs/[a-z/\-]+\.png').allMatches(readme);
    expect(pictures, isNotEmpty);
    for (final m in pictures) {
      expect(File(m.group(0)!).existsSync(), isTrue, reason: m.group(0));
    }
  });
}
