import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _selectedLanguage =
      Get.locale?.languageCode ?? 'vi'; // Sử dụng Get.locale nếu có
  String _temperatureUnit = 'C';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ngôn ngữ'.tr,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            DropdownButton<String>(
              value: _selectedLanguage,
              items: const [
                DropdownMenuItem(value: 'vi', child: Text('Tiếng Việt')),
                DropdownMenuItem(value: 'en', child: Text('English')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedLanguage = value!;
                  Get.updateLocale(Locale(_selectedLanguage));
                });
              },
            ),
            const SizedBox(height: 32),
            Text(
              'Đơn vị nhiệt độ'.tr,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            DropdownButton<String>(
              value: _temperatureUnit,
              items: const [
                DropdownMenuItem(value: 'C', child: Text('Celsius (°C)')),
                DropdownMenuItem(value: 'F', child: Text('Fahrenheit (°F)')),
              ],
              onChanged: (value) {
                setState(() {
                  _temperatureUnit = value!;
                  // TODO: Cập nhật đơn vị nhiệt độ
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}
