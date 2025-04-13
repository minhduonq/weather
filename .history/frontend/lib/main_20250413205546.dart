import 'package:flutter/material.dart';
import 'package:frontend/setting/settings_page.dart';
import 'package:get/get.dart';
import 'package:frontend/screens/HomePage.dart';
import 'package:frontend/setting/language/translations.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      translations: AppTranslations(),
      locale: const Locale('vi', 'VN'),
      fallbackLocale: const Locale('en', 'US'),
      home: const SettingsPage(),
    );
  }
}
