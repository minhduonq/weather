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
      appBar: AppBar(
        title: Text(
          'settings'.tr,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
        backgroundColor: Colors.grey.shade300,
        elevation: 0,
      ),
      backgroundColor: Colors.grey.shade300,
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 18),
        children: [
          _buildCard([
            _buildDropdownTile(
              title: 'language'.tr,
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
              subtitle:
                  _temperatureUnit == 'C' ? 'celsius'.tr : 'fahrenheit'.tr,
              options: [
                PopupMenuItem(value: 'C', child: Text('celsius'.tr)),
                PopupMenuItem(value: 'F', child: Text('fahrenheit'.tr)),
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
              subtitle: _refreshRate == '3h' ? 'every_3h'.tr : 'every_1h'.tr,
              options: [
                PopupMenuItem(value: '1h', child: Text('every_1h'.tr)),
                PopupMenuItem(value: '3h', child: Text('every_3h'.tr)),
              ],
              onSelected: (value) {
                setState(() {
                  _refreshRate = value;
                });
                _saveSetting('refresh', value);
              },
            ),
          ]),
          const SizedBox(height: 18),
          _buildCard([
            SwitchListTile(
              title: Text(
                'outside_app'.tr,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1,
                ),
              ),
              value: _showOutsideApp,
              onChanged: (value) {
                setState(() {
                  _showOutsideApp = value;
                });
                _saveSetting('showOutsideApp', value);
              },
            ),
            ListTile(
              title: Text(
                'notification'.tr,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1,
                ),
              ),
              onTap: () {},
            ),
          ]),
          const SizedBox(height: 18),
          _buildCard([
            ListTile(
              title: Text(
                'rate'.tr,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1,
                ),
              ),
              onTap: () {},
            ),
            ListTile(
              title: Text(
                'privacy'.tr,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1,
                ),
              ),
              onTap: () {},
            ),
            ListTile(
              title: Text(
                'contact'.tr,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1,
                ),
              ),
              onTap: () {},
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildDropdownTile({
    required String title,
    required String subtitle,
    required List<PopupMenuEntry<String>> options,
    required Function(String) onSelected,
  }) {
    return ListTile(
      title: trWithStyle(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          letterSpacing: 1,
        ),
      ),
      subtitle: trWithStyle(
        subtitle,
        style: const TextStyle(
          fontSize: 12,
          color: Colors.blue,
        ),
      ),
      trailing: PopupMenuButton<String>(
        onSelected: onSelected,
        itemBuilder: (context) => options,
        icon: const Icon(Icons.more_vert),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      elevation: 2,
      child: Column(
        children: List.generate(children.length * 2 - 1, (index) {
          if (index.isEven) {
            return children[index ~/ 2];
          } else {
            return const Divider(
              height: 1,
              thickness: 1,
              indent: 15,
              endIndent: 15,
            );
          }
        }),
      ),
    );
  }
}
