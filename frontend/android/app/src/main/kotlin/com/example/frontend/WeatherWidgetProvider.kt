package com.example.frontend

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetBackgroundIntent

class WeatherWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            // Lấy dữ liệu được lưu trữ bởi Flutter
            val widgetData = HomeWidgetPlugin.getData(context)
            val views = RemoteViews(context.packageName, R.layout.weather_widget)

            // Cập nhật dữ liệu lên widget
            views.setTextViewText(R.id.widget_location, widgetData.getString("location", "Location"))
            views.setTextViewText(R.id.widget_temperature, widgetData.getString("temperature", "--°"))
            views.setTextViewText(R.id.widget_description, widgetData.getString("description", "Weather description"))
            views.setTextViewText(R.id.widget_updated, widgetData.getString("updated", "Updated: --:--"))

            // Hiển thị thông tin gió
            views.setTextViewText(R.id.widget_wind, widgetData.getString("wind", "--km/h"))

            val iconCode = widgetData.getString("icon", null)
            Log.d("WeatherWidget", "Icon code from widgetData: $iconCode")

            if (iconCode != null) {
                try {
                    val resourceName = "weather_$iconCode" // Ví dụ: weather_04n
                    val resourceId = context.resources.getIdentifier(resourceName, "drawable", context.packageName)
                    if (resourceId != 0) {
                        views.setImageViewResource(R.id.widget_icon, resourceId)
                        Log.d("WeatherWidget", "Set icon from drawable: $resourceName for widget ID: $appWidgetId")
                    } else {
                        Log.e("WeatherWidget", "Drawable resource not found: $resourceName for widget ID: $appWidgetId. Setting default.")
                        views.setImageViewResource(R.id.widget_icon, R.drawable.weather_01d) // Icon mặc định của bạn
                    }
                } catch (e2: Exception) {
                    Log.e("WeatherWidget", "Error setting icon from drawable for widget ID: $appWidgetId - ${e2.message}. Setting default.")
                    views.setImageViewResource(R.id.widget_icon, R.drawable.weather_01d) // Icon mặc định
                }
            } else {
                Log.e("WeatherWidget", "Icon code is null. Setting default icon for widget ID: $appWidgetId.")
                views.setImageViewResource(R.id.widget_icon, R.drawable.weather_01d) // Icon mặc định
            }

            // Thêm PendingIntent để mở ứng dụng khi nhấn vào widget
            val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            val pendingIntent = PendingIntent.getActivity(context, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)

            // Cập nhật widget
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    private fun getWeatherIconResource(iconCode: String, context: Context): Int {
        val resourceName = "weather_$iconCode"
        val resourceId = context.resources.getIdentifier(resourceName, "drawable", context.packageName)
        return if (resourceId != 0) resourceId else R.drawable.weather_01d // fallback icon
    }
}