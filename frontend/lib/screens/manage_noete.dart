import 'package:flutter/material.dart';
import 'package:frontend/models/note_model.dart';
import 'package:frontend/services/constants.dart';
import 'package:frontend/services/database.dart';
import 'package:frontend/services/notification_service.dart';
import 'package:frontend/services/weather_service.dart';
import 'package:frontend/services/formatting_service.dart';
import 'package:frontend/services/location_service.dart';
import 'add_note_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sqflite/sqflite.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ManageNote extends StatefulWidget {
  @override
  _ManageNoteState createState() => _ManageNoteState();
}

class _ManageNoteState extends State<ManageNote> {
  late DatabaseHelper databaseHelper;
  List<Note> notes = [];
  bool notificationEnabled = true;
  TimeOfDay notificationTime = const TimeOfDay(hour: 20, minute: 0);
  DateTime notificationDate = DateTime.now();
  List<Map<String, dynamic>> _locations = [];

  @override
  void initState() {
    super.initState();
    databaseHelper = DatabaseHelper();
    NotificationService().init();
    _loadNotes();
    _loadSettings();
    _loadSavedLocations();
    _ensureDatabaseSchema();
    NotificationService().requestNotificationPermissions();
  }

  Future<void> _ensureDatabaseSchema() async {
    try {
      final db = await databaseHelper.database;
      final columns = await db.rawQuery('PRAGMA table_info(setting)');
      bool hasNotificationDate =
          columns.any((col) => col['name'] == 'notification_date');

      if (!hasNotificationDate) {
        await db
            .execute('ALTER TABLE setting ADD COLUMN notification_date TEXT');
        print('Added notification_date column to setting table');
      }
    } catch (e) {
      print('Error updating database schema: $e');
    }
  }

  void _loadNotes() async {
    List<Note> loadedNotes = await databaseHelper.getNotes();
    setState(() {
      notes = loadedNotes;
    });
  }

  void _deleteNote(int id) async {
    await databaseHelper.deleteNote(id);
    _loadNotes();
  }

  Future<void> _loadSettings() async {
    final settings = await databaseHelper.getSettings();
    if (settings != null) {
      setState(() {
        notificationEnabled = settings['notification_enabled'] == 1;
        final timeParts = settings['notification_time'].split(':');
        notificationTime = TimeOfDay(
          hour: int.parse(timeParts[0]),
          minute: int.parse(timeParts[1]),
        );
        notificationDate = settings['notification_date'] != null
            ? DateTime.parse(settings['notification_date'])
            : DateTime.now();
      });
      if (notificationEnabled) {
        await _scheduleWeatherNotification();
      }
    }
  }

  Future<void> _loadSavedLocations() async {
    _locations = [];
    final savedLocations = await databaseHelper.getAllLocations();
    for (var location in savedLocations) {
      if (location['name'] != null &&
          location['name'].isNotEmpty &&
          location['latitude'] != null &&
          location['longitude'] != null) {
        _locations.add({
          'id': location['id'],
          'name': location['name'],
          'latitude': location['latitude'],
          'longitude': location['longitude'],
          'isCurrent': location['name'] == InitialName,
        });
      }
    }
    print('Loaded valid locations: $_locations');
    setState(() {});
  }

  Future<void> _updateSettings() async {
    try {
      await databaseHelper.updateSettings({
        'unit': 'metric',
        'theme': 'light',
        'language': 'vi',
        'notification_enabled': notificationEnabled ? 1 : 0,
        'notification_time':
            '${notificationTime.hour}:${notificationTime.minute.toString().padLeft(2, '0')}',
        'notification_date': notificationDate.toIso8601String(),
      });
      print('Settings updated successfully');
      if (notificationEnabled) {
        await _scheduleWeatherNotification();
      } else {
        await NotificationService().cancelAllNotifications();
        print('All notifications cancelled');
      }
    } catch (e) {
      print('Error updating settings: $e');
    }
  }

  Future<void> _scheduleWeatherNotification() async {
    if (_locations.isEmpty) {
      print('No valid locations available for notification');
      return;
    }

    final location = _locations.firstWhere(
      (loc) => loc['isCurrent'] == true,
      orElse: () => _locations.first,
    );
    print(
        'Selected location: ${location['name']} (${location['latitude']}, ${location['longitude']})');

    if (location['latitude'] == null || location['longitude'] == null) {
      print('Invalid location coordinates for ${location['name']}');
      return;
    }

    try {
      await WeatherService.loadWeatherData(
          location['latitude'], location['longitude']);
      final dailyData = WeatherService.dailyData;
      print('Daily data: $dailyData');

      if (dailyData.isEmpty ||
          dailyData['list'] == null ||
          dailyData['list'].length < 2) {
        print('Insufficient weather data for tomorrow');
        return;
      }

      // Tìm dữ liệu cho ngày mai
      final now = DateTime.now();
      final tomorrow = DateTime(now.year, now.month, now.day + 1);
      var tomorrowData;
      for (var data in dailyData['list']) {
        final dataDate = DateTime.fromMillisecondsSinceEpoch(data['dt'] * 1000);
        if (dataDate.day == tomorrow.day &&
            dataDate.month == tomorrow.month &&
            dataDate.year == tomorrow.year) {
          tomorrowData = data;
          break;
        }
      }

      if (tomorrowData == null) {
        print('No data found for tomorrow: $tomorrow');
        return;
      }

      final cityName = location['name'];

      if (tomorrowData['temp'] == null || tomorrowData['weather'] == null) {
        print('Invalid tomorrow data: $tomorrowData');
        return;
      }

      final maxTemp = tomorrowData['temp']['max']?.round() ?? 0;
      final minTemp = tomorrowData['temp']['min']?.round() ?? 0;
      final avgTemp = ((maxTemp + minTemp) / 2).round();
      final humidity = tomorrowData['humidity'] ?? 0;
      final weatherDescription =
          tomorrowData['weather'][0]['description']?.toString() ??
              'Không có dữ liệu';
      final windSpeed = (tomorrowData['wind_speed'] != null
          ? tomorrowData['wind_speed'] * 3.6
          : 0); // m/s to km/h
      final windDegree = tomorrowData['wind_deg'] ?? 0;
      final pressure = tomorrowData['pressure'] ?? 0;
      final pop = (tomorrowData['pop'] != null
          ? (tomorrowData['pop'] * 100).round()
          : 0);
      final sunrise = tomorrowData['sunrise'] != null
          ? FormattingService.formatEpochTimeToTime(
              tomorrowData['sunrise'], dailyData['timezone'] ?? 0)
          : 'Không có dữ liệu';
      final sunset = tomorrowData['sunset'] != null
          ? FormattingService.formatEpochTimeToTime(
              tomorrowData['sunset'], dailyData['timezone'] ?? 0)
          : 'Không có dữ liệu';
      final tomorrowDate =
          DateTime.fromMillisecondsSinceEpoch(tomorrowData['dt'] * 1000);
      final dateString =
          '${tomorrowDate.day}/${tomorrowDate.month}/${tomorrowDate.year}';

      final String notificationBody = '''
Dự báo thời tiết tại $cityName ngày $dateString:
- Nhiệt độ: ${maxTemp}°C (Cao nhất), ${minTemp}°C (Thấp nhất), ${avgTemp}°C (Trung bình)
- Độ ẩm: ${humidity}%
- Thời tiết: $weatherDescription
- Xác suất mưa: ${pop}%
- Gió: ${windSpeed.toStringAsFixed(1)} km/h, hướng ${windDegree}°
- Áp suất: ${pressure} hPa
- Mặt trời mọc: $sunrise, lặn: $sunset
''';

      final nowTime = DateTime.now();
      final scheduledTime = DateTime(
        notificationDate.year,
        notificationDate.month,
        notificationDate.day,
        notificationTime.hour,
        notificationTime.minute,
      );

      DateTime finalScheduledDate = scheduledTime;
      if (scheduledTime.isBefore(nowTime)) {
        finalScheduledDate = scheduledTime.add(Duration(days: 1));
        print(
            'Scheduled time is in the past, moving to tomorrow: $finalScheduledDate');
      }

      await NotificationService().scheduleDailyWeatherNotification(
        time:
            '${notificationTime.hour}:${notificationTime.minute.toString().padLeft(2, '0')}',
        title: 'Dự báo thời tiết ngày mai',
        body: notificationBody,
        scheduledDate: finalScheduledDate,
      );
      print(
          'Notification scheduled for $finalScheduledDate with body: $notificationBody');
    } catch (e) {
      print('Error scheduling notification: $e');
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: notificationTime,
    );
    if (picked != null && picked != notificationTime) {
      setState(() {
        notificationTime = picked;
      });
      await _updateSettings();
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: notificationDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );
    if (picked != null && picked != notificationDate) {
      setState(() {
        notificationDate = picked;
      });
      await _updateSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ghi chú và Thông báo'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Thông báo dự báo thời tiết ngày mai',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SwitchListTile(
                  title: Text('Bật thông báo'),
                  value: notificationEnabled,
                  onChanged: (bool value) {
                    setState(() {
                      notificationEnabled = value;
                    });
                    _updateSettings();
                  },
                ),
                ListTile(
                  title: Text('Thời gian thông báo'),
                  subtitle: Text(notificationTime.format(context)),
                  onTap: () => _selectTime(context),
                ),
                ListTile(
                  title: Text('Ngày thông báo'),
                  subtitle: Text(
                      '${notificationDate.day}/${notificationDate.month}/${notificationDate.year}'),
                  onTap: () => _selectDate(context),
                ),
                Divider(),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: notes.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(notes[index].content),
                  subtitle: Text(notes[index].reminderTime.toString()),
                  trailing: IconButton(
                    icon: Icon(Icons.delete),
                    onPressed: () => _deleteNote(notes[index].id!),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      // floatingActionButton: FloatingActionButton(
      //   onPressed: () {
      //     Navigator.push(
      //       context,
      //       MaterialPageRoute(
      //         builder: (context) =>
      //             AddNoteScreen(databaseHelper: databaseHelper),
      //       ),
      //     ).then((_) {
      //       _loadNotes();
      //     });
      //   },
      //   child: Icon(Icons.add),
      // ),
    );
  }
}
