import 'package:flutter/material.dart';
import 'package:frontend/services/location_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import '../services/constants.dart';
import '../services/weather_service.dart';
import '../services/formatting_service.dart';
import 'dart:developer';

class WeatherWidgetService {
  static const String appGroupId = 'com.example.frontend.weatherWidget';

  //

  static Future<void> updateWeatherWidget() async {
    try {
      // More comprehensive check for weather data
      if (KeyLocation != null &&
          WeatherService.currentData.isNotEmpty &&
          WeatherService.currentData['main'] != null &&
          WeatherService.currentData['weather'] != null &&
          WeatherService.currentData['weather'].isNotEmpty) {
        final weatherData = WeatherService.currentData;
        final location = LocationName ?? 'Unknown Location';
        final temp = '${weatherData['main']['temp'].round()}°';
        final description = weatherData['weather'][0]['description'];
        final icon = weatherData['weather'][0]['icon'];
        final windSpeed = weatherData['wind']['speed'];
        final windInfo = '${windSpeed.toStringAsFixed(1)}km/h';

        final now = DateTime.now();
        final updatedText = 'Updated: ${DateFormat('HH:mm').format(now)}';

        // Update the widget data
        await HomeWidget.saveWidgetData<String>('location', location);
        await HomeWidget.saveWidgetData<String>('temperature', temp);
        await HomeWidget.saveWidgetData<String>(
            'description', FormattingService.capitalize(description));
        await HomeWidget.saveWidgetData<String>('updated', updatedText);
        await HomeWidget.saveWidgetData<String>('wind', windInfo);

        log('Weather icon to be saved: $icon');
        await HomeWidget.saveWidgetData<String>('icon', icon);

        // Request an update for the widget
        await HomeWidget.updateWidget(
          name: 'WeatherWidgetProvider',
          androidName: 'WeatherWidgetProvider', // Không thêm package 2 lần
        );

        log('Weather widget updated successfully');
      } else {
        log('Cannot update widget: weather data is not available or incomplete');
      }
    } catch (e) {
      log('Error updating weather widget: $e');
    }
  }

  // Call this when fetching fresh weather data
  static Future<void> triggerWidgetUpdate() async {
    try {
      if (KeyLocation != null) {
        // Get fresh data
        await WeatherService.loadWeatherData(
            KeyLocation!.latitude, KeyLocation!.longitude);
        await updateWeatherWidget();
      } else {
        // Try to get current location
        Position? position = await LocationService.getCurrentLocation();
        if (position != null) {
          KeyLocation = position;
          await WeatherService.loadWeatherData(
              position.latitude, position.longitude);
          await updateWeatherWidget();
        }
      }
    } catch (e) {
      print('Error triggering widget update: $e');
    }
  }
}
