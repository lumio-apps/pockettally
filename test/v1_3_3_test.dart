import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pockettally/reminder.dart';

void main() {
  test('exact alarms are on by default', () {
    // Tests run without --dart-define, like the GitHub release build.
    expect(kExactAlarms, isTrue);
  });

  test('the release workflow builds only the APK', () {
    final yml = File('.github/workflows/build.yml').readAsStringSync();
    expect(yml, contains('flutter build apk'));
    expect(yml, isNot(contains('appbundle')));
    expect(yml, isNot(contains('UPDATER')));
  });

  test('the privacy policy is there and says what the app does', () {
    final text = File('PRIVACY.md').readAsStringSync();
    expect(text, contains('We do not collect'));
    expect(text, contains('no internet permission'));
    expect(text, contains('github.com/lumio-apps/pockettally'));
  });
}
