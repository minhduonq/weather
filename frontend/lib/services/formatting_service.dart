import 'package:get/get.dart';

class FormattingService {
  // Format epoch time to readable time string
  static String formatEpochTimeToTime(
      int epochTime, int timezoneOffsetInSeconds) {
    DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(
      (epochTime + timezoneOffsetInSeconds) * 1000,
      isUtc: true,
    );
    String formattedTime =
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    return formattedTime;
  }

  // Get day name from epoch time with translation
  static String getDayName(int timestamp) {
    final DateTime dateTime =
        DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final int weekday = dateTime.weekday;

    const List<String> dayKeys = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];

    return dayKeys[weekday - 1].tr; // Dùng key để dịch theo ngôn ngữ hiện tại
  }

  // Get weather icon path
  static String getWeatherIconPath(String iconCode) {
    return 'assets/svgs/$iconCode.svg';
  }

  // Capitalize first letter of text
  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}
