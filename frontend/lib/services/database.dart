import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:frontend/models/note_model.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:developer';
import 'package:flutter/foundation.dart'; // Để kiểm tra chế độ debug

Future<void> deleteWeatherDBIfDebug() async {
  if (kDebugMode) {
    final path = join(await getDatabasesPath(), 'weather.db');
    await deleteDatabase(path);
    log("DEBUG MODE: Database deleted at $path");
  }
}

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await initDatabase();
    return _database!;
  }

  Future<Database> initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'weather.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
    CREATE TABLE location(
      id INTEGER PRIMARY KEY,
      name TEXT NOT NULL,
      latitude REAL NOT NULL,
      longitude REAL NOT NULL,
      is_current INTEGER DEFAULT 0
    );
  ''');

    await db.execute('''
    CREATE TABLE weather_data(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      location_id INTEGER NOT NULL,
      temperature REAL,
      feelsLike REAL,
      maxTemp REAL,
      minTemp REAL,
      pressure INTEGER,
      humidity INTEGER,
      windSpeed REAL,
      windDeg REAL,
      windGust REAL,
      icon TEXT,
      timeZone INTEGER,
      cloud INTEGER,
      visibility INTEGER,
      sunrise INTEGER,
      sunset INTEGER,
      description TEXT,
      main TEXT,
      updatedAt TEXT,
      FOREIGN KEY (location_id) REFERENCES location(id) ON DELETE CASCADE
    );
  ''');

    await db.execute('''
    CREATE TABLE hourly_data(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      location_id INTEGER NOT NULL,
      time INTEGER,
      temperatureMax REAL,
      temperatureMin REAL,
      humidity INTEGER,
      icon TEXT,
      FOREIGN KEY (location_id) REFERENCES location(id) ON DELETE CASCADE
    );
  ''');

    await db.execute('''
    CREATE TABLE daily_data(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      location_id INTEGER NOT NULL,
      time INTEGER,
      temperatureMax REAL,
      temperatureMin REAL,
      humidity INTEGER,
      icon TEXT,
      FOREIGN KEY (location_id) REFERENCES location(id) ON DELETE CASCADE
    );
  ''');

    await db.execute('''
    CREATE TABLE setting(
      unit TEXT NOT NULL,
      theme TEXT NOT NULL,
      language TEXT NOT NULL,
      notification_enabled INTEGER NOT NULL
    );
  ''');

    await db.execute('''
    CREATE TABLE search_history(
      location TEXT NOT NULL,
      searched_at TEXT NOT NULL,
      lat REAL NOT NULL,
      lon REAL NOT NULL
    );
  ''');

    await db.execute('''
    CREATE TABLE notes(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      content TEXT NOT NULL,
      reminderTime TEXT NOT NULL,
      humidity REAL NOT NULL,
      temperature REAL NOT NULL,
      location TEXT NOT NULL
    );
    ''');

    // Insert initial settings
    await db.insert('setting', {
      'unit': 'metric',
      'theme': 'light',
      'language': 'vi',
      'notification_enabled': 1,
      'notification_time': '20:00',
    });
  }

  // Phương thức để xử lý nâng cấp database
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Thêm cột is_current vào bảng location nếu chưa tồn tại
      try {
        // Kiểm tra xem cột đã tồn tại chưa
        var result = await db.rawQuery('PRAGMA table_info(location)');
        bool hasIsCurrentColumn = false;
        for (var column in result) {
          if (column['name'] == 'is_current') {
            hasIsCurrentColumn = true;
            break;
          }
        }

        if (!hasIsCurrentColumn) {
          await db.execute(
              'ALTER TABLE location ADD COLUMN is_current INTEGER DEFAULT 0');
          log("Added is_current column to location table");
        }
      } catch (e) {
        log("Error upgrading database: $e");
      }
    }
  }

  Future<int> insertWeatherData(Map<String, dynamic> weatherData) async {
    final db = await database;
    return await db.insert(
      'weather_data',
      weatherData,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> insertLocation(Map<String, dynamic> location) async {
    final db = await database;

    // Kiểm tra xem địa điểm đã tồn tại chưa (dựa trên tên)
    final List<Map<String, dynamic>> existingLocations =
        await getLocationByName(location['name']);

    if (existingLocations.isNotEmpty) {
      // Nếu địa điểm đã tồn tại, cập nhật thông tin
      int locationId = existingLocations.first['id'];
      await db.update(
        'location',
        location,
        where: 'id = ?',
        whereArgs: [locationId],
      );
      return locationId;
    } else {
      // Nếu là địa điểm mới, thêm vào database
      return await db.insert(
        'location',
        location,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<int> insertHourlyData(Map<String, dynamic> hourlyData) async {
    final db = await database;
    return await db.insert(
      'hourly_data',
      hourlyData,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> insertDailyData(Map<String, dynamic> dailyData) async {
    final db = await database;
    return await db.insert(
      'daily_data',
      dailyData,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> insertSetting(Map<String, dynamic> setting) async {
    final db = await database;
    return await db.insert(
      'setting',
      setting,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> insertSearchHistory(Map<String, dynamic> searchHistory) async {
    final db = await database;
    return await db.insert(
      'search_history',
      searchHistory,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Truy vấn tất cả dữ liệu từ bảng location
  Future<List<Map<String, dynamic>>> getAllLocations() async {
    final db = await database;
    return await db.query('location');
  }

  // Tìm địa điểm theo tên
  Future<List<Map<String, dynamic>>> getLocationByName(String name) async {
    final db = await database;
    return await db.query(
      'location',
      where: 'name = ?',
      whereArgs: [name],
    );
  }

  // Cập nhật trường is_current cho tất cả các vị trí
  Future<void> resetCurrentLocation() async {
    final db = await database;
    await db.update(
      'location',
      {'is_current': 0},
      where: 'is_current = ?',
      whereArgs: [1],
    );
  }

  // Cập nhật vị trí hiện tại
  Future<void> setCurrentLocation(int locationId) async {
    final db = await database;

    // Đặt lại tất cả vị trí thành không phải vị trí hiện tại
    await resetCurrentLocation();

    // Đặt vị trí có id được chỉ định thành vị trí hiện tại
    await db.update(
      'location',
      {'is_current': 1},
      where: 'id = ?',
      whereArgs: [locationId],
    );
  }

  // Lấy vị trí hiện tại
  Future<List<Map<String, dynamic>>> getCurrentLocation() async {
    final db = await database;
    return await db.query(
      'location',
      where: 'is_current = ?',
      whereArgs: [1],
    );
  }

  // Truy vấn tất cả dữ liệu từ bảng weather_data
  Future<List<Map<String, dynamic>>> getAllWeatherData() async {
    final db = await database;
    return await db.query('weather_data');
  }

  // Truy vấn tất cả dữ liệu từ bảng hourly_data
  Future<List<Map<String, dynamic>>> getAllHourlyData() async {
    final db = await database;
    return await db.query('hourly_data');
  }

  // Truy vấn tất cả dữ liệu từ bảng daily_data
  Future<List<Map<String, dynamic>>> getAllDailyData() async {
    final db = await database;
    return await db.query('daily_data');
  }

  // Phương thức xóa địa điểm
  Future<void> deleteLocation(int id) async {
    final db = await database;
    await db.delete(
      'location', // Tên bảng
      where: 'id = ?', // Điều kiện xóa
      whereArgs: [id], // Tham số
    );
  }

  // Future<void> showImmediateNotification({
  //   required int id,
  //   required String title,
  //   required String body,
  // }) async {
  //   // Tùy thuộc vào plugin thông báo bạn đang sử dụng
  //   // Ví dụ với flutter_local_notifications:
  //   const AndroidNotificationDetails androidDetails =
  //       AndroidNotificationDetails(
  //     'weather_channel_id',
  //     'Weather Notifications',
  //     channelDescription: 'Channel for weather notifications',
  //     importance: Importance.high,
  //     priority: Priority.high,
  //   );

  //   const NotificationDetails platformDetails = NotificationDetails(
  //     android: androidDetails,
  //   );

  //   await flutterLocalNotificationsPlugin.show(
  //     id,
  //     title,
  //     body,
  //     platformDetails,
  //   );
  // }

  // Get location by ID
  Future<List<Map<String, dynamic>>> getLocationById(int id) async {
    final db = await database;
    return await db.query(
      'location',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Get weather data by location ID
  Future<List<Map<String, dynamic>>> getWeatherDataByLocationId(
      int locationId) async {
    final db = await database;
    return await db.query(
      'weather_data',
      where: 'location_id = ?',
      whereArgs: [locationId],
      orderBy: 'updatedAt DESC', // Get most recent first
      limit: 1,
    );
  }

  // Get hourly data by location ID
  Future<List<Map<String, dynamic>>> getHourlyDataByLocationId(
      int locationId) async {
    final db = await database;
    return await db.query(
      'hourly_data',
      where: 'location_id = ?',
      whereArgs: [locationId],
      orderBy: 'time ASC', // Order by time
    );
  }

  // Get daily data by location ID
  Future<List<Map<String, dynamic>>> getDailyDataByLocationId(
      int locationId) async {
    final db = await database;
    return await db.query(
      'daily_data',
      where: 'location_id = ?',
      whereArgs: [locationId],
      orderBy: 'time ASC', // Order by time
    );
  }

  // Xóa hourly data theo location_id
  Future<int> deleteHourlyDataByLocationId(int locationId) async {
    final db = await database;
    return await db.delete(
      'hourly_data',
      where: 'location_id = ?',
      whereArgs: [locationId],
    );
  }

  // Xóa daily data theo location_id
  Future<int> deleteDailyDataByLocationId(int locationId) async {
    final db = await database;
    return await db.delete(
      'daily_data',
      where: 'location_id = ?',
      whereArgs: [locationId],
    );
  }

  // Xóa weather data theo location_id
  Future<int> deleteWeatherDataByLocationId(int locationId) async {
    final db = await database;
    return await db.delete(
      'weather_data',
      where: 'location_id = ?',
      whereArgs: [locationId],
    );
  }

  // Thêm vào class DatabaseHelper
  Future<void> resetDatabase() async {
    // Xóa toàn bộ database và tạo lại từ đầu
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'weather.db');

    // Đóng connection hiện tại nếu có
    if (_database != null) {
      await _database!.close();
      _database = null;
    }

    // Xóa file database
    await deleteDatabase(path);

    // Khởi tạo lại database
    _database = await initDatabase();

    log("Database has been completely reset!");
  }

  // Phương thức xóa dữ liệu nhưng giữ cấu trúc bảng
  Future<void> clearAllData() async {
    final db = await database;

    // Xóa dữ liệu từ tất cả các bảng
    await db.delete('weather_data');
    await db.delete('hourly_data');
    await db.delete('daily_data');
    await db.delete('search_history');

    // Chỉ giữ lại location nếu cần
    // await db.delete('location');

    log("All weather data has been cleared from the database!");
  }

  Future<Map<String, dynamic>?> getSettings() async {
    final db = await database;
    final settings = await db.query('setting', limit: 1);
    return settings.isNotEmpty ? settings.first : null;
  }

  Future<int> updateSettings(Map<String, dynamic> settings) async {
    final db = await database;
    return await db.update(
      'setting',
      settings,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
