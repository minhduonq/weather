import 'package:flutter/material.dart';
import 'package:frontend/services/constants.dart';
import 'package:frontend/services/database.dart';
import 'package:frontend/services/notification_service.dart';
import 'package:frontend/services/weather_service.dart';
import 'package:frontend/services/formatting_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ManageNotification extends StatefulWidget {
  @override
  _ManageNoteState createState() => _ManageNoteState();
}

class _ManageNoteState extends State<ManageNotification> {
  late DatabaseHelper databaseHelper;
  bool notificationEnabled = true;
  TimeOfDay? notificationTime;
  DateTime notificationDate = DateTime.now();
  bool _isInitialized = false;
  Position? currentPosition;
  String? currentLocationName;

  // API key for weather data
  final String apiKey = '2b5630205440fa5d9747bc910681e783';

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      databaseHelper = DatabaseHelper();
      await NotificationService().init();
      await _ensureDatabaseSchema();
      await _loadSettings();
      await _getCurrentLocation();
      await NotificationService().requestNotificationPermissions();

      setState(() {
        _isInitialized = true;
      });

      if (notificationEnabled) {
        await _scheduleWeatherNotification();
      }
    } catch (e) {
      print('Error initializing app: $e');
      setState(() {
        _isInitialized = true;
      });
      _showErrorSnackBar('Lỗi khởi tạo ứng dụng: $e');
    }
  }

  Future<void> _ensureDatabaseSchema() async {
    try {
      final db = await databaseHelper.database;

      // Lấy thông tin về bảng setting hiện tại
      final columns = await db.rawQuery('PRAGMA table_info(setting)');
      print('Current setting table schema: $columns');

      // Kiểm tra và thêm các cột cần thiết
      bool hasNotificationTime =
          columns.any((col) => col['name'] == 'notification_time');
      if (!hasNotificationTime) {
        await db.execute(
            'ALTER TABLE setting ADD COLUMN notification_time TEXT DEFAULT "20:00"');
        print('Added notification_time column to setting table');
      }

      bool hasNotificationEnabled =
          columns.any((col) => col['name'] == 'notification_enabled');
      if (!hasNotificationEnabled) {
        await db.execute(
            'ALTER TABLE setting ADD COLUMN notification_enabled INTEGER DEFAULT 1');
        print('Added notification_enabled column to setting table');
      }

      bool hasNotificationDate =
          columns.any((col) => col['name'] == 'notification_date');
      if (!hasNotificationDate) {
        await db
            .execute('ALTER TABLE setting ADD COLUMN notification_date TEXT');
        print('Added notification_date column to setting table');
      }
    } catch (e) {
      print('Error updating database schema: $e');
      _showErrorSnackBar('Lỗi cập nhật cấu trúc dữ liệu');
    }
  }

  Future<void> _loadSettings() async {
    try {
      final db = await databaseHelper.database;
      final settings = await db.query('setting', limit: 1);

      if (settings.isNotEmpty) {
        final setting = settings.first;

        // Load notification enabled
        final enabledValue = setting['notification_enabled'];
        if (enabledValue != null) {
          notificationEnabled = enabledValue == 1;
        }

        // Load notification time
        final savedTime = setting['notification_time'] as String?;
        if (savedTime != null && savedTime.contains(':')) {
          try {
            final parts = savedTime.split(':');
            final hour = int.parse(parts[0]);
            final minute = int.parse(parts[1]);
            if (hour >= 0 && hour < 24 && minute >= 0 && minute < 60) {
              notificationTime = TimeOfDay(hour: hour, minute: minute);
            }
          } catch (e) {
            print('Error parsing saved time: $e');
          }
        }
      }

      // Set default values if not found
      if (notificationTime == null) {
        notificationTime = TimeOfDay(hour: 20, minute: 0);
      }

      print(
          'Loaded notification time: ${formatTimeDisplay(notificationTime!)}');
      print('Loaded notification enabled: $notificationEnabled');
    } catch (e) {
      print('Error loading settings: $e');
      // Set default values
      notificationTime = TimeOfDay(hour: 20, minute: 0);
      notificationEnabled = true;
      _showErrorSnackBar('Lỗi tải cài đặt, sử dụng giá trị mặc định');
    }
  }

  Future<void> _saveSettings() async {
    try {
      final db = await databaseHelper.database;
      final timeString = notificationTime != null
          ? '${notificationTime!.hour}:${notificationTime!.minute.toString().padLeft(2, '0')}'
          : '20:00';

      // Kiểm tra xem có bản ghi nào trong bảng setting không
      final existingSettings = await db.query('setting', limit: 1);

      if (existingSettings.isEmpty) {
        // Nếu không có bản ghi, thực hiện insert với tất cả các cột bắt buộc
        await db.insert('setting', {
          'unit': 'metric', // Cột bắt buộc
          'theme': 'light', // Cột bắt buộc
          'language': 'vi', // Cột bắt buộc
          'notification_enabled': notificationEnabled ? 1 : 0, // Cột bắt buộc
          'notification_time': timeString,
          'notification_date': notificationDate.toIso8601String(),
        });
        print(
            'Settings inserted: notification_time=$timeString, enabled=$notificationEnabled');
      } else {
        // Nếu có bản ghi, update bằng cách xóa và insert lại
        // hoặc update tất cả cột để tránh lỗi NOT NULL
        await db.delete('setting'); // Xóa tất cả record cũ
        await db.insert('setting', {
          'unit': 'metric', // Cột bắt buộc
          'theme': 'light', // Cột bắt buộc
          'language': 'vi', // Cột bắt buộc
          'notification_enabled': notificationEnabled ? 1 : 0, // Cột bắt buộc
          'notification_time': timeString,
          'notification_date': notificationDate.toIso8601String(),
        });
        print(
            'Settings updated (delete+insert): notification_time=$timeString, enabled=$notificationEnabled');
      }
    } catch (e) {
      print('Error saving settings: $e');
      _showErrorSnackBar('Lỗi khi lưu cài đặt thời gian: $e');
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission()
          .timeout(Duration(seconds: 3),
              onTimeout: () => LocationPermission.denied);

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission().timeout(
            Duration(seconds: 5),
            onTimeout: () => LocationPermission.denied);

        if (permission == LocationPermission.denied) {
          print('Location permissions are denied');
          await _setupDefaultLocation();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('Location permissions are permanently denied');
        await _setupDefaultLocation();
        return;
      }

      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        ).timeout(Duration(seconds: 5), onTimeout: () {
          throw Exception('Location timeout');
        });

        currentPosition = position;
        currentLocationName = await getCityNameFromCoordinates(
                position.latitude, position.longitude) ??
            'Vị trí hiện tại';
      } catch (e) {
        print('Error getting current position: $e');
        await _setupDefaultLocation();
      }
    } catch (e) {
      print('Error in getCurrentLocation: $e');
      await _setupDefaultLocation();
    }
  }

  Future<void> _setupDefaultLocation() async {
    try {
      const String defaultCity = 'Ho Chi Minh City';
      const double defaultLat = 10.8231;
      const double defaultLon = 106.6297;

      currentPosition = Position(
        latitude: defaultLat,
        longitude: defaultLon,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      );
      currentLocationName = defaultCity;
      print('Default location set to: $defaultCity');
    } catch (e) {
      print('Error setting up default location: $e');
    }
  }

  Future<String?> getCityNameFromCoordinates(double lat, double lon) async {
    try {
      final url =
          'https://api.openweathermap.org/geo/1.0/reverse?lat=$lat&lon=$lon&limit=1&appid=$apiKey';
      final response =
          await http.get(Uri.parse(url)).timeout(Duration(seconds: 10));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          return data[0]['name'];
        }
      } else {
        print('Geocoding API error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting city name: $e');
    }
    return null;
  }

  Future<void> _updateSettings() async {
    try {
      await _saveSettings();
      await NotificationService().cancelAllNotifications();

      if (notificationEnabled) {
        await _scheduleWeatherNotification();
        print(
            'Weather notification scheduled for ${formatTimeDisplay(notificationTime!)}');
        _showSnackBar(
            'Đã lên lịch thông báo cho ${formatTimeDisplay(notificationTime!)}');
      } else {
        print('All notifications cancelled');
        _showSnackBar('Đã tắt thông báo thời tiết');
      }
    } catch (e) {
      print('Error updating settings: $e');
      _showErrorSnackBar('Lỗi khi cập nhật cài đặt: $e');
    }
  }

  Future<Map<String, dynamic>?> _fetchCurrentWeather() async {
    try {
      if (currentPosition == null) {
        await _getCurrentLocation();
      }

      if (currentPosition == null) {
        print('No current position available');
        return null;
      }

      final url =
          'https://api.openweathermap.org/data/2.5/weather?lat=${currentPosition!.latitude}&lon=${currentPosition!.longitude}&appid=$apiKey&units=metric&lang=vi';

      final response =
          await http.get(Uri.parse(url)).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('Weather API error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error fetching current weather: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _fetchTomorrowWeather() async {
    try {
      if (currentPosition == null) {
        await _getCurrentLocation();
      }

      if (currentPosition == null) {
        print('No current position available');
        return null;
      }

      final url =
          'https://api.openweathermap.org/data/2.5/forecast?lat=${currentPosition!.latitude}&lon=${currentPosition!.longitude}&appid=$apiKey&units=metric&lang=vi';

      final response =
          await http.get(Uri.parse(url)).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> list = data['list'] ?? [];

        if (list.isEmpty) {
          print('No forecast data available');
          return null;
        }

        final now = DateTime.now();
        final tomorrow = DateTime(now.year, now.month, now.day + 1);

        final tomorrowForecasts = list.where((item) {
          final itemDateTime =
              DateTime.fromMillisecondsSinceEpoch(item['dt'] * 1000);
          return itemDateTime.day == tomorrow.day &&
              itemDateTime.month == tomorrow.month &&
              itemDateTime.year == tomorrow.year;
        }).toList();

        if (tomorrowForecasts.isEmpty) {
          print('No forecast data found for tomorrow');
          return null;
        }

        double tempSum = 0;
        double tempMax = double.negativeInfinity;
        double tempMin = double.infinity;
        double humiditySum = 0;
        double pressureSum = 0;
        double windSpeedSum = 0;
        double windDegSum = 0;
        double popMax = 0;
        String description = '';
        String icon = '';

        for (var forecast in tomorrowForecasts) {
          final temp = forecast['main']['temp'].toDouble();
          tempSum += temp;
          tempMax = tempMax > temp ? tempMax : temp;
          tempMin = tempMin < temp ? tempMin : temp;

          humiditySum += forecast['main']['humidity'];
          pressureSum += forecast['main']['pressure'];
          windSpeedSum += forecast['wind']['speed'];
          windDegSum += forecast['wind']['deg'] ?? 0;

          final pop = (forecast['pop'] ?? 0).toDouble();
          popMax = popMax > pop ? popMax : pop;

          if (description.isEmpty) {
            description = forecast['weather'][0]['description'];
            icon = forecast['weather'][0]['icon'];
          }
        }

        final count = tomorrowForecasts.length;
        return {
          'dt': tomorrow.millisecondsSinceEpoch ~/ 1000,
          'temp': {
            'max': tempMax,
            'min': tempMin,
            'avg': tempSum / count,
          },
          'humidity': (humiditySum / count).round(),
          'pressure': (pressureSum / count).round(),
          'wind_speed': windSpeedSum / count,
          'wind_deg': (windDegSum / count).round(),
          'pop': popMax,
          'weather': [
            {
              'description': description,
              'icon': icon,
            }
          ],
          'timezone': data['city']['timezone'] ?? 0,
        };
      } else {
        print('Forecast API error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error fetching tomorrow weather: $e');
      return null;
    }
  }

  String _formatWeatherNotification(
      Map<String, dynamic> tomorrowData, String cityName, int? timezone) {
    final tempData = tomorrowData['temp'] ?? {};
    final maxTemp = tempData['max']?.round() ?? 0;
    final minTemp = tempData['min']?.round() ?? 0;
    final avgTemp = tempData['avg']?.round() ?? 0;
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
''';
  }

  Future<void> _scheduleWeatherNotification() async {
    try {
      await NotificationService().cancelAllNotifications();

      final tomorrowData = await _fetchTomorrowWeather();
      if (tomorrowData == null) {
        _showErrorSnackBar('Không thể lấy dữ liệu thời tiết ngày mai');
        return;
      }

      final timezone = tomorrowData['timezone'] as int? ?? 0;
      final cityName = currentLocationName ?? 'Vị trí hiện tại';
      final notificationBody =
          _formatWeatherNotification(tomorrowData, cityName, timezone);

      // Test mode cho debug - set thành false để test ngay
      bool isPhysicalDevice = true;
      if (!kIsWeb && Platform.isAndroid) {
        isPhysicalDevice = true; // Thay thành false để test ngay
      }

      if (!isPhysicalDevice) {
        // Test mode - hiển thị thông báo ngay
        await NotificationService().showNotification(
          id: 0,
          title: 'Dự báo thời tiết ngày mai',
          body: notificationBody,
        );
        _showSnackBar('Đã gửi thông báo thời tiết ngay (Test mode)');
        print('Notification shown immediately for testing');
      } else {
        // Production mode - lên lịch thông báo
        final now = DateTime.now();
        final scheduledTime = DateTime(
          notificationDate.year,
          notificationDate.month,
          notificationDate.day,
          notificationTime!.hour,
          notificationTime!.minute,
        );
        final finalScheduledDate = scheduledTime.isBefore(now)
            ? scheduledTime.add(Duration(days: 1))
            : scheduledTime;

        await NotificationService().scheduleDailyWeatherNotification(
          id: 0,
          time:
              '${notificationTime!.hour}:${notificationTime!.minute.toString().padLeft(2, '0')}',
          title: 'Dự báo thời tiết ngày mai',
          body: notificationBody,
          scheduledDate: finalScheduledDate,
        );

        _showSnackBar(
            'Đã lên lịch thông báo thời tiết cho ${formatTimeDisplay(notificationTime!)}');
        print('Notification scheduled for $finalScheduledDate');
      }
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
    return currentLocationName ?? 'Vị trí hiện tại';
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
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () async {
              await _getCurrentLocation();
              if (notificationEnabled) {
                await _scheduleWeatherNotification();
              }
              _showSnackBar('Đã làm mới cài đặt thông báo');
            },
            tooltip: 'Làm mới thông báo',
          ),
        ],
      ),
      body: !_isInitialized || notificationTime == null
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
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
                            ListTile(
                              title: Text('Thời gian thông báo'),
                              subtitle: Text(
                                formatTimeDisplay(notificationTime!),
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
                                  initialTime: notificationTime!,
                                  builder:
                                      (BuildContext context, Widget? child) {
                                    return MediaQuery(
                                      data: MediaQuery.of(context).copyWith(
                                          alwaysUse24HourFormat: true),
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
                            Divider(),
                            ListTile(
                              title: Text('Vị trí hiện tại'),
                              subtitle: Text(
                                _getCurrentLocationName(),
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              leading: Icon(Icons.location_on),
                            ),
                            if (currentPosition != null) ...[
                              ListTile(
                                title: Text('Tọa độ'),
                                subtitle: Text(
                                  'Lat: ${currentPosition!.latitude.toStringAsFixed(4)}, Lon: ${currentPosition!.longitude.toStringAsFixed(4)}',
                                  style: TextStyle(fontSize: 12),
                                ),
                                leading: Icon(Icons.gps_fixed),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
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
                              'Ứng dụng sẽ gửi thông báo dự báo thời tiết hàng ngày vào giờ bạn chọn. '
                              'Thông báo sẽ cung cấp thông tin về nhiệt độ, độ ẩm, áp suất, thời tiết, và '
                              'xác suất mưa cho ngày hôm sau dựa trên vị trí hiện tại của bạn.',
                              style: TextStyle(fontSize: 14),
                            ),
                            SizedBox(height: 8),
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: Colors.blue.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.tips_and_updates,
                                      color: Colors.blue, size: 20),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Mẹo: Thời gian thông báo sẽ được lưu và áp dụng cho lần tiếp theo.',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.blue[700]),
                                    ),
                                  ),
                                ],
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
