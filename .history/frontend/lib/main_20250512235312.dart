import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:frontend/screens/HomePage.dart';
import 'package:frontend/screens/weather_stogare.dart';
import 'package:frontend/services/translations.dart';
//import 'package:frontend/services/widget_service.dart';

void main() async {
  //WidgetsFlutterBinding.ensureInitialized();
  //await WidgetService.initWidgetService();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomePage(),
      translations: AppTranslations(),
      locale: Locale('vi'),
      fallbackLocale: Locale('en'),
    );
  }
}
