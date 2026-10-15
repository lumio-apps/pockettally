import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('The update check is gone', () {
    expect(File('lib/update_checker.dart').existsSync(), isFalse);
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, isNot(contains('http:')));
    expect(pubspec, isNot(contains('open_filex')));
    for (final f in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final text = f.readAsStringSync();
      expect(text, isNot(contains('UpdateChecker')), reason: f.path);
      expect(text, isNot(contains('kUpdaterEnabled')), reason: f.path);
      expect(text, isNot(contains('package:http/')), reason: f.path);
    }
  });

  test('No build adds internet or install permissions', () {
    final script = File('tool/prepare_android.py').readAsStringSync();
    expect(script, isNot(contains('UPDATER_PERMISSIONS')));
    expect(script,
        contains('android.permission.INTERNET" tools:node="remove"'));
    final workflow = File('.github/workflows/build.yml').readAsStringSync();
    expect(workflow, isNot(contains('UPDATER')));
  });
}
