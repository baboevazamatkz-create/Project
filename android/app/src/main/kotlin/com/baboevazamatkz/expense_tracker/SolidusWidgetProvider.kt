package com.baboevazamatkz.expense_tracker

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.widget.RemoteViews
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import java.util.Date
import java.util.UUID

/**
 * The home-screen widget: an expense line with a category, an income line,
 * and a keypad under both.
 *
 * A widget has no input method -- an EditText inside one cannot be focused
 * or typed into on any Android version -- so the digits come from keys the
 * widget draws itself. Tapping an amount focuses that row; the keys append
 * to whichever row is focused; "−" and "+" record it.
 *
 * Recording happens here rather than by opening the app, which is the whole
 * point of the keypad. That means writing to Firestore from a broadcast
 * receiver, so the document is built by hand: its shape mirrors
 * Expense.toJson() in lib/models/expense.dart, and a Dart test asserts the
 * two agree. Which budget and which currency come from the app, which
 * mirrors them into preferences (see lib/data/widget_bridge.dart).
 *
 * When either is missing -- the app has never run, or the anonymous sign-in
 * has not happened -- the tap opens the app instead of failing quietly.
 */
class SolidusWidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_CYCLE = "com.baboevazamatkz.expense_tracker.WIDGET_CYCLE"
        const val ACTION_KEY = "com.baboevazamatkz.expense_tracker.WIDGET_KEY"
        const val ACTION_FOCUS = "com.baboevazamatkz.expense_tracker.WIDGET_FOCUS"
        const val ACTION_COMMIT = "com.baboevazamatkz.expense_tracker.WIDGET_COMMIT"
        const val ACTION_ADD = "com.baboevazamatkz.expense_tracker.WIDGET_ADD"

        const val EXTRA_TYPE = "solidus.type"
        const val EXTRA_CATEGORY = "solidus.category"
        private const val EXTRA_KEY = "solidus.key"

        private const val PREFS = "solidus_widget"
        private const val KEY_CATEGORY = "category_index"
        private const val KEY_FOCUS = "focus"
        private const val KEY_EXPENSE_AMOUNT = "amount_expense"
        private const val KEY_INCOME_AMOUNT = "amount_income"

        private const val TYPE_EXPENSE = "expense"
        private const val TYPE_INCOME = "income"

        /** Long enough for any real amount, short enough to stay in the pill. */
        private const val MAX_DIGITS = 12

        /** Mirrors ExpenseCategory in lib/models/expense_category.dart. */
        private val CATEGORY_KEYS = listOf(
            "food", "transport", "housing", "entertainment",
            "health", "shopping", "other",
        )
        private val CATEGORY_LABELS = listOf(
            "Еда", "Транспорт", "Жильё", "Развлечения",
            "Здоровье", "Покупки", "Другое",
        )

        /** The same glyphs ExpenseCategory carries inside the app. */
        private val CATEGORY_ICONS = listOf(
            R.drawable.w_cat_food,
            R.drawable.w_cat_transport,
            R.drawable.w_cat_housing,
            R.drawable.w_cat_entertainment,
            R.drawable.w_cat_health,
            R.drawable.w_cat_shopping,
            R.drawable.w_cat_other,
        )

        /** The label each key sends, against the view that sends it. */
        private val KEY_IDS = mapOf(
            "1" to R.id.w_key_1, "2" to R.id.w_key_2, "3" to R.id.w_key_3,
            "4" to R.id.w_key_4, "5" to R.id.w_key_5, "6" to R.id.w_key_6,
            "7" to R.id.w_key_7, "8" to R.id.w_key_8, "9" to R.id.w_key_9,
            "0" to R.id.w_key_0, "." to R.id.w_key_dot,
            "<" to R.id.w_key_del, "C" to R.id.w_key_clear,
            "000" to R.id.w_key_zeros,
        )

        private fun prefs(context: Context) =
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

        /** The app's own preferences, where the bridge leaves what we need. */
        private fun flutterPrefs(context: Context) =
            context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

        private fun householdCode(context: Context): String? =
            flutterPrefs(context).getString("flutter.widget_household_code", null)

        private fun currencyKey(context: Context): String =
            flutterPrefs(context).getString("flutter.widget_currency", null) ?: "rub"

        fun categoryIndex(context: Context): Int {
            val stored = prefs(context).getInt(KEY_CATEGORY, 0)
            return ((stored % CATEGORY_KEYS.size) + CATEGORY_KEYS.size) % CATEGORY_KEYS.size
        }

        private fun focus(context: Context): String =
            prefs(context).getString(KEY_FOCUS, TYPE_EXPENSE) ?: TYPE_EXPENSE

        private fun amountKey(type: String) =
            if (type == TYPE_INCOME) KEY_INCOME_AMOUNT else KEY_EXPENSE_AMOUNT

        private fun amount(context: Context, type: String): String =
            prefs(context).getString(amountKey(type), "") ?: ""

        /**
         * "1234567.5" -> "1 234 567.5".
         *
         * What is stored stays raw, so it still parses; only the face of the
         * pill is grouped. The separator is a plain space, matching
         * _groupThousands in lib/widgets/add_expense_sheet.dart -- a figure
         * typed into the widget and the same figure typed into the sheet
         * should not look like two different conventions.
         */
        fun grouped(raw: String): String {
            if (raw.isEmpty()) return raw
            val dot = raw.indexOf('.')
            val whole = if (dot == -1) raw else raw.substring(0, dot)
            val rest = if (dot == -1) "" else raw.substring(dot)
            val out = StringBuilder()
            for (i in whole.indices) {
                if (i > 0 && (whole.length - i) % 3 == 0) out.append(' ')
                out.append(whole[i])
            }
            return out.append(rest).toString()
        }

        fun redrawAll(context: Context, flash: String? = null) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, SolidusWidgetProvider::class.java)
            )
            for (id in ids) render(context, manager, id, flash)
        }

        private fun render(
            context: Context,
            manager: AppWidgetManager,
            widgetId: Int,
            flash: String? = null,
        ) {
            val views = RemoteViews(context.packageName, R.layout.widget_solidus)
            val focused = focus(context)
            val ready = householdCode(context) != null

            val category = categoryIndex(context)
            views.setImageViewResource(R.id.w_category, CATEGORY_ICONS[category])
            views.setInt(
                R.id.w_category,
                "setColorFilter",
                context.getColor(R.color.w_gold),
            )
            // The label is gone from the face of the chip, so it carries the
            // name for anyone reading the screen aloud.
            views.setContentDescription(R.id.w_category, CATEGORY_LABELS[category])

            for (type in listOf(TYPE_EXPENSE, TYPE_INCOME)) {
                val id = if (type == TYPE_EXPENSE) R.id.w_expense_amount
                else R.id.w_income_amount
                val typed = amount(context, type)
                views.setTextViewText(
                    id,
                    when {
                        typed.isNotEmpty() -> grouped(typed)
                        ready -> context.getString(R.string.w_amount_hint)
                        else -> context.getString(R.string.w_no_budget)
                    },
                )
                views.setInt(
                    id,
                    "setBackgroundResource",
                    if (type == focused) R.drawable.widget_field_focused
                    else R.drawable.widget_field,
                )
                views.setOnClickPendingIntent(
                    id,
                    broadcast(context, ACTION_FOCUS, type, mapOf(EXTRA_TYPE to type)),
                )
            }

            for ((label, viewId) in KEY_IDS) {
                views.setOnClickPendingIntent(
                    viewId,
                    broadcast(context, ACTION_KEY, label, mapOf(EXTRA_KEY to label)),
                )
            }

            // After a record the button wears a check for a second, which is
            // the only acknowledgement a widget can give: it cannot raise a
            // toast from the launcher's process, and the row it just wrote
            // is not on screen here.
            views.setTextViewText(
                R.id.w_add_expense,
                context.getString(
                    if (flash == TYPE_EXPENSE) R.string.w_check else R.string.w_minus
                ),
            )
            views.setTextViewText(
                R.id.w_add_income,
                context.getString(
                    if (flash == TYPE_INCOME) R.string.w_check else R.string.w_plus
                ),
            )
            views.setOnClickPendingIntent(
                R.id.w_add_expense,
                broadcast(context, ACTION_COMMIT, TYPE_EXPENSE, mapOf(EXTRA_TYPE to TYPE_EXPENSE)),
            )
            views.setOnClickPendingIntent(
                R.id.w_add_income,
                broadcast(context, ACTION_COMMIT, TYPE_INCOME, mapOf(EXTRA_TYPE to TYPE_INCOME)),
            )
            views.setOnClickPendingIntent(
                R.id.w_category,
                broadcast(context, ACTION_CYCLE, "cycle", emptyMap()),
            )

            manager.updateAppWidget(widgetId, views)
        }

        /**
         * Every one of these needs its own data uri. Without it they all
         * collapse onto a single PendingIntent and every key sends whatever
         * was registered last.
         */
        private fun broadcast(
            context: Context,
            action: String,
            tag: String,
            extras: Map<String, String>,
        ): PendingIntent {
            val intent = Intent(context, SolidusWidgetProvider::class.java).apply {
                this.action = action
                data = Uri.parse("solidus://$action/$tag")
                for ((k, v) in extras) putExtra(k, v)
            }
            return PendingIntent.getBroadcast(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        private fun openApp(context: Context, type: String): PendingIntent {
            val intent = Intent(context, MainActivity::class.java).apply {
                action = ACTION_ADD
                data = Uri.parse("solidus://add/$type")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra(EXTRA_TYPE, type)
                if (type == TYPE_EXPENSE) {
                    putExtra(EXTRA_CATEGORY, CATEGORY_KEYS[categoryIndex(context)])
                }
            }
            return PendingIntent.getActivity(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        private fun appendKey(context: Context, type: String, label: String) {
            val current = amount(context, type)
            val next = when {
                label == "C" -> ""
                label == "<" -> current.dropLast(1)
                label == "." ->
                    if (current.contains('.') || current.isEmpty()) current
                    else "$current."
                // Three zeros at once, which is what a sum is usually
                // reached by. Nothing to multiply yet, or already a
                // standalone zero, and it does nothing rather than
                // producing "000".
                label == "000" ->
                    if (current.isEmpty() || current == "0") current
                    else if (current.length + 3 > MAX_DIGITS) current
                    else current + "000"
                current.length >= MAX_DIGITS -> current
                // A leading zero is only meaningful before a decimal point.
                current == "0" -> label
                else -> current + label
            }
            prefs(context).edit().putString(amountKey(type), next).apply()
        }

        /** True when a record was written, which is what the check marks. */
        private fun commit(context: Context, type: String): Boolean {
            val typed = amount(context, type)
            val value = typed.toDoubleOrNull()
            val code = householdCode(context)
            val user = runCatching { FirebaseAuth.getInstance().currentUser }.getOrNull()

            if (value == null || value <= 0.0) {
                // Nothing typed: fall back to the sheet, which is what the
                // widget did before it had a keypad.
                openApp(context, type).send()
                return false
            }
            if (code == null || user == null) {
                openApp(context, type).send()
                return false
            }

            val document = mutableMapOf<String, Any?>(
                "id" to UUID.randomUUID().toString(),
                "amount" to value,
                "category" to if (type == TYPE_EXPENSE) {
                    CATEGORY_KEYS[categoryIndex(context)]
                } else {
                    null
                },
                "note" to "",
                "date" to Date(),
                "currency" to currencyKey(context),
                "type" to type,
            )
            FirebaseFirestore.getInstance()
                .collection("households")
                .document(code)
                .collection("expenses")
                .document(document["id"] as String)
                .set(document)

            prefs(context).edit().putString(amountKey(type), "").apply()
            return true
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
        render(context, manager, widgetId)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            ACTION_CYCLE ->
                prefs(context).edit()
                    .putInt(KEY_CATEGORY, categoryIndex(context) + 1)
                    .apply()

            ACTION_FOCUS ->
                prefs(context).edit()
                    .putString(KEY_FOCUS, intent.getStringExtra(EXTRA_TYPE) ?: TYPE_EXPENSE)
                    .apply()

            ACTION_KEY ->
                appendKey(
                    context,
                    focus(context),
                    intent.getStringExtra(EXTRA_KEY) ?: return,
                )

            ACTION_COMMIT -> {
                val type = intent.getStringExtra(EXTRA_TYPE) ?: TYPE_EXPENSE
                if (commit(context, type)) {
                    flashCheck(context, type)
                    return
                }
            }

            else -> return
        }
        redrawAll(context)
    }

    /**
     * Draws the check, waits a second, then draws the button again.
     *
     * goAsync is what keeps the process alive across that second: a
     * receiver is ordinarily allowed to die the moment onReceive returns,
     * and the redraw would never happen. The budget is around ten seconds,
     * so one is comfortably inside it.
     */
    private fun flashCheck(context: Context, type: String) {
        redrawAll(context, flash = type)
        val pending = goAsync()
        Handler(Looper.getMainLooper()).postDelayed({
            redrawAll(context)
            pending.finish()
        }, 1000L)
    }
}
