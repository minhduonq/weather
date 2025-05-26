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
import 'dart:async'; // Thêm import cho Timer
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;

class ManageNotification extends StatefulWidget {
  @override
  _ManageNoteState createState() => _ManageNoteState();
}

class _ManageNoteState extends State<ManageNotification>
    with WidgetsBindingObserver {
  late DatabaseHelper databaseHelper;
  bool notificationEnabled = true;
  TimeOfDay? notificationTime;
  DateTime notificationDate = DateTime.now();
  bool _isInitialized = false;
  Position? currentPosition;
  String? currentLocationName;

  // Timer management
  Timer? _notificationTimer;
  Timer? _dailyTimer;
  Timer? _statusUpdateTimer;

  // Notification status tracking
  String _timerStatus = 'Chưa khởi tạo';
  String _nextNotificationTime = '';
  bool _isTimerActive = false;

  // API key for weather data
  final String apiKey = '2b5630205440fa5d9747bc910681e783';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
    _startStatusUpdateTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelAllTimers();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Khi app quay lại foreground, kiểm tra và đặt lại timer nếu cần
    if (state == AppLifecycleState.resumed) {
      print('App resumed - checking timer status');
      if (notificationEnabled && !_isTimerActive) {
        print('Timer not active, rescheduling...');
        _scheduleWeatherNotificationSilent();
      }
    }
  }

  void _cancelAllTimers() {
    _notificationTimer?.cancel();
    _dailyTimer?.cancel();
    _statusUpdateTimer?.cancel();
    _notificationTimer = null;
    _dailyTimer = null;
    _statusUpdateTimer = null;
  }

  void _startStatusUpdateTimer() {
    _statusUpdateTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      if (mounted) {
        _updateTimerStatus();
      }
    });
  }

  void _updateTimerStatus() {
    setState(() {
      _isTimerActive = _notificationTimer?.isActive == true;

      if (_isTimerActive && notificationTime != null) {
        final now = DateTime.now();
        final todayScheduledTime = DateTime(
          now.year,
          now.month,
          now.day,
          notificationTime!.hour,
          notificationTime!.minute,
          0,
          0,
        );

        DateTime nextTime;
        if (todayScheduledTime.isAfter(now)) {
          nextTime = todayScheduledTime;
        } else {
          nextTime = todayScheduledTime.add(Duration(days: 1));
        }

        final timeUntil = nextTime.difference(now);

        if (timeUntil.inDays >= 1) {
          _nextNotificationTime =
              'Ngày mai lúc ${formatTimeDisplay(notificationTime!)}';
        } else if (timeUntil.inHours >= 1) {
          _nextNotificationTime =
              'Sau ${timeUntil.inHours}h ${timeUntil.inMinutes % 60}p';
        } else if (timeUntil.inMinutes >= 1) {
          _nextNotificationTime = 'Sau ${timeUntil.inMinutes} phút';
        } else {
          _nextNotificationTime = 'Sắp hiển thị';
        }

        _timerStatus = 'Hoạt động';
      } else {
        _timerStatus = notificationEnabled ? 'Không hoạt động' : 'Đã tắt';
        _nextNotificationTime = '';
      }
    });
  }

  Future<void> _initializeApp() async {
    try {
      setState(() {
        _timerStatus = 'Đang khởi tạo...';
      });

      databaseHelper = DatabaseHelper();
      await NotificationService().init();
      await _ensureDatabaseSchema();
      await _loadSettings();
      await _getCurrentLocation();
      await NotificationService().requestNotificationPermissions();

      setState(() {
        _isInitialized = true;
        _timerStatus = 'Đã khởi tạo';
      });

      // Tự động schedule notification nếu được bật
      if (notificationEnabled) {
        print('Auto-scheduling notification on app init...');
        await _scheduleWeatherNotificationSilent();
      }
    } catch (e) {
      print('Error initializing app: $e');
      setState(() {
        _isInitialized = true;
        _timerStatus = 'Lỗi khởi tạo';
      });
      _showErrorSnackBar('Lỗi khởi tạo ứng dụng: $e');
    }
  }

  Future<void> _ensureDatabaseSchema() async {
    try {
      final db = await databaseHelper.database;
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

      final existingSettings = await db.query('setting', limit: 1);

      if (existingSettings.isEmpty) {
        await db.insert('setting', {
          'unit': 'metric',
          'theme': 'light',
          'language': 'vi',
          'notification_enabled': notificationEnabled ? 1 : 0,
          'notification_time': timeString,
          'notification_date': notificationDate.toIso8601String(),
        });
        print(
            'Settings inserted: notification_time=$timeString, enabled=$notificationEnabled');
      } else {
        await db.delete('setting');
        await db.insert('setting', {
          'unit': 'metric',
          'theme': 'light',
          'language': 'vi',
          'notification_enabled': notificationEnabled ? 1 : 0,
          'notification_time': timeString,
          'notification_date': notificationDate.toIso8601String(),
        });
        print(
            'Settings updated: notification_time=$timeString, enabled=$notificationEnabled');
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

      // Hủy tất cả timer và notification cũ
      _cancelAllTimers();
      await NotificationService().cancelAllNotifications();

      if (notificationEnabled) {
        await _scheduleWeatherNotification();
        print(
            'Weather notification scheduled for ${formatTimeDisplay(notificationTime!)}');
      } else {
        print('All notifications cancelled');
        setState(() {
          _timerStatus = 'Đã tắt';
          _nextNotificationTime = '';
        });
        _showSnackBar('Đã tắt thông báo thời tiết');
      }

      // Khởi động lại timer cập nhật trạng thái
      _startStatusUpdateTimer();
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

    return '''Dự báo thời tiết tại $cityName ngày $dateString:
- Nhiệt độ: ${maxTemp}°C (Cao nhất), ${minTemp}°C (Thấp nhất), ${avgTemp}°C (Trung bình)
- Độ ẩm: ${humidity}%
- Thời tiết: $weatherDescription
- Xác suất mưa: ${pop}%
- Gió: $windSpeed km/h, hướng ${windDegree}°
- Áp suất: ${pressure} hPa''';
  }

  Future<void> _showWeatherNotificationNow() async {
    try {
      final tomorrowData = await _fetchTomorrowWeather();
      if (tomorrowData == null) {
        print('Cannot fetch weather data for immediate notification');
        return;
      }

      final timezone = tomorrowData['timezone'] as int? ?? 0;
      final cityName = currentLocationName ?? 'Vị trí hiện tại';
      final notificationBody =
          _formatWeatherNotification(tomorrowData, cityName, timezone);

      await NotificationService().showNotification(
        id: 0,
        title: 'Dự báo thời tiết ngày mai',
        body: notificationBody,
      );

      print('Weather notification shown immediately');
    } catch (e) {
      print('Error showing immediate notification: $e');
    }
  }

  Future<void> _scheduleWeatherNotificationSilent() async {
    try {
      _cancelAllTimers();
      await NotificationService().cancelAllNotifications();

      if (!notificationEnabled) {
        print('Notification disabled, skipping silent scheduling');
        return;
      }

      final tomorrowData = await _fetchTomorrowWeather();
      if (tomorrowData == null) {
        print('Cannot fetch weather data for silent scheduling');
        setState(() {
          _timerStatus = 'Lỗi lấy dữ liệu thời tiết';
        });
        return;
      }

      final now = DateTime.now();
      final todayScheduledTime = DateTime(
        now.year,
        now.month,
        now.day,
        notificationTime!.hour,
        notificationTime!.minute,
        0,
        0,
      );

      DateTime scheduledTime;
      if (todayScheduledTime.isAfter(now)) {
        scheduledTime = todayScheduledTime;
        print('Scheduling for TODAY: $scheduledTime');
      } else {
        scheduledTime = todayScheduledTime.add(Duration(days: 1));
        print('Scheduling for TOMORROW: $scheduledTime');
      }

      final timeUntil = scheduledTime.difference(now);

      // Đặt notification timer
      _notificationTimer = Timer(timeUntil, () async {
        print('Timer triggered - showing notification');
        await _showWeatherNotificationNow();

        // Đặt lại timer cho ngày hôm sau
        if (notificationEnabled && mounted) {
          await Future.delayed(
              Duration(seconds: 5)); // Đợi 5 giây rồi schedule lại
          _scheduleWeatherNotificationSilent();
        }
      });

      // Đặt daily timer để reset vào 00:01
      _setupDailyTimer();

      // Khởi động timer cập nhật trạng thái
      _startStatusUpdateTimer();

      print(
          'Silent timer set for ${timeUntil.inMinutes} minutes (${timeUntil.inHours}h ${timeUntil.inMinutes % 60}m)');
      print('Next notification at: $scheduledTime');

      setState(() {
        _timerStatus = 'Hoạt động';
      });
    } catch (e) {
      print('Error in silent scheduling: $e');
      setState(() {
        _timerStatus = 'Lỗi đặt lịch';
      });
    }
  }

  Future<void> _scheduleWeatherNotification() async {
    try {
      _cancelAllTimers();
      await NotificationService().cancelAllNotifications();

      final tomorrowData = await _fetchTomorrowWeather();
      if (tomorrowData == null) {
        _showErrorSnackBar('Không thể lấy dữ liệu thời tiết ngày mai');
        return;
      }

      final now = DateTime.now();
      final todayScheduledTime = DateTime(
        now.year,
        now.month,
        now.day,
        notificationTime!.hour,
        notificationTime!.minute,
        0,
        0,
      );

      DateTime scheduledTime;
      if (todayScheduledTime.isAfter(now)) {
        scheduledTime = todayScheduledTime;
        print('Scheduling for TODAY: $scheduledTime');
      } else {
        scheduledTime = todayScheduledTime.add(Duration(days: 1));
        print('Scheduling for TOMORROW: $scheduledTime');
      }

      final timeUntil = scheduledTime.difference(now);

      // Đặt notification timer
      _notificationTimer = Timer(timeUntil, () async {
        print('Timer triggered - showing notification');
        await _showWeatherNotificationNow();

        // Đặt lại timer cho ngày hôm sau
        if (notificationEnabled && mounted) {
          await Future.delayed(Duration(seconds: 5));
          _scheduleWeatherNotificationSilent();
        }
      });

      // Đặt daily timer
      _setupDailyTimer();

      // Khởi động timer cập nhật trạng thái
      _startStatusUpdateTimer();

      // Hiển thị thông báo cho user
      String timeMessage;
      if (timeUntil.inDays >= 1) {
        timeMessage =
            'vào ngày mai lúc ${formatTimeDisplay(notificationTime!)}';
      } else if (timeUntil.inHours >= 1) {
        timeMessage =
            'sau ${timeUntil.inHours}h ${timeUntil.inMinutes % 60}p (${formatTimeDisplay(notificationTime!)})';
      } else if (timeUntil.inMinutes >= 1) {
        timeMessage =
            'sau ${timeUntil.inMinutes}p (${formatTimeDisplay(notificationTime!)})';
      } else {
        timeMessage = 'trong vài giây nữa';
      }

      _showSnackBar('Đã đặt hẹn giờ thông báo $timeMessage');
      print('Notification timer set for: $scheduledTime');
      print(
          'Time until notification: ${timeUntil.inMinutes} minutes (${timeUntil.inHours}h ${timeUntil.inMinutes % 60}m)');

      setState(() {
        _timerStatus = 'Hoạt động';
      });
    } catch (e) {
      print('Error scheduling notification: $e');
      _showErrorSnackBar('Lỗi khi lên lịch thông báo: $e');
      setState(() {
        _timerStatus = 'Lỗi đặt lịch';
      });
    }
  }

  void _setupDailyTimer() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final resetTime = tomorrow.add(Duration(minutes: 1));
    final timeUntilReset = resetTime.difference(now);

    _dailyTimer = Timer(timeUntilReset, () {
      print('Daily timer triggered - rescheduling notification');
      if (notificationEnabled && mounted) {
        _scheduleWeatherNotificationSilent();
      }
    });

    print(
        'Daily reset timer set for: $resetTime (in ${timeUntilReset.inHours}h ${timeUntilReset.inMinutes % 60}m)');
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
        duration: Duration(seconds: 3),
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
        duration: Duration(seconds: 4),
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
              setState(() {
                _timerStatus = 'Đang làm mới...';
              });

              await _getCurrentLocation();
              if (notificationEnabled) {
                await _scheduleWeatherNotification();
              }
              _showSnackBar('Đã làm mới cài đặt thông báo');
            },
            tooltip: 'Làm mới thông báo',
          ),
          IconButton(
            icon: Icon(Icons.notifications_active),
            onPressed: () async {
              await _showWeatherNotificationNow();
              _showSnackBar('Đã hiển thị thông báo test');
            },
            tooltip: 'Test thông báo',
          ),
        ],
      ),
      body: !_isInitialized || notificationTime == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Đang khởi tạo ứng dụng...'),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () async {
                await _getCurrentLocation();
                if (notificationEnabled) {
                  await _scheduleWeatherNotification();
                }
              },
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      // Thông tin trạng thái Timer
                      // Card(
                      //   margin: EdgeInsets.all(10),
                      //   elevation: 3,
                      //   color: _isTimerActive
                      //       ? Colors.green[50]
                      //       : Colors.orange[50],
                      //   child: Padding(
                      //     padding: EdgeInsets.all(16),
                      //     child: Column(
                      //       crossAxisAlignment: CrossAxisAlignment.start,
                      //       children: [
                      //         Row(
                      //           children: [
                      //             Icon(
                      //               _isTimerActive
                      //                   ? Icons.timer
                      //                   : Icons.timer_off,
                      //               color: _isTimerActive
                      //                   ? Colors.green
                      //                   : Colors.orange,
                      //               size: 28,
                      //             ),
                      //             SizedBox(width: 8),
                      //             Text(
                      //               'Trạng thái Timer',
                      //               style: TextStyle(
                      //                 fontSize: 18,
                      //                 fontWeight: FontWeight.bold,
                      //                 color: _isTimerActive
                      //                     ? Colors.green[800]
                      //                     : Colors.orange[800],
                      //               ),
                      //             ),
                      //           ],
                      //         ),
                      //         SizedBox(height: 12),
                      //         Row(
                      //           children: [
                      //             Container(
                      //               width: 12,
                      //               height: 12,
                      //               decoration: BoxDecoration(
                      //                 shape: BoxShape.circle,
                      //                 color: _isTimerActive
                      //                     ? Colors.green
                      //                     : Colors.orange,
                      //               ),
                      //             ),
                      //             SizedBox(width: 8),
                      //             Text(
                      //               _timerStatus,
                      //               style: TextStyle(
                      //                 fontSize: 16,
                      //                 fontWeight: FontWeight.w600,
                      //               ),
                      //             ),
                      //           ],
                      //         ),
                      //         if (_nextNotificationTime.isNotEmpty) ...[
                      //           SizedBox(height: 8),
                      //           Row(
                      //             children: [
                      //               Icon(Icons.schedule,
                      //                   size: 16, color: Colors.blue),
                      //               SizedBox(width: 8),
                      //               Text(
                      //                 'Thông báo tiếp theo: $_nextNotificationTime',
                      //                 style: TextStyle(
                      //                   fontSize: 14,
                      //                   color: Colors.blue[700],
                      //                 ),
                      //               ),
                      //             ],
                      //           ),
                      //         ],
                      //         SizedBox(height: 8),
                      //         Container(
                      //           padding: EdgeInsets.all(8),
                      //           decoration: BoxDecoration(
                      //             color: Colors.blue.withOpacity(0.1),
                      //             borderRadius: BorderRadius.circular(8),
                      //             border: Border.all(
                      //                 color: Colors.blue.withOpacity(0.3)),
                      //           ),
                      //           child: Row(
                      //             children: [
                      //               Icon(Icons.info_outline,
                      //                   color: Colors.blue, size: 16),
                      //               SizedBox(width: 8),
                      //               Expanded(
                      //                 child: Text(
                      //                   'Timer sẽ tự động đặt lại mỗi ngày và hiển thị thông báo đúng giờ',
                      //                   style: TextStyle(
                      //                       fontSize: 12,
                      //                       color: Colors.blue[700]),
                      //                 ),
                      //               ),
                      //             ],
                      //           ),
                      //         ),
                      //       ],
                      //     ),
                      //   ),
                      // ),

                      // Cài đặt thông báo
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
                              SizedBox(height: 12),
                              SwitchListTile(
                                title:
                                    Text('Bật thông báo thời tiết hàng ngày'),
                                subtitle: Text(
                                  notificationEnabled
                                      ? 'Thông báo sẽ hiển thị vào ${formatTimeDisplay(notificationTime!)}'
                                      : 'Thông báo đã được tắt',
                                ),
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
                              Divider(),
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
                                leading: Icon(
                                  Icons.access_time,
                                  color: notificationEnabled
                                      ? Theme.of(context).primaryColor
                                      : Colors.grey,
                                ),
                                enabled: notificationEnabled,
                                onTap: () async {
                                  if (!notificationEnabled) return;
                                  final TimeOfDay? picked =
                                      await showTimePicker(
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
                                trailing: notificationEnabled
                                    ? Icon(Icons.edit)
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Thông tin vị trí
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
                                  Icon(Icons.location_on, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text(
                                    'Thông tin vị trí',
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),
                              ListTile(
                                title: Text('Vị trí hiện tại'),
                                subtitle: Text(
                                  _getCurrentLocationName(),
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                leading: Icon(Icons.location_city),
                              ),
                              if (currentPosition != null) ...[
                                ListTile(
                                  title: Text('Tọa độ'),
                                  subtitle: Text(
                                    'Lat: ${currentPosition!.latitude.toStringAsFixed(4)}, Lon: ${currentPosition!.longitude.toStringAsFixed(4)}',
                                    style: TextStyle(
                                        fontSize: 12, fontFamily: 'monospace'),
                                  ),
                                  leading: Icon(Icons.gps_fixed),
                                ),
                                ListTile(
                                  title: Text('Độ chính xác'),
                                  subtitle: Text(
                                      '${currentPosition!.accuracy.toStringAsFixed(1)}m'),
                                  leading: Icon(Icons.my_location),
                                ),
                              ],
                              ElevatedButton.icon(
                                onPressed: () async {
                                  setState(() {
                                    _timerStatus = 'Đang cập nhật vị trí...';
                                  });
                                  await _getCurrentLocation();
                                  if (notificationEnabled) {
                                    await _scheduleWeatherNotification();
                                  }
                                  _showSnackBar(
                                      'Đã cập nhật vị trí thành công');
                                },
                                icon: Icon(Icons.refresh),
                                label: Text('Cập nhật vị trí'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Thông tin hướng dẫn
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
                                      color: Colors.purple),
                                  SizedBox(width: 8),
                                  Text(
                                    'Hướng dẫn sử dụng',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),
                              // _buildInfoItem(
                              //   Icons.timer,
                              //   'Timer chính xác',
                              //   'Sử dụng Timer thay vì notification scheduling để đảm bảo thông báo hiện đúng giờ trên mọi thiết bị.',
                              //   Colors.green,
                              // ),
                              // SizedBox(height: 8),
                              // _buildInfoItem(
                              //   Icons.autorenew,
                              //   'Tự động lập lại',
                              //   'Timer sẽ tự động đặt lại mỗi ngày vào 00:01 để đảm bảo thông báo liên tục.',
                              //   Colors.blue,
                              // ),
                              // SizedBox(height: 8),
                              _buildInfoItem(
                                Icons.cloud,
                                'Dữ liệu thời tiết',
                                'Thông báo cung cấp dự báo chi tiết cho ngày mai bao gồm nhiệt độ, độ ẩm, gió và xác suất mưa.',
                                Colors.orange,
                              ),
                              // SizedBox(height: 8),
                              // _buildInfoItem(
                              //   Icons.phone_android,
                              //   'Hoạt động ở nền',
                              //   'App sẽ tự động kiểm tra và đặt lại timer khi được mở lại sau khi đóng.',
                              //   Colors.purple,
                              // ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildInfoItem(
      IconData icon, String title, String description, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color.withOpacity(0.8),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
