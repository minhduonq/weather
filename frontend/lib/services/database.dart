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
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'weather.db');

    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
    CREATE TABLE location(
      id INTEGER PRIMARY KEY,
      name TEXT NOT NULL,
      latitude REAL NOT NULL,
      longitude REAL NOT NULL,
      is_current BOOLEAN NOT NULL DEFAULT 0
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
  }

  Future<void> saveCurrentLocation(
      double latitude, double longitude, String name) async {
    final db = await database;

    // First, reset all locations to not be current
    await db.update('location', {'is_current': 0},
        where: 'is_current = ?', whereArgs: [1]);

    // Check if a location with these coordinates already exists
    List<Map<String, dynamic>> existingLocations = await db.query('location',
        where: 'latitude = ? AND longitude = ?',
        whereArgs: [latitude, longitude]);

    if (existingLocations.isNotEmpty) {
      // Update existing location to be current
      await db.update('location', {'is_current': 1, 'name': name},
          where: 'id = ?', whereArgs: [existingLocations.first['id']]);
      return;
    }

    // Insert new location as current
    await db.insert('location', {
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'is_current': 1
    });
  }

  Future<Map<String, dynamic>?> getCurrentLocation() async {
    final db = await database;
    final results = await db.query('location',
        where: 'is_current = ?', whereArgs: [1], limit: 1);

    if (results.isNotEmpty) {
      return results.first;
    }
    return null;
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
    return await db.insert(
      'location',
      location,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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
    _database = await _initDatabase();

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
}
