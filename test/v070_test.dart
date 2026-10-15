import 'package:flutter_test/flutter_test.dart';
import 'package:pockettally/update_checker.dart';

void main() {
  group('update files', () {
    const assets = {
      'pockettally-v0.7.0-universal.apk': 'apk',
      'pockettally-v0.7.0-windows-setup.exe': 'setup',
      'pockettally-v0.7.0-linux-x86_64.AppImage': 'appimage',
    };

    test('phones get the APK, never an old desktop file', () {
      expect(UpdateChecker.pickApkUrl(assets, null), 'apk');
    });
  });

  test('version comparison', () {
    expect(UpdateChecker.isNewer('0.7.0', '0.6.5'), isTrue);
    expect(UpdateChecker.isNewer('0.7.0', '0.7.0'), isFalse);
    expect(UpdateChecker.isNewer('0.6.5', '0.7.0'), isFalse);
    expect(UpdateChecker.isNewer('1.0.0', '0.9.9+12'), isTrue);
  });
}
