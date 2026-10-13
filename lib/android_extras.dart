import 'dart:io';

import 'package:flutter/services.dart';

/// The home screen widgets and the launcher shortcuts (Android only).
///
/// The Android side lives in tool/android (MainActivity.kt and
/// WidgetProviders.kt). The widgets show texts the app saves in its
/// settings (see AppState.syncWidget); nothing else is shared.
class AndroidExtras {
  static const MethodChannel _channel =
      MethodChannel('com.lumio.pockettally/android');

  static bool get supported => Platform.isAndroid;

  /// [onAction] gets "expense" or "income" when a shortcut or a widget
  /// button is tapped while the app is open.
  static void listen(void Function(String action) onAction) {
    if (!supported) return;
    _channel.setMethodCallHandler((call) async {
      final action = call.arguments;
      if (call.method == 'action' && action is String) onAction(action);
    });
  }

  /// What a shortcut or widget button asked for when it opened the app
  /// ("expense", "income"), or null. Asked once, at start.
  static Future<String?> takeAction() async {
    if (!supported) return null;
    try {
      return await _channel.invokeMethod<String>('takeAction');
    } catch (_) {
      return null;
    }
  }

  /// Opens the app's page in the phone settings. Returns false if it could
  /// not be opened.
  static Future<bool> openAppSettings() async {
    if (!supported) return false;
    try {
      return await _channel.invokeMethod<bool>('openAppSettings') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Redraws the widgets with the texts saved last.
  static Future<void> updateWidgets() async {
    if (!supported) return;
    try {
      await _channel.invokeMethod<void>('updateWidgets');
    } catch (_) {
      // No widget, or an older Android side: nothing to do.
    }
  }
}
