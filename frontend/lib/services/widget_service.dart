// import 'package:home_widget/home_widget.dart';
// //import 'package:workmanager/workmanager.dart';
// import 'package:frontend/services/database.dart';
// import '../services/constants.dart';
//
// class WidgetService {
//   static const String widgetUpdateTask = 'weatherWidgetUpdate';
//
//   static Future<void> initWidgetService() async {
//     // Khởi tạo Workmanager để cập nhật widget định kỳ
//     //Workmanager().initialize(callbackDispatcher);
//     // Đăng ký công việc định kỳ để cập nhật widget (mỗi 30 phút)
//     // Workmanager().registerPeriodicTask(
//     //   widgetUpdateTask,
//     //   widgetUpdateTask,
//     //   frequency: Duration(minutes: 30),
//     // );
//   }
//
//   static Future<void> updateWidgetData() async {
//     final dbHelper = DatabaseHelper();
//
//     // Lấy thông tin vị trí hiện tại
//     String? location = LocationName;
//
//     // Lấy dữ liệu thời tiết hiện tại từ DB hoặc biến toàn cục
//     if (KeyLocation != null) {
//       final locations = await dbHelper.getAllLocations();
//       int? locationId;
//
//       for (var loc in locations) {
//         if (loc['name'] == location) {
//           locationId = loc['id'];
//           break;
//         }
//       }
//
//       if (locationId != null) {
//         final weatherDataList = await dbHelper.getWeatherDataByLocationId(locationId);
//
//         if (weatherDataList.isNotEmpty) {
//           final weatherData = weatherDataList.first;
//
//           // Cập nhật dữ liệu lên widget
//           await HomeWidget.saveWidgetData('location', location);
//           await HomeWidget.saveWidgetData(
//               'temperature', '${weatherData['temperature'].round()}°');
//           await HomeWidget.saveWidgetData(
//               'description', capitalizeFirstLetter(weatherData['description']));
//           await HomeWidget.saveWidgetData('icon', weatherData['icon']);
//
//           final now = DateTime.now();
//           final timeString = '${now.hour}:${now.minute.toString().padLeft(2, '0')}';
//           await HomeWidget.saveWidgetData('updated', 'Updated: $timeString');
//
//           // Yêu cầu cập nhật widget
//           await HomeWidget.updateWidget(
//             androidName: 'WeatherWidgetProvider',
//           );
//         }
//       }
//     }
//   }
//
//   static String capitalizeFirstLetter(String text) {
//     if (text.isEmpty) return text;
//     return text[0].toUpperCase() + text.substring(1);
//   }
// }
//
// // Callback phải ở cấp độ hàng đầu (top-level function)
// @pragma('vm:entry-point')
// void callbackDispatcher() {
//   Workmanager().executeTask((task, inputData) async {
//     if (task == WidgetService.widgetUpdateTask) {
//       await WidgetService.updateWidgetData();
//     }
//     return Future.value(true);
//   });
// }