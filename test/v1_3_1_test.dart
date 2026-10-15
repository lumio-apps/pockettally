import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _meta = 'fastlane/metadata/android/en-US';

String _read(String name) => File('$_meta/$name').readAsStringSync();

/// The number after the `+` in pubspec.yaml: the Android version code.
int _buildNumber() {
  final line = File('pubspec.yaml')
      .readAsLinesSync()
      .firstWhere((l) => l.startsWith('version:'));
  return int.parse(RegExp(r'\+(\d+)').firstMatch(line)!.group(1)!);
}

void main() {
  test('F-Droid store listing fits the limits', () {
    expect(_read('title.txt').trim().length, inInclusiveRange(1, 30));
    expect(_read('short_description.txt').trim().length, inInclusiveRange(1, 80));
    expect(_read('full_description.txt').length, lessThanOrEqualTo(4000));
  });

  test('every F-Droid image is there', () {
    for (final f in ['icon.png', 'featureGraphic.png']) {
      expect(File('$_meta/images/$f').existsSync(), isTrue, reason: f);
    }
    final shots = Directory('$_meta/images/phoneScreenshots')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.png'));
    expect(shots.length, greaterThanOrEqualTo(2));
  });

  test('the current version has a changelog of at most 500 bytes', () {
    final file = File('$_meta/changelogs/${_buildNumber()}.txt');
    expect(file.existsSync(), isTrue,
        reason: 'add changelogs/${_buildNumber()}.txt for this version');
    expect(utf8.encode(file.readAsStringSync()).length, lessThanOrEqualTo(500));
  });

  test('the F-Droid recipe points at the current version', () {
    final recipe = File('fdroid/com.lumio.pockettally.yml').readAsStringSync();
    expect(recipe, contains('versionCode: ${_buildNumber()}'));
    expect(recipe, contains('CurrentVersionCode: ${_buildNumber()}'));
    expect(recipe, isNot(contains('UPDATER')));
    expect(recipe, contains('prepare_android.py manifest --fdroid'));
  });
}
