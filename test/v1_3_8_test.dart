import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('README pictures exist', () {
    final readme = File('README.md').readAsStringSync();
    final pictures = RegExp(r'docs/[a-z/\-]+\.png').allMatches(readme);
    expect(pictures, isNotEmpty);
    for (final m in pictures) {
      expect(File(m.group(0)!).existsSync(), isTrue, reason: m.group(0));
    }
  });
}
