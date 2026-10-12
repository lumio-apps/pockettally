/// Marks moments when the app is left on purpose (file or photo picker,
/// save dialog, permission prompt, installer), so the app lock does not
/// ask for the PIN when the user comes back from them.
class LockGuard {
  static int _depth = 0;

  /// True while such a dialog or picker is open.
  static bool get active => _depth > 0;

  static Future<T> around<T>(Future<T> Function() action) async {
    _depth++;
    try {
      return await action();
    } finally {
      _depth--;
    }
  }
}
