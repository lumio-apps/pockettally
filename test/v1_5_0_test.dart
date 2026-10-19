import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Biometric unlock is wired in', () {
    expect(File('pubspec.yaml').readAsStringSync(), contains('local_auth:'));
    expect(File('tool/android/kotlin/MainActivity.kt').readAsStringSync(),
        contains('FlutterFragmentActivity'));
    expect(File('lib/biometric.dart').existsSync(), isTrue);
    expect(File('lib/app_state.dart').readAsStringSync(),
        contains('biometricOn'));
  });

  test('All languages have the biometric strings', () {
    for (final f in Directory('lib/l10n')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.arb'))) {
      final s = f.readAsStringSync();
      expect(s, contains('"biometricUnlock"'), reason: f.path);
      expect(s, contains('"biometricReason"'), reason: f.path);
    }
  });
}
