import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/constants.dart';
import '../services/database.dart';
import '../services/widget_service.dart';
import '../services/helpTrans.dart';
import 'HomePage.dart';

class Setting extends StatefulWidget {
  const Setting({Key? key}) : super(key: key);

  @override
  State<Setting> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<Setting> {
  String _selectedLanguage = 'vi';
  String _temperatureUnit = 'C';
  String _refreshRate = '3h';
  bool _showOutsideApp = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedLanguage = prefs.getString('lang') ?? 'vi';
      _temperatureUnit = prefs.getString('unit') ?? 'C';
      _refreshRate = prefs.getString('refresh') ?? '3h';
      _showOutsideApp = prefs.getBool('showOutsideApp') ?? false;
    });
    Get.updateLocale(Locale(_selectedLanguage));
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is String) {
      await prefs.setString(key, value);
    } else if (value is bool) {
      await prefs.setBool(key, value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: 'settings'.trText,
      ),
      backgroundColor: const Color(0xFFEFEFEF),
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
              _saveSetting('showOutsideApp', value);
            },
          ),
          const Divider(height: 32),
          ListTile(title: 'rate'.trText, onTap: () {}),
          ListTile(title: 'privacy'.trText, onTap: () {}),
          ListTile(title: 'contact'.trText, onTap: () {}),
          const Divider(height: 32),
          _buildDatabaseResetSection(),
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

  Widget _buildDatabaseResetSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Database Management',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.cleaning_services_outlined),
          title: const Text('Clear Weather Data'),
          subtitle: const Text('Keep locations but remove all weather data'),
          onTap: () async {
            bool confirm = await showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Clear Weather Data'),
                    content: const Text(
                        'This will remove all weather data but keep your saved locations. Continue?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Clear',
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ) ??
                false;

            if (confirm) {
              await DatabaseHelper().clearAllData();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Weather data cleared successfully!')),
              );
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.restore, color: Colors.red),
          title: const Text('Reset Database'),
          subtitle: const Text('Remove all data including saved locations'),
          onTap: () async {
            bool confirm = await showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Reset Database'),
                    content: const Text(
                        'This will completely reset the database and remove ALL data including your saved locations. This action cannot be undone. Continue?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Reset',
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ) ??
                false;

            if (confirm) {
              await DatabaseHelper().resetDatabase();
              LocationName = '';
              InitialName = '';
              KeyLocation = null;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Database reset successfully!')),
              );
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const HomePage()),
              );
            }
          },
        ),
      ],
    );
  }
}
