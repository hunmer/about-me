package github.hunmer.aboutme.widgets.services

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONObject
import github.hunmer.aboutme_widgets.R

/**
 * 本日活动详细视图小组件数据工厂
 *
 * 为ListView提供活动列表数据（带emoji和时长）
 */
class ActivityDailyRemoteViewsFactory(
    private val context: Context,
    intent: Intent
) : RemoteViewsService.RemoteViewsFactory {

    private val widgetId: Int = intent.getIntExtra(
        AppWidgetManager.EXTRA_APPWIDGET_ID,
        AppWidgetManager.INVALID_APPWIDGET_ID
    )

    // 活动项列表
    private var activityItems: List<ActivityItem> = emptyList()
    private var accentColor: Int = DEFAULT_ACCENT_COLOR

    data class ActivityItem(
        val name: String,
        val emoji: String,
        val duration: String,
        val color: Int
    )

    override fun onCreate() {
        loadData()
    }

    override fun onDataSetChanged() {
        loadData()
    }

    override fun onDestroy() {
        activityItems = emptyList()
    }

    override fun getCount(): Int = activityItems.size

    override fun getViewAt(position: Int): RemoteViews {
        if (position >= activityItems.size) {
            return getLoadingView()
        }

        val item = activityItems[position]
        val views = RemoteViews(context.packageName, R.layout.widget_activity_daily_item)

        // 设置颜色圆点
        views.setInt(R.id.activity_color_dot, "setBackgroundColor", item.color)

        // 设置emoji
        views.setTextViewText(R.id.activity_emoji, item.emoji)

        // 设置活动名称
        views.setTextViewText(R.id.activity_name, item.name)

        // 设置时长
        views.setTextViewText(R.id.activity_duration, item.duration)

        // 设置点击事件
        val fillIntent = Intent().apply {
            putExtra("tag_name", item.name)
        }
        views.setOnClickFillInIntent(R.id.item_root, fillIntent)

        return views
    }

    override fun getLoadingView(): RemoteViews {
        return RemoteViews(context.packageName, R.layout.widget_activity_daily_item).apply {
            setTextViewText(R.id.activity_name, "加载中...")
            setTextViewText(R.id.activity_duration, "")
            setTextViewText(R.id.activity_emoji, "")
        }
    }

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long = position.toLong()

    override fun hasStableIds(): Boolean = true

    /**
     * 从SharedPreferences加载数据
     */
    private fun loadData() {
        try {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val dataJson = prefs.getString("activity_daily_data_$widgetId", null)

            android.util.Log.d(TAG, "Loading data for widget $widgetId: ${if (dataJson.isNullOrEmpty()) "null or empty" else "${dataJson.length} chars"}")

            if (dataJson.isNullOrEmpty()) {
                activityItems = emptyList()
                return
            }

            val json = JSONObject(dataJson)
            val config = json.getJSONObject("config")
            val data = json.getJSONObject("data")

            android.util.Log.d(TAG, "Parsed JSON config and data")

            // 读取强调色
            accentColor = config.getString("accentColor").toLongOrNull()?.toInt()
                ?: DEFAULT_ACCENT_COLOR

            // 解析活动列表（使用 optJSONArray 避免异常）
            val activities = data.optJSONArray("activities")
            val items = mutableListOf<ActivityItem>()

            if (activities != null) {
                android.util.Log.d(TAG, "Found ${activities.length()} activities")
                for (i in 0 until activities.length()) {
                    val activity = activities.getJSONObject(i)
                    val name = activity.getString("name")
                    val emoji = activity.optString("emoji", "📋")
                    val duration = activity.getString("duration")
                    val color = activity.optLong("color", accentColor.toLong()).toInt()

                    items.add(ActivityItem(
                        name = name,
                        emoji = emoji,
                        duration = duration,
                        color = color
                    ))
                }
            } else {
                android.util.Log.w(TAG, "No 'activities' field found in data")
            }

            activityItems = items
            android.util.Log.d(TAG, "Loaded ${items.size} activity items for widget $widgetId")
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Error loading data: $e", e)
            activityItems = emptyList()
        }
    }

    companion object {
        private const val TAG = "ActivityDailyFactory"
        private const val PREFS_NAME = "HomeWidgetPreferences"
        private const val DEFAULT_ACCENT_COLOR = 0xFF1F2937.toInt()
    }
}
