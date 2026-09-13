package com.baboevazamatkz.expense_tracker

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Carries a widget tap through to Flutter.
 *
 * The launcher starts this activity with the type (and, for an expense, the
 * category) the user tapped. Dart asks for it once it is ready and again on
 * every resume; whatever is pending is handed over and cleared, so a tap is
 * acted on exactly once.
 */
class MainActivity : FlutterActivity() {
    private var pending: Map<String, String>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "consumeLaunchAction" -> {
                        result.success(pending)
                        pending = null
                    }
                    else -> result.notImplemented()
                }
            }
        capture(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        capture(intent)
    }

    private fun capture(intent: Intent?) {
        if (intent?.action != SolidusWidgetProvider.ACTION_ADD) return
        val type = intent.getStringExtra(SolidusWidgetProvider.EXTRA_TYPE) ?: return
        pending = buildMap {
            put("type", type)
            intent.getStringExtra(SolidusWidgetProvider.EXTRA_CATEGORY)
                ?.let { put("category", it) }
        }
        // The same intent is redelivered if the activity is recreated (a
        // rotation, a theme change), which would reopen the sheet. Clearing
        // the action makes the tap a one-shot.
        intent.action = null
    }

    companion object {
        private const val CHANNEL = "solidus/widget"
    }
}
