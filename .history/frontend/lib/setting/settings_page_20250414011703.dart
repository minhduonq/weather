import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _selectedLanguage = 'vi';
  String _temperatureUnit = 'C';
  String _refreshRate = '3h';

  bool _showOutsideApp = true;
  bool _isDarkMode = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt')),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          _buildDropdownTile(
            title: 'Ngôn ngữ',
            value: _selectedLanguage,
            subtitle: _selectedLanguage == 'vi' ? 'Tiếng Việt' : 'English',
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
          _buildDropdownTile(
            title: 'Đơn vị',
            value: _temperatureUnit,
            subtitle: _temperatureUnit == 'C' ? '°C' : '°F',
            items: const [
              DropdownMenuItem(value: 'C', child: Text('Celsius (°C)')),
              DropdownMenuItem(value: 'F', child: Text('Fahrenheit (°F)')),
            ],
            onChanged: (value) {
              setState(() {
                _temperatureUnit = value!;
                // TODO: Update logic
              });
            },
          ),
          _buildDropdownTile(
            title: 'Tự động làm mới',
            value: _refreshRate,
            subtitle: _refreshRate == '3h' ? 'Mỗi 3 giờ' : 'Mỗi 1 giờ',
            items: const [
              DropdownMenuItem(value: '1h', child: Text('Mỗi 1 giờ')),
              DropdownMenuItem(value: '3h', child: Text('Mỗi 3 giờ')),
            ],
            onChanged: (value) {
              setState(() {
                _refreshRate = value!;
              });
            },
          ),
          const Divider(height: 32),
          SwitchListTile(
            title: const Text('H.thị ngoài màn hình ứng dụng'),
            value: _showOutsideApp,
            onChanged: (value) {
              setState(() {
                _showOutsideApp = value;
              });
            },
          ),
          SwitchListTile(
            title: const Text('Giao diện hiện thị'),
            subtitle: Text(_isDarkMode ? 'Tối' : 'Sáng'),
            value: _isDarkMode,
            onChanged: (value) {
              setState(() {
                _isDarkMode = value;
                // TODO: update theme mode
              });
            },
          ),
          const Divider(height: 32),
          ListTile(
            title: const Text('Đánh giá'),
            onTap: () {
              // TODO: Link to app store
            },
          ),
          ListTile(
            title: const Text('Chính sách riêng'),
            onTap: () {
              // TODO: Open privacy policy
            },
          ),
          ListTile(
            title: const Text('Liên hệ chúng tôi'),
            onTap: () {
              // TODO: Contact us logic
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownTile({
    required String title,
    required String value,
    required String subtitle,
    required List<DropdownMenuItem<String>> items,
    required Function(String?) onChanged,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: DropdownButton<String>(
        value: value,
        items: items,
        onChanged: onChanged,
        underline: const SizedBox(),
      ),
    );
  }
}
