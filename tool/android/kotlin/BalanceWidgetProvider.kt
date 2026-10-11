package com.lumio.pockettally

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Home screen widget: this month's balance and a + button.
 * The texts are written by the app (lib/android_extras.dart) whenever
 * the data changes.
 */
class BalanceWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.balance_widget).apply {
                setTextViewText(R.id.widget_title, widgetData.getString("title", "PocketTally"))
                setTextViewText(R.id.widget_balance, widgetData.getString("balance", "—"))
                setTextViewText(R.id.widget_detail, widgetData.getString("detail", ""))
                setOnClickPendingIntent(
                    R.id.widget_root,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
                )
                setOnClickPendingIntent(
                    R.id.widget_add,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("pockettally://add"),
                    ),
                )
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
