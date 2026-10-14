package com.lumio.pockettally

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

/** The big home screen widget: balance, income, expenses and two buttons. */
class BalanceWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        WidgetUpdater.update(context, manager, ids, small = false)
    }
}

/** The small home screen widget: balance and - / + buttons. */
class BalanceWidgetSmallProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        WidgetUpdater.update(context, manager, ids, small = true)
    }
}

/**
 * Fills the widgets with the texts the app saved in its settings
 * (keys "widget_..."; see AppState.syncWidget in Dart). The widgets never
 * read the database themselves.
 */
object WidgetUpdater {
    /** Where Flutter's shared_preferences keeps its values. */
    private const val PREFS = "FlutterSharedPreferences"

    fun updateAll(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        update(
            context, manager,
            manager.getAppWidgetIds(ComponentName(context, BalanceWidgetProvider::class.java)),
            small = false,
        )
        update(
            context, manager,
            manager.getAppWidgetIds(ComponentName(context, BalanceWidgetSmallProvider::class.java)),
            small = true,
        )
    }

    fun update(context: Context, manager: AppWidgetManager, ids: IntArray, small: Boolean) {
        if (ids.isEmpty()) return
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        fun text(key: String, fallback: String): String =
            try {
                prefs.getString("flutter.$key", null) ?: fallback
            } catch (e: Exception) {
                fallback
            }

        for (id in ids) {
            // One broken widget (a removed view, a full system) must never stop the others or crash the app.
            try {
                val layout = if (small) R.layout.balance_widget_small else R.layout.balance_widget
                val views = RemoteViews(context.packageName, layout)
                views.setTextViewText(R.id.widget_title, text("widget_title", "PocketTally"))
                if (small) {
                    views.setTextViewText(R.id.widget_balance, text("widget_balance_short", "—"))
                } else {
                    views.setTextViewText(R.id.widget_balance, text("widget_balance", "—"))
                    views.setTextViewText(R.id.widget_income, text("widget_income", ""))
                    views.setTextViewText(R.id.widget_expense, text("widget_expense", ""))
                    views.setTextViewText(R.id.widget_add_expense, text("widget_label_expense", "− Expense"))
                    views.setTextViewText(R.id.widget_add_income, text("widget_label_income", "+ Income"))
                }
                views.setOnClickPendingIntent(R.id.widget_root, launch(context, null, 0))
                views.setOnClickPendingIntent(R.id.widget_add_expense, launch(context, "expense", 1))
                views.setOnClickPendingIntent(R.id.widget_add_income, launch(context, "income", 2))
                manager.updateAppWidget(id, views)
            } catch (e: Exception) {
                // Keep the old picture on this widget; it is drawn again at the next update.
            }
        }
    }

    /** Opens the app; with [action] it opens the expense or income form. */
    private fun launch(context: Context, action: String?, requestCode: Int): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            if (action != null) putExtra(MainActivity.EXTRA_ACTION, action)
        }
        return PendingIntent.getActivity(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
