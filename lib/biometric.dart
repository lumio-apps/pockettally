import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import 'utils/lock_guard.dart';

/// Fingerprint or face unlock through the phone's own prompt. The app only
/// learns "yes" or "no"; it never sees the fingerprint or the face.
class Biometric {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// True when the phone can check a fingerprint or face and one is set up.
  static Future<bool> available() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      if (!await _auth.canCheckBiometrics) return false;
      return (await _auth.getAvailableBiometrics()).isNotEmpty;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Shows the system prompt. True only when it was passed; any error,
  /// cancel or "too many tries" counts as false, so the PIN stays the way in.
  static Future<bool> authenticate(String reason) async {
    try {
      // The prompt takes the app out of the foreground: no relock meanwhile.
      return await LockGuard.around(() => _auth.authenticate(
            localizedReason: reason,
            options: const AuthenticationOptions(
              biometricOnly: true,
              stickyAuth: true,
            ),
          ));
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
