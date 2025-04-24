package com.example.frontend // Thay đổi theo package name của bạn

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

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

            // Cập nhật icon
            val weatherIcon = widgetData.getString("icon", "01d")
            val iconResourceId = getWeatherIconResource(weatherIcon ?: "01d", context)
            views.setImageViewResource(R.id.widget_icon, iconResourceId)

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