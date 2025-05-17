import 'package:flutter/material.dart';
import 'package:frontend/services/database.dart';
import 'package:frontend/services/notification_service.dart';
import 'package:get/get.dart';
import 'package:frontend/screens/HomePage.dart';
import 'package:frontend/screens/weather_stogare.dart';
import 'package:frontend/services/translations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Khởi tạo các dịch vụ cần thiết
  try {
    // Khởi tạo database helper
    await DatabaseHelper().initDatabase();

    // Khởi tạo notification service
    await NotificationService().init();
    await NotificationService().requestNotificationPermissions();

    // Khởi tạo các dịch vụ khác nếu cần
    // await WidgetService.initWidgetService();
  } catch (e) {
    print("Lỗi khi khởi tạo dịch vụ: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
