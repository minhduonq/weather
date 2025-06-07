import 'package:flutter/material.dart';
import 'package:frontend/provider/location_notifier.dart';
import 'package:frontend/services/database.dart';
import 'package:frontend/services/notification_service.dart';
import 'package:get/get.dart';
import 'package:frontend/screens/HomePage.dart';
import 'package:frontend/screens/weather_stogare.dart';
import 'package:frontend/services/translations.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services
  try {
    await DatabaseHelper().initDatabase();
    await NotificationService().init();
    await NotificationService().requestNotificationPermissions();
  } catch (e) {
    print("Lỗi khi khởi tạo dịch vụ: $e");
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocationNotifier()),
        Provider(create: (_) => DatabaseHelper()),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomePage(),
      translations: AppTranslations(),
      locale: const Locale('vi'),
      fallbackLocale: const Locale('en'),
      routes: {
        '/home': (context) => HomePage(),
        '/weather_storage': (context) => WeatherStorageScreen(),
      },
    );
  }
}
