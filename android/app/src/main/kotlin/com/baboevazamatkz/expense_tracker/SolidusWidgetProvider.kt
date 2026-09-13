package com.baboevazamatkz.expense_tracker

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

/**
 * The home-screen widget: an expense line with a category, and an income line.
 *
 * One thing the design asked for cannot be built. An app widget is a
 * RemoteViews tree drawn by the launcher's process, and the platform gives it
 * no input method -- an EditText inside a widget cannot be focused or typed
 * into on any Android version. So the amount areas are not fields but targets:
 * tapping one opens the app's own add sheet with the keyboard already up, the
 * type already chosen, and for an expense the category already set to whatever
 * the chip is showing. Entering an amount takes the same number of taps it
 * would have; what the widget saves is choosing the type and the category.
 *
 * The chip itself is handled entirely here: tapping it cycles to the next
 * category and redraws the widget, without opening anything.
 */
class SolidusWidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_CYCLE = "com.baboevazamatkz.expense_tracker.WIDGET_CYCLE"
        const val ACTION_ADD = "com.baboevazamatkz.expense_tracker.WIDGET_ADD"

        const val EXTRA_TYPE = "solidus.type"
        const val EXTRA_CATEGORY = "solidus.category"

        private const val PREFS = "solidus_widget"
        private const val KEY_CATEGORY = "category_index"

        /**
         * Mirrors ExpenseCategory in lib/models/expense_category.dart, in the
         * same order. The keys are that enum's own names, which is what the
         * app stores and what the sheet expects back.
         */
        private val CATEGORY_KEYS = listOf(
            "food", "transport", "housing", "entertainment",
            "health", "shopping", "other",
        )
        private val CATEGORY_LABELS = listOf(
            "Еда", "Транспорт", "Жильё", "Развлечения",
            "Здоровье", "Покупки", "Другое",
        )

        fun categoryIndex(context: Context): Int {
            val stored = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getInt(KEY_CATEGORY, 0)
            return ((stored % CATEGORY_KEYS.size) + CATEGORY_KEYS.size) % CATEGORY_KEYS.size
        }

        fun setCategoryIndex(context: Context, index: Int) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit()
                .putInt(KEY_CATEGORY, index)
                .apply()
        }

        fun redrawAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, SolidusWidgetProvider::class.java)
            )
            for (id in ids) render(context, manager, id)
        }

        private fun render(context: Context, manager: AppWidgetManager, widgetId: Int) {
            val index = categoryIndex(context)
            val views = RemoteViews(context.packageName, R.layout.widget_solidus)
            views.setTextViewText(R.id.w_category, CATEGORY_LABELS[index])

            val expense = openApp(context, widgetId, "expense", CATEGORY_KEYS[index])
            views.setOnClickPendingIntent(R.id.w_expense_amount, expense)
            views.setOnClickPendingIntent(R.id.w_add_expense, expense)

            val income = openApp(context, widgetId, "income", null)
            views.setOnClickPendingIntent(R.id.w_income_amount, income)
            views.setOnClickPendingIntent(R.id.w_add_income, income)

            views.setOnClickPendingIntent(R.id.w_category, cycle(context, widgetId))

            manager.updateAppWidget(widgetId, views)
        }

        private fun openApp(
            context: Context,
            widgetId: Int,
            type: String,
            category: String?,
        ): PendingIntent {
            val intent = Intent(context, MainActivity::class.java).apply {
                action = ACTION_ADD
                // Without a distinct data uri every one of these collapses
                // onto the same PendingIntent and both rows open the same
                // sheet, whichever was registered last.
                data = android.net.Uri.parse("solidus://add/$type/${category ?: "none"}/$widgetId")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra(EXTRA_TYPE, type)
                if (category != null) putExtra(EXTRA_CATEGORY, category)
            }
            return PendingIntent.getActivity(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        private fun cycle(context: Context, widgetId: Int): PendingIntent {
            val intent = Intent(context, SolidusWidgetProvider::class.java).apply {
                action = ACTION_CYCLE
                data = android.net.Uri.parse("solidus://cycle/$widgetId")
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            }
            return PendingIntent.getBroadcast(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
    }

    override fun onUpdate(
        context: Context,
        manager: AppWidgetManager,
        widgetIds: IntArray,
    ) {
        for (id in widgetIds) render(context, manager, id)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        manager: AppWidgetManager,
        widgetId: Int,
        newOptions: android.os.Bundle,
    ) {
        // Resizing re-lays out the same tree, but redrawing keeps the chip
        // correct if the widget was resized while the app changed it.
        render(context, manager, widgetId)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_CYCLE) {
            setCategoryIndex(context, categoryIndex(context) + 1)
            redrawAll(context)
        }
    }
}
