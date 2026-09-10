package app.localfirst.goal_tracker_poc

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray

class GoalCardsWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val cards = runCatching {
            JSONArray(widgetData.getString("goal_cards_json", "[]"))
        }.getOrElse { JSONArray() }

        appWidgetIds.forEach { widgetId ->
            val options = appWidgetManager.getAppWidgetOptions(widgetId)
            val minHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT)
            val capacity = when {
                minHeight < 170 -> 3
                minHeight < 280 -> 5
                else -> 8
            }
            val views = RemoteViews(context.packageName, R.layout.widget_goal_cards)
            views.removeAllViews(R.id.cards_container)
            val count = minOf(cards.length(), capacity)
            views.setViewVisibility(
                R.id.empty_cards,
                if (count == 0) View.VISIBLE else View.GONE,
            )
            for (index in 0 until count) {
                val card = cards.getJSONObject(index)
                val row = RemoteViews(context.packageName, R.layout.widget_goal_row)
                val name = card.optString("name", "Goal")
                val category = card.optString("category", "")
                val progressText = card.optString("progress_text", "")
                val progress = (card.optDouble("progress", 0.0) * 100).toInt()
                row.setTextViewText(R.id.goal_title, name)
                row.setTextViewText(R.id.goal_category, category)
                row.setViewVisibility(
                    R.id.goal_category,
                    if (category.isBlank()) View.GONE else View.VISIBLE,
                )
                row.setTextViewText(R.id.goal_progress_text, progressText)
                row.setViewVisibility(
                    R.id.goal_progress_text,
                    if (progressText.isBlank()) View.GONE else View.VISIBLE,
                )
                row.setProgressBar(R.id.goal_progress, 100, progress, false)
                row.setViewVisibility(
                    R.id.urgent_icon,
                    if (card.optBoolean("urgent", false)) View.VISIBLE else View.GONE,
                )
                val id = Uri.encode(card.optString("id"))
                row.setOnClickPendingIntent(
                    R.id.goal_row,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("goaltracker://goal?id=$id"),
                    ),
                )
                views.addView(R.id.cards_container, row)
            }
            views.setOnClickPendingIntent(
                R.id.widget_header,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
            )
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}

class TodayWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val actions = runCatching {
            JSONArray(widgetData.getString("today_actions_json", "[]"))
        }.getOrElse { JSONArray() }

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_today)
            views.setTextViewText(R.id.widget_title, "Today")
            views.removeAllViews(R.id.actions_container)
            val count = minOf(actions.length(), 3)
            views.setViewVisibility(
                R.id.empty_actions,
                if (count == 0) View.VISIBLE else View.GONE,
            )
            for (index in 0 until count) {
                val action = actions.getJSONObject(index)
                val row = RemoteViews(context.packageName, R.layout.widget_today_row)
                row.setTextViewText(R.id.action_title, action.optString("action"))
                row.setTextViewText(R.id.action_goal, action.optString("name"))
                val id = Uri.encode(action.optString("id"))
                val type = Uri.encode(action.optString("type", "goal"))
                val date = Uri.encode(action.optString("date", ""))
                row.setOnClickPendingIntent(
                    R.id.action_copy,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("goaltracker://${if (type == "task") "task" else "goal"}?id=$id"),
                    ),
                )
                row.setOnClickPendingIntent(
                    R.id.action_done,
                    HomeWidgetBackgroundIntent.getBroadcast(
                        context,
                        Uri.parse("goaltracker://done?id=$id&type=$type&date=$date"),
                    ),
                )
                views.addView(R.id.actions_container, row)
            }
            views.setOnClickPendingIntent(
                R.id.widget_header,
                HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("goaltracker://today"),
                ),
            )
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}

class CalendarWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val items = runCatching {
            JSONArray(widgetData.getString("calendar_schedule_json", "[]"))
        }.getOrElse { JSONArray() }

        appWidgetIds.forEach { widgetId ->
            val options = appWidgetManager.getAppWidgetOptions(widgetId)
            val minHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT)
            val capacity = when {
                minHeight < 150 -> 2
                minHeight < 260 -> 4
                else -> 7
            }
            val views = RemoteViews(context.packageName, R.layout.widget_today)
            views.setTextViewText(R.id.widget_title, "Calendar")
            views.removeAllViews(R.id.actions_container)
            val count = minOf(items.length(), capacity)
            views.setViewVisibility(
                R.id.empty_actions,
                if (count == 0) View.VISIBLE else View.GONE,
            )
            views.setTextViewText(R.id.empty_actions, "Nothing scheduled.")
            for (index in 0 until count) {
                val item = items.getJSONObject(index)
                val row = RemoteViews(context.packageName, R.layout.widget_today_row)
                row.setTextViewText(R.id.action_title, item.optString("title"))
                row.setTextViewText(R.id.action_goal, item.optString("time"))
                row.setViewVisibility(R.id.action_done, View.GONE)
                row.setOnClickPendingIntent(
                    R.id.action_copy,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("goaltracker://calendar"),
                    ),
                )
                views.addView(R.id.actions_container, row)
            }
            views.setOnClickPendingIntent(
                R.id.widget_header,
                HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("goaltracker://calendar"),
                ),
            )
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
