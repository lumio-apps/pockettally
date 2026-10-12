import 'package:flutter_test/flutter_test.dart';
import 'package:pockettally/update_checker.dart';

void main() {
  test('the single Android APK is picked on every phone', () {
    const assets = {
      'pockettally-v0.9.4-android.apk': 'apk',
      'pockettally-v0.9.4-windows-setup.exe': 'exe',
      'pockettally-v0.9.4-linux-x86_64.AppImage': 'appimage',
    };
    for (final abi in ['arm64-v8a', 'armeabi-v7a', 'x86_64', null]) {
      expect(UpdateChecker.pickApkUrl(assets, abi), 'apk');
    }
  });
}
