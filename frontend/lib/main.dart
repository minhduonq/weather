import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:frontend/screens/HomePage.dart';
import 'package:frontend/screens/LocationManage.dart';
import 'package:frontend/screens/weather_stogare.dart';
<<<<<<< HEAD
import 'package:frontend/services/notification_service.dart';
=======
import 'package:frontend/services/translations.dart';
//import 'package:frontend/services/widget_service.dart';
>>>>>>> 5ac083889d9a16af0cc6cec4a1db08759213a99e

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
<<<<<<< HEAD
    return MaterialApp(
        debugShowCheckedModeBanner: false,
        // home: WeatherStorageScreen(),
        home: HomePage());
=======
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomePage(),
      translations: AppTranslations(),
      locale: Locale('vi'),
      fallbackLocale: Locale('en'),
    );
>>>>>>> 5ac083889d9a16af0cc6cec4a1db08759213a99e
  }
}
