import 'package:get/get.dart';

class AppTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
    'vi_VN': {
      'settings': 'Cài đặt',
      'language': 'Ngôn ngữ',
      'temperature_unit': 'Đơn vị nhiệt độ',
      'vietnamese': 'Tiếng Việt',
      'english': 'English',
      'celsius': 'Celsius (°C)',
      'fahrenheit': 'Fahrenheit (°F)',
    },
    'en_US': {
      'settings': 'Settings',
      'language': 'Language',
      'temperature_unit': 'Temperature Unit',
      'vietnamese': 'Vietnamese',
      'english': 'English',
      'celsius': 'Celsius (°C)',
      'fahrenheit': 'Fahrenheit (°F)',
    },
  };
}
