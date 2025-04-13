import 'package:get/get.dart';

class AppTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
    'en': {
      'settings': 'Settings',
      'language': 'Language',
      'temperature_unit': 'Temperature Unit',
    },
    'vi': {
      'settings': 'Cài đặt',
      'language': 'Ngôn ngữ',
      'temperature_unit': 'Đơn vị nhiệt độ',
    },
  };
}
