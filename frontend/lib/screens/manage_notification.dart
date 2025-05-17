import 'package:flutter/material.dart';
import 'package:frontend/services/constants.dart';
import 'package:frontend/services/database.dart';
import 'package:frontend/services/notification_service.dart';
import 'package:frontend/services/weather_service.dart';
import 'package:frontend/services/formatting_service.dart';
import 'dart:io' show Platform;

class ManageNotification extends StatefulWidget {
  @override
  _ManageNoteState createState() => _ManageNoteState();
}

class _ManageNoteState extends State<ManageNotification>
    with WidgetsBindingObserver {
  late DatabaseHelper databaseHelper;
  bool notificationEnabled = true;
  TimeOfDay notificationTime = const TimeOfDay(hour: 20, minute: 0);
  DateTime notificationDate = DateTime.now();
  List<Map<String, dynamic>> _locations = [];
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      databaseHelper = DatabaseHelper();
      await NotificationService().init();
      await _loadSettings();
      await _loadSavedLocations();
      await _ensureDatabaseSchema();
      await NotificationService().requestNotificationPermissions();

      setState(() {
        _isInitialized = true;
      });

      // Schedule notification on app start if enabled
      if (notificationEnabled) {
        await _scheduleWeatherNotification();
      }
    } catch (e) {
      print('Error initializing app: $e');
      setState(() {
        _isInitialized = true; // Set to true even on error to show UI
      });
      _showErrorSnackBar('Lỗi khởi tạo ứng dụng: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refetch settings and reschedule notifications when app resumes
      _loadSettings().then((_) {
        if (notificationEnabled) {
          _scheduleWeatherNotification();
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _ensureDatabaseSchema() async {
    try {
      final db = await databaseHelper.database;
      final columns = await db.rawQuery('PRAGMA table_info(setting)');

      bool hasNotificationTime =
          columns.any((col) => col['name'] == 'notification_time');
      if (!hasNotificationTime) {
        await db.execute(
            'ALTER TABLE setting ADD COLUMN notification_time TEXT DEFAULT "20:00"');
        print('Added notification_time column to setting table');
      }

      bool hasNotificationDate =
          columns.any((col) => col['name'] == 'notification_date');
      if (!hasNotificationDate) {
        await db
            .execute('ALTER TABLE setting ADD COLUMN notification_date TEXT');
        print('Added notification_date column to setting table');
      }

      final schema = await db.rawQuery('PRAGMA table_info(setting)');
      print('Setting table schema: $schema');
    } catch (e) {
      print('Error updating database schema: $e');
      _showErrorSnackBar('Lỗi cập nhật cấu trúc dữ liệu');
    }
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await databaseHelper.getSettings();
      setState(() {
        notificationEnabled = settings?['notification_enabled'] == 1;
        if (settings?['notification_time'] != null) {
          final timeParts = settings?['notification_time'].split(':');
          if (timeParts.length == 2) {
            try {
              notificationTime = TimeOfDay(
                hour: int.parse(timeParts[0]),
                minute: int.parse(timeParts[1]),
              );
            } catch (e) {
              print('Invalid notification time format: $e');
              notificationTime = const TimeOfDay(hour: 20, minute: 0);
            }
          }
        }
        notificationDate = settings?['notification_date'] != null
            ? DateTime.parse(settings?['notification_date'])
            : DateTime.now();
      });
    } catch (e) {
      print('Error loading settings: $e');
      _showErrorSnackBar('Lỗi tải cài đặt');
    }
  }

  Future<void> _loadSavedLocations() async {
    try {
      _locations = [];
      final savedLocations = await databaseHelper.getAllLocations();
      for (var location in savedLocations) {
        if (location['name']?.isNotEmpty == true &&
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
      if (_locations.isEmpty) {
        _showErrorSnackBar('Không tìm thấy vị trí. Vui lòng thêm vị trí.');
      }
      setState(() {});
    } catch (e) {
      print('Error loading locations: $e');
      _showErrorSnackBar('Lỗi tải vị trí');
    }
  }

  Future<void> _updateSettings() async {
    try {
      await _ensureDatabaseSchema();
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

      // Cancel existing notifications
      await NotificationService().cancelAllNotifications();

      if (notificationEnabled) {
        await _scheduleWeatherNotification();
        print(
            'Weather notification scheduled for ${formatTimeDisplay(notificationTime)}');
      } else {
        print('All notifications cancelled');
        _showSnackBar('Đã tắt thông báo thời tiết');
      }
    } catch (e) {
      print('Error updating settings: $e');
      _showErrorSnackBar('Lỗi khi cập nhật cài đặt: $e');
    }
  }

  Future<Map<String, dynamic>?> _fetchTomorrowWeather(
      double latitude, double longitude) async {
    try {
      await WeatherService.loadWeatherData(latitude, longitude);
      final dailyData = WeatherService.dailyData;
      if (dailyData.isEmpty ||
          dailyData['list'] == null ||
          dailyData['list'].length < 2) {
        print('Insufficient weather data');
        return null;
      }

      final now = DateTime.now();
      final tomorrow = DateTime(now.year, now.month, now.day + 1);
      for (var data in dailyData['list']) {
        final dataDate = DateTime.fromMillisecondsSinceEpoch(data['dt'] * 1000);
        if (dataDate.day == tomorrow.day &&
            dataDate.month == tomorrow.month &&
            dataDate.year == tomorrow.year) {
          return data;
        }
      }
      print('No data found for tomorrow: $tomorrow');
      return null;
    } catch (e) {
      print('Error fetching weather data: $e');
      return null;
    }
  }

  String _formatWeatherNotification(
      Map<String, dynamic> tomorrowData, String cityName, int? timezone) {
    final maxTemp = tomorrowData['temp']?['max']?.round() ?? 0;
    final minTemp = tomorrowData['temp']?['min']?.round() ?? 0;
    final avgTemp = ((maxTemp + minTemp) / 2).round();
    final humidity = tomorrowData['humidity'] ?? 0;
    final weatherDescription =
        tomorrowData['weather']?[0]?['description']?.toString() ?? 'N/A';
    final pop =
        (tomorrowData['pop'] != null ? (tomorrowData['pop'] * 100).round() : 0);
    final windSpeed = (tomorrowData['wind_speed'] != null
        ? (tomorrowData['wind_speed'] * 3.6).toStringAsFixed(1)
        : '0.0');
    final windDegree = tomorrowData['wind_deg'] ?? 0;
    final pressure = tomorrowData['pressure'] ?? 0;
    final sunrise = tomorrowData['sunrise'] != null
        ? FormattingService.formatEpochTimeToTime(
            tomorrowData['sunrise'], timezone ?? 0)
        : 'N/A';
    final sunset = tomorrowData['sunset'] != null
        ? FormattingService.formatEpochTimeToTime(
            tomorrowData['sunset'], timezone ?? 0)
        : 'N/A';
    final date = DateTime.fromMillisecondsSinceEpoch(tomorrowData['dt'] * 1000);
    final dateString = '${date.day}/${date.month}/${date.year}';

    return '''
Dự báo thời tiết tại $cityName ngày $dateString:
- Nhiệt độ: ${maxTemp}°C (Cao nhất), ${minTemp}°C (Thấp nhất), ${avgTemp}°C (Trung bình)
- Độ ẩm: ${humidity}%
- Thời tiết: $weatherDescription
- Xác suất mưa: ${pop}%
- Gió: $windSpeed km/h, hướng ${windDegree}°
- Áp suất: ${pressure} hPa
- Mặt trời mọc: $sunrise, lặn: $sunset
''';
  }

  Future<void> _scheduleWeatherNotification() async {
    try {
      if (_locations.isEmpty) {
        print('No valid locations available');
        _showErrorSnackBar('Không có vị trí cho thông báo thời tiết');
        return;
      }

      final location = _locations.firstWhere(
        (loc) => loc['isCurrent'] == true,
        orElse: () => _locations.first,
      );
      print('Selected location for notification: ${location['name']}');

      final latitude = location['latitude'] as double?;
      final longitude = location['longitude'] as double?;
      if (latitude == null || longitude == null) {
        print('Invalid coordinates for ${location['name']}');
        _showErrorSnackBar('Tọa độ vị trí không hợp lệ');
        return;
      }

      // Cancel any existing notifications first
      await NotificationService().cancelAllNotifications();

      final tomorrowData = await _fetchTomorrowWeather(latitude, longitude);
      if (tomorrowData == null) {
        _showErrorSnackBar('Không thể lấy dữ liệu thời tiết ngày mai');
        return;
      }

      final cityName = location['name'] as String;
      final timezone = WeatherService.dailyData['timezone'] as int? ?? 0;
      final notificationBody =
          _formatWeatherNotification(tomorrowData, cityName, timezone);

      final now = DateTime.now();
      final scheduledTime = DateTime(
        notificationDate.year,
        notificationDate.month,
        notificationDate.day,
        notificationTime.hour,
        notificationTime.minute,
      );
      final finalScheduledDate = scheduledTime.isBefore(now)
          ? scheduledTime.add(Duration(days: 1))
          : scheduledTime;

      // Schedule the actual daily notification
      await NotificationService().scheduleDailyWeatherNotification(
        id: 0,
        time:
            '${notificationTime.hour}:${notificationTime.minute.toString().padLeft(2, '0')}',
        title: 'Dự báo thời tiết ngày mai',
        body: notificationBody,
        scheduledDate: finalScheduledDate,
      );

      print('Notification scheduled for $finalScheduledDate');
      _showSnackBar(
          'Đã lên lịch thông báo thời tiết cho ${formatTimeDisplay(notificationTime)}');
    } catch (e) {
      print('Error scheduling notification: $e');
      _showErrorSnackBar('Lỗi khi lên lịch thông báo: $e');
    }
  }

  String formatTimeDisplay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _getCurrentLocationName() {
    final currentLocation = _locations.firstWhere(
      (loc) => loc['isCurrent'] == true,
      orElse: () =>
          _locations.isNotEmpty ? _locations.first : {'name': 'Chưa có vị trí'},
    );
    return currentLocation['name'] as String;
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Quản lý thông báo'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () async {
              await _loadSettings();
              await _loadSavedLocations();
              if (notificationEnabled) {
                await _scheduleWeatherNotification();
              }
              _showSnackBar('Đã làm mới cài đặt thông báo');
            },
            tooltip: 'Làm mới thông báo',
          ),
        ],
      ),
      body: !_isInitialized
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    // Phần cài đặt thông báo
                    Card(
                      margin: EdgeInsets.all(10),
                      elevation: 4,
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.notifications,
                                    color: Theme.of(context).primaryColor),
                                SizedBox(width: 8),
                                Text(
                                  'Cài đặt thông báo thời tiết',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            SwitchListTile(
                              title: Text('Bật thông báo thời tiết hàng ngày'),
                              value: notificationEnabled,
                              secondary: Icon(
                                notificationEnabled
                                    ? Icons.notifications_active
                                    : Icons.notifications_off,
                                color: notificationEnabled
                                    ? Colors.green
                                    : Colors.grey,
                              ),
                              onChanged: (value) async {
                                setState(() {
                                  notificationEnabled = value;
                                });
                                await _updateSettings();
                              },
                            ),
                            // Widget chọn giờ thông báo
                            ListTile(
                              title: Text('Thời gian thông báo'),
                              subtitle: Text(
                                formatTimeDisplay(notificationTime),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: notificationEnabled
                                      ? Theme.of(context).primaryColor
                                      : Colors.grey,
                                ),
                              ),
                              leading: Icon(Icons.access_time),
                              enabled: notificationEnabled,
                              onTap: () async {
                                if (!notificationEnabled) return;

                                final TimeOfDay? picked = await showTimePicker(
                                  context: context,
                                  initialTime: notificationTime,
                                  builder:
                                      (BuildContext context, Widget? child) {
                                    return MediaQuery(
                                      data: MediaQuery.of(context).copyWith(
                                        alwaysUse24HourFormat: true,
                                      ),
                                      child: child!,
                                    );
                                  },
                                );

                                if (picked != null &&
                                    picked != notificationTime) {
                                  setState(() {
                                    notificationTime = picked;
                                  });
                                  await _updateSettings();
                                }
                              },
                            ),
                            // Hiển thị vị trí hiện tại
                            if (_locations.isNotEmpty) ...[
                              Divider(),
                              ListTile(
                                title: Text('Vị trí hiện tại'),
                                subtitle: Text(
                                  _getCurrentLocationName(),
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                leading: Icon(Icons.location_on),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    // Thẻ mô tả thông báo
                    Card(
                      margin: EdgeInsets.all(10),
                      elevation: 2,
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline,
                                    color: Theme.of(context).primaryColor),
                                SizedBox(width: 8),
                                Text(
                                  'Thông tin về thông báo',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Ứng dụng sẽ gửi cho bạn thông báo dự báo thời tiết mỗi ngày vào giờ đã chọn. '
                              'Thông báo sẽ cung cấp thông tin về nhiệt độ, độ ẩm, áp suất, thời tiết, và '
                              'xác suất mưa cho ngày hôm sau.',
                              style: TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Thẻ kiểm tra thông báo
                    Card(
                      margin: EdgeInsets.all(10),
                      elevation: 3,
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.notification_important,
                                    color: Theme.of(context).primaryColor),
                                SizedBox(width: 8),
                                Text(
                                  'Kiểm tra thông báo',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Nếu bạn không nhận được thông báo, hãy kiểm tra xem thông báo đã được bật trong '
                              'cài đặt của điện thoại chưa. Bạn cũng có thể kiểm tra thông báo bằng cách nhấn nút bên dưới.',
                              style: TextStyle(fontSize: 14),
                            ),
                            SizedBox(height: 16),
                            Center(
                              child: ElevatedButton.icon(
                                icon: Icon(Icons.send),
                                label: Text('Gửi thông báo thử nghiệm'),
                                style: ElevatedButton.styleFrom(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 12),
                                ),
                                onPressed: () async {
                                  try {
                                    // Lên lịch thông báo với thời gian cụ thể trong tương lai gần
                                    final now = DateTime.now();
                                    final testDate =
                                        now.add(Duration(minutes: 1));

                                    await NotificationService()
                                        .scheduleDailyWeatherNotification(
                                      id: 100,
                                      time: '${now.hour}:${now.minute}',
                                      title: 'Thử nghiệm thông báo',
                                      body:
                                          'Đây là thông báo thử nghiệm. Nếu bạn nhìn thấy nó, hệ thống thông báo đang hoạt động bình thường.',
                                      scheduledDate: testDate,
                                    );

                                    _showSnackBar(
                                        'Đã lên lịch thông báo thử nghiệm, sẽ hiển thị sau 1 phút');
                                  } catch (e) {
                                    _showErrorSnackBar(
                                        'Lỗi khi gửi thông báo: $e');
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Thẻ khắc phục sự cố
                    Card(
                      margin: EdgeInsets.all(10),
                      elevation: 2,
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.help_outline,
                                    color: Theme.of(context).primaryColor),
                                SizedBox(width: 8),
                                Text(
                                  'Khắc phục sự cố',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Nếu thông báo không hoạt động:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 8),
                            Text(
                                '1. Đảm bảo đã bật thông báo trong cài đặt ứng dụng'),
                            Text(
                                '2. Kiểm tra cài đặt thông báo trong điện thoại'),
                            Text('3. Thử khởi động lại ứng dụng'),
                            Text('4. Nhấn nút làm mới ở góc trên bên phải'),
                            SizedBox(height: 16),
                            Center(
                              child: ElevatedButton.icon(
                                icon: Icon(Icons.refresh),
                                label: Text('Khởi tạo lại thông báo'),
                                style: ElevatedButton.styleFrom(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 12),
                                ),
                                onPressed: () async {
                                  await NotificationService()
                                      .cancelAllNotifications();
                                  if (notificationEnabled) {
                                    await _scheduleWeatherNotification();
                                  }
                                  _showSnackBar('Đã khởi tạo lại thông báo');
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
