import 'package:get/get.dart';

class FormattingService {
  // Format epoch time to readable time string
  static String formatEpochTimeToTime(
      int epochTime, int timezoneOffsetInSeconds) {
    // Add timezone offset to convert to local time
    DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(
      (epochTime + timezoneOffsetInSeconds) * 1000,
      isUtc: true, // because epoch time from API is UTC
    );

    String formattedTime =
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    return formattedTime;
  }

  // Get day name from epoch time
  static String getDayName(int epochTime) {
    DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(epochTime * 1000);

    final isVietnamese = Get.locale?.languageCode == 'vi';

    if (isVietnamese) {
      List<String> weekdaysVi = [
        'Thứ Hai',
        'Thứ Ba',
        'Thứ Tư',
        'Thứ Năm',
        'Thứ Sáu',
        'Thứ Bảy',
        'Chủ Nhật',
      ];
      return weekdaysVi[dateTime.weekday - 1];
    } else {
      List<String> weekdaysEn = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      return weekdaysEn[dateTime.weekday - 1];
    }
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
