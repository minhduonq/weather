import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/helpTrans.dart';

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
      backgroundColor: const Color(0xFFEFEFEF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFEFEFEF),
        elevation: 0,
        centerTitle: true,
        title: Text(
          'settings'.tr,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          const SizedBox(height: 8),
          _buildCard([
            _buildTile(
              title: 'unit'.tr,
              trailing: Text(
                _temperatureUnit == 'C' ? '°C' : '°F',
                style: TextStyle(color: Colors.blue, fontSize: 14),
              ),
              onTap: () {
                _showUnitOptions();
              },
            ),
            _buildTile(
              title: 'use_current_location'.tr,
              trailing: Text(
                'continue'.tr,
                style: const TextStyle(color: Colors.blue, fontSize: 14),
              ),
              onTap: () {
                // Action for use current location
              },
            ),
            _buildSwitchTile(
              title: 'refresh_rate'.tr,
              value: true,
              onChanged: (val) {},
            ),
          ]),
          const SizedBox(height: 8),
          _buildCard([
            _buildSwitchTile(
              title: 'outside_app'.tr,
              value: _showOutsideApp,
              onChanged: (val) {
                setState(() {
                  _showOutsideApp = val;
                });
                _saveSetting('showOutsideApp', val);
              },
            ),
            _buildTile(
              title: 'notification'.tr,
              onTap: () {},
            ),
            _buildTile(
              title: 'custom_service'.tr,
              trailing: Text(
                'on'.tr,
                style: const TextStyle(color: Colors.blue, fontSize: 14),
              ),
              onTap: () {},
            ),
          ]),
          const SizedBox(height: 8),
          _buildCard([
            _buildTile(
              title: 'privacy'.tr,
              onTap: () {},
            ),
          ]),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      margin: EdgeInsets.zero,
      elevation: 1.5,
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildTile({
    required String title,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      dense: true,
      title: Text(
        title,
        style: const TextStyle(fontSize: 16),
      ),
      trailing: trailing,
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      dense: true,
      title: Text(
        title,
        style: const TextStyle(fontSize: 16),
      ),
      value: value,
      onChanged: onChanged,
    );
  }

  void _showUnitOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text('°C'),
            onTap: () {
              setState(() {
                _temperatureUnit = 'C';
              });
              _saveSetting('unit', 'C');
              Navigator.pop(context);
            },
          ),
          ListTile(
            title: Text('°F'),
            onTap: () {
              setState(() {
                _temperatureUnit = 'F';
              });
              _saveSetting('unit', 'F');
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
