package com.baboevazamatkz.expense_tracker

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews

/**
 * A second, much simpler home-screen widget: one button that opens the app
 * straight into the voice assistant, already listening.
 *
 * Unlike [SolidusWidgetProvider] this one cannot record anything itself --
 * a widget has no code of its own beyond the views it draws and the
 * intents its views send, and turning speech into a record needs both the
 * speech engine and the app's own parsing, neither of which a
 * [android.content.BroadcastReceiver] can reach. So the tap's only job is
 * to open [MainActivity] with [ACTION_VOICE] set, which MainActivity turns
 * into a one-shot "start listening now" for Dart to consume -- as close to
 * "press and speak" as a plain launcher tap can get.
 */
class SolidusVoiceWidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_VOICE = "com.baboevazamatkz.expense_tracker.WIDGET_VOICE"
    }

    override fun onUpdate(
        context: Context,
        manager: AppWidgetManager,
        widgetIds: IntArray,
    ) {
        for (id in widgetIds) render(context, manager, id)
    }

    private fun render(context: Context, manager: AppWidgetManager, widgetId: Int) {
        val views = RemoteViews(context.packageName, R.layout.widget_solidus_voice)
        val intent = Intent(context, MainActivity::class.java).apply {
            action = ACTION_VOICE
            data = Uri.parse("solidus://voice")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pending = PendingIntent.getActivity(
            context, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        views.setOnClickPendingIntent(R.id.w_voice_button, pending)
        manager.updateAppWidget(widgetId, views)
    }
}
