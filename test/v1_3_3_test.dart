import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pockettally/reminder.dart';

String _block(String text, String heading) {
  final start = text.indexOf(heading);
  expect(start, isNonNegative, reason: heading);
  final open = text.indexOf('```\n', start) + 4;
  return text.substring(open, text.indexOf('\n```', open));
}

void main() {
  test('exact alarms are on unless the Play build switches them off', () {
    // Tests run without --dart-define, like the GitHub and F-Droid builds.
    expect(kExactAlarms, isTrue);
  });

  test('the Play build is made by the release workflow', () {
    final yml = File('.github/workflows/build.yml').readAsStringSync();
    expect(yml, contains('flutter build appbundle'));
    expect(yml, isNot(contains('UPDATER')));
    expect(yml, contains('--dart-define=EXACT_ALARMS=false'));
    expect(yml, contains('prepare_android.py manifest --play'));
    expect(yml, contains('check_play_bundle.py'));
  });

  group('Google Play listing', () {
    final listing = File('docs/play-store/listing.md').readAsStringSync();

    test('texts fit the limits', () {
      expect(_block(listing, '### Short description').length,
          inInclusiveRange(1, 80));
      expect(_block(listing, '### Full description').length,
          inInclusiveRange(1, 4000));
      expect(_block(listing, "### What's new").length, inInclusiveRange(1, 500));
    });

    test('the 6 screenshots are 1080 x 1920 PNG files', () {
      for (var i = 1; i <= 6; i++) {
        final bytes = File('docs/play-store/phone-$i.png').readAsBytesSync();
        // PNG header: signature, then IHDR with width and height.
        expect(bytes.sublist(1, 4), [0x50, 0x4E, 0x47], reason: 'phone-$i');
        int u32(int at) =>
            bytes[at] << 24 | bytes[at + 1] << 16 | bytes[at + 2] << 8 | bytes[at + 3];
        expect(u32(16), 1080, reason: 'phone-$i width');
        expect(u32(20), 1920, reason: 'phone-$i height');
      }
    });
  });

  test('the privacy policy is there and says what the app does', () {
    final text = File('PRIVACY.md').readAsStringSync();
    expect(text, contains('We do not collect'));
    expect(text, contains('no internet permission'));
    expect(text, contains('github.com/lumio-apps/pockettally'));
  });
}
