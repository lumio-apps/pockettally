import 'package:flutter_test/flutter_test.dart';
import 'package:pockettally/update_checker.dart';

void main() {
  group('desktop update files', () {
    const assets = {
      'pockettally-v0.7.0-universal.apk': 'apk',
      'pockettally-v0.7.0-windows-setup.exe': 'setup',
      'pockettally-v0.7.0-windows.zip': 'zip',
      'pockettally-v0.7.0-linux-x86_64.AppImage': 'appimage',
      'pockettally-v0.7.0-linux-x86_64.tar.gz': 'tar',
    };

    test('Windows gets the installer, Linux the AppImage', () {
      expect(UpdateChecker.pickDesktopUrl(assets, kWindowsSetupSuffix), 'setup');
      expect(
          UpdateChecker.pickDesktopUrl(assets, kLinuxAppImageSuffix), 'appimage');
    });

    test('no desktop file in older releases', () {
      expect(
          UpdateChecker.pickDesktopUrl(
              {'pockettally-v0.6.5-universal.apk': 'apk'}, kWindowsSetupSuffix),
          isNull);
    });

    test('phones still get an APK, never a desktop file', () {
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
