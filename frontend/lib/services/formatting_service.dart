class FormattingService {
  // Format epoch time to readable time string
  static String formatEpochTimeToTime(int epochTime, int timezoneOffsetInSeconds) {
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
  static String getDayName(int timestamp) {
    // Tạo DateTime từ timestamp
    final DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);

    // Lấy ngày trong tuần
    final int weekday = dateTime.weekday;

    // Map số thành tên ngày
    const List<String> dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

    return dayNames[weekday - 1]; // weekday bắt đầu từ 1
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