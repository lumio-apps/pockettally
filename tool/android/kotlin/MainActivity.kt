package com.lumio.pockettally

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * The app's only screen. Besides Flutter it handles the launcher shortcuts
 * and the home screen widget buttons ("expense" / "income"), and lets the
 * app refresh the widgets (see lib/android_extras.dart).
 */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null

    /** What a shortcut or widget button asked for, until the app takes it. */
    private var pendingAction: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pendingAction = actionOf(intent)
        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "takeAction" -> {
                    result.success(pendingAction)
                    pendingAction = null
                }
                "updateWidgets" -> {
                    try {
                        WidgetUpdater.updateAll(applicationContext)
                    } catch (e: Exception) {
                        // A widget problem must never stop the app.
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        channel = ch
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val action = actionOf(intent) ?: return
        val ch = channel
        if (ch == null) {
            pendingAction = action
        } else {
            ch.invokeMethod("action", action)
        }
    }

    companion object {
        const val CHANNEL = "com.lumio.pockettally/android"
        const val EXTRA_ACTION = "pockettally_action"

        fun actionOf(intent: Intent?): String? = intent?.getStringExtra(EXTRA_ACTION)
    }
}
