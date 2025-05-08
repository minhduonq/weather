import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/constants.dart';
import '../services/database.dart';
import '../services/widget_service.dart';
import 'HomePage.dart';

class Setting extends StatefulWidget {
  const Setting({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _Setting();
}

extension TrText on String {
  Text get trText => Text(tr);
}


class _SettingsPageState extends State<SettingsPage> {
  String _selectedLanguage = 'vi';
  String _temperatureUnit = 'C';
  String _refreshRate = '3h';


  bool _showOutsideApp = false;
  bool _isDarkMode = true;


  @override
  void initState() {
    super.initState();
    _loadSettings(); // Load từ SharedPreferences khi mở trang
  }


  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedLanguage = prefs.getString('lang') ?? 'vi';
      _temperatureUnit = prefs.getString('unit') ?? 'C';
      _refreshRate = prefs.getString('refresh') ?? '3h';
    });
    Get.updateLocale(Locale(_selectedLanguage));
  }


  Future<void> _saveSetting(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text('Setting'),
        ),
        backgroundColor: Color(0xFFEFEFEF),
        body: ListView(
        children: [
          const SizedBox(height: 16),
          _buildDropdownTile(
            title: 'language'.tr,
            value: _selectedLanguage,
            subtitle:
                _selectedLanguage == 'vi' ? 'vietnamese'.tr : 'english'.tr,
            options: [
              PopupMenuItem(value: 'vi', child: Text('vietnamese'.tr)),
              PopupMenuItem(value: 'en', child: Text('english'.tr)),
            ],
            onSelected: (value) {
              setState(() {
                _selectedLanguage = value;
                Get.updateLocale(Locale(_selectedLanguage));
              });
              _saveSetting('lang', value);
            },
          ),
          _buildDropdownTile(
            title: 'unit'.tr,
            value: _temperatureUnit,
            subtitle: _temperatureUnit == 'C' ? 'celsius'.tr : 'fahrenheit'.tr,
            options: [
              PopupMenuItem(value: 'C', child: 'celsius'.trText),
              PopupMenuItem(value: 'F', child: 'fahrenheit'.trText),
            ],
            onSelected: (value) {
              setState(() {
                _temperatureUnit = value;
              });
              _saveSetting('unit', value);
            },
          ),
          _buildDropdownTile(
            title: 'refresh_rate'.tr,
            value: _refreshRate,
            subtitle: _refreshRate == '3h' ? 'every_3h'.tr : 'every_1h'.tr,
            options: [
              PopupMenuItem(value: '1h', child: 'every_1h'.trText),
              PopupMenuItem(value: '3h', child: 'every_3h'.trText),
            ],
            onSelected: (value) {
              setState(() {
                _refreshRate = value;
              });
              _saveSetting('refresh', value);
            },
          ),
          const Divider(height: 32),
          SwitchListTile(
            title: 'outside_app'.trText,
            value: _showOutsideApp,
            onChanged: (value) {
              setState(() {
                _showOutsideApp = value;
              });
            },
          ),
          Obx(
            () => SwitchListTile(
              title: 'theme'.trText,
              subtitle:
                  _themeController.isDarkMode.value
                      ? 'dark'.trText
                      : 'light'.trText,
              value: _themeController.isDarkMode.value,
              onChanged: (value) {
                _themeController.toggleTheme(value);
              },
            ),
          ),
          const Divider(height: 32),
          ListTile(title: 'rate'.trText, onTap: () {}),
          ListTile(title: 'privacy'.trText, onTap: () {}),
          ListTile(title: 'contact'.trText, onTap: () {}),
        ],
      ),
    );
  }


  Widget _buildDropdownTile({
    required String title,
    required String value,
    required String subtitle,
    required List<PopupMenuEntry<String>> options,
    required Function(String) onSelected,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: PopupMenuButton<String>(
        onSelected: onSelected,
        itemBuilder: (context) => options,
        icon: const Icon(Icons.more_vert),
      ),
    );
  }
}


  // Đây là một widget có thể thêm vào màn hình Setting
  Widget _buildDatabaseResetSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Database Management',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ListTile(
          leading: Icon(Icons.cleaning_services_outlined),
          title: Text('Clear Weather Data'),
          subtitle: Text('Keep locations but remove all weather data'),
          onTap: () async {
            bool confirm = await showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Clear Weather Data'),
                    content: Text(
                        'This will remove all weather data but keep your saved locations. Continue?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child:
                            Text('Clear', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ) ??
                false;

            if (confirm) {
              await DatabaseHelper().clearAllData();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Weather data cleared successfully!')),
              );
            }
          },
        ),
        ListTile(
          leading: Icon(Icons.restore, color: Colors.red),
          title: Text('Reset Database'),
          subtitle: Text('Remove all data including saved locations'),
          onTap: () async {
            bool confirm = await showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Reset Database'),
                    content: Text(
                        'This will completely reset the database and remove ALL data including your saved locations. This action cannot be undone. Continue?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child:
                            Text('Reset', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ) ??
                false;

            if (confirm) {
              await DatabaseHelper().resetDatabase();
              // Reset global variables
              LocationName = '';
              InitialName = '';
              KeyLocation = null;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Database reset successfully!')),
              );
              // Restart app or navigate back to home
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => HomePage()),
              );
            }
          },
        ),
      ],
    );
  }
}
