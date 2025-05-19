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
      version: 2, // Tăng version để hỗ trợ onUpgrade
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
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      unit TEXT NOT NULL,
      theme TEXT NOT NULL,
      language TEXT NOT NULL,
      notification_enabled INTEGER NOT NULL,
      notification_time TEXT DEFAULT "20:00",
      notification_date TEXT
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

    // Chèn cài đặt mặc định
    await db.insert('setting', {
      'unit': 'metric',
      'theme': 'light',
      'language': 'vi',
      'notification_enabled': 1,
      'notification_time': '20:00',
      'notification_date': DateTime.now().toIso8601String(),
    });
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Thêm cột notification_time và notification_date nếu chưa có
      try {
        await db.execute(
            'ALTER TABLE setting ADD COLUMN notification_time TEXT DEFAULT "20:00"');
        print('Added notification_time column to setting table');
      } catch (e) {
        print('Error adding notification_time column: $e');
      }

      try {
        await db
            .execute('ALTER TABLE setting ADD COLUMN notification_date TEXT');
        print('Added notification_date column to setting table');
      } catch (e) {
        print('Error adding notification_date column: $e');
      }

      // Thêm cột is_current vào bảng location nếu chưa có
      try {
        await db.execute(
            'ALTER TABLE location ADD COLUMN is_current INTEGER DEFAULT 0');
        print('Added is_current column to location table');
      } catch (e) {
        print('Error adding is_current column: $e');
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

  Future<int> updateSettings(Map<String, dynamic> settings) async {
    final db = await database;
    // Kiểm tra xem có bản ghi cài đặt nào chưa
    final existingSettings = await db.query('setting', limit: 1);
    if (existingSettings.isEmpty) {
      // Nếu không có, chèn mới
      return await db.insert(
        'setting',
        settings,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      // Nếu có, cập nhật bản ghi đầu tiên
      return await db.update(
        'setting',
        settings,
        where: 'id = ?',
        whereArgs: [existingSettings.first['id']],
      );
    }
  }

  Future<Map<String, dynamic>> getSettings() async {
    final db = await database;
    final result = await db.query('setting', limit: 1);
    return result.isNotEmpty ? result.first : {};
  }

  Future<int> insertSearchHistory(Map<String, dynamic> searchHistory) async {
    final db = await database;
    return await db.insert(
      'search_history',
      searchHistory,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getAllLocations() async {
    final db = await database;
    return await db.query('location');
  }

  Future<List<Map<String, dynamic>>> getAllWeatherData() async {
    final db = await database;
    return await db.query('weather_data');
  }

  Future<List<Map<String, dynamic>>> getAllHourlyData() async {
    final db = await database;
    return await db.query('hourly_data');
  }

  Future<List<Map<String, dynamic>>> getAllDailyData() async {
    final db = await database;
    return await db.query('daily_data');
  }

  Future<void> deleteLocation(int id) async {
    final db = await database;
    await db.delete(
      'location',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getLocationById(int id) async {
    final db = await database;
    return await db.query(
      'location',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getWeatherDataByLocationId(
      int locationId) async {
    final db = await database;
    return await db.query(
      'weather_data',
      where: 'location_id = ?',
      whereArgs: [locationId],
      orderBy: 'updatedAt DESC',
      limit: 1,
    );
  }

  Future<List<Map<String, dynamic>>> getHourlyDataByLocationId(
      int locationId) async {
    final db = await database;
    return await db.query(
      'hourly_data',
      where: 'location_id = ?',
      whereArgs: [locationId],
      orderBy: 'time ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getDailyDataByLocationId(
      int locationId) async {
    final db = await database;
    return await db.query(
      'daily_data',
      where: 'location_id = ?',
      whereArgs: [locationId],
      orderBy: 'time ASC',
    );
  }

  Future<int> deleteHourlyDataByLocationId(int locationId) async {
    final db = await database;
    return await db.delete(
      'hourly_data',
      where: 'location_id = ?',
      whereArgs: [locationId],
    );
  }

  Future<int> deleteDailyDataByLocationId(int locationId) async {
    final db = await database;
    return await db.delete(
      'daily_data',
      where: 'location_id = ?',
      whereArgs: [locationId],
    );
  }

  Future<int> deleteWeatherDataByLocationId(int locationId) async {
    final db = await database;
    return await db.delete(
      'weather_data',
      where: 'location_id = ?',
      whereArgs: [locationId],
    );
  }

  Future<void> resetDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'weather.db');

    if (_database != null) {
      await _database!.close();
      _database = null;
    }

    await deleteDatabase(path);
    _database = await initDatabase();
    log("Database has been completely reset!");
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('weather_data');
    await db.delete('hourly_data');
    await db.delete('daily_data');
    await db.delete('search_history');
    log("All weather data has been cleared from the database!");
  }

  Future<List<Map<String, dynamic>>> getLocationByName(String name) async {
    final db = await database;
    return await db.query(
      'location',
      where: 'name = ?',
      whereArgs: [name],
    );
  }

  Future<void> resetCurrentLocation() async {
    final db = await database;
    await db.update(
      'location',
      {'is_current': 0},
    );
  }

  Future<void> updateLocation(int id, Map<String, dynamic> location) async {
    final db = await database;
    await db.update(
      'location',
      location,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> setCurrentLocation(int id) async {
    final db = await database;
    await resetCurrentLocation();
    await db.update(
      'location',
      {'is_current': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateLocationSchema() async {
    final db = await database;
    var tableInfo = await db.rawQuery("PRAGMA table_info(location)");
    bool hasIsCurrentColumn =
        tableInfo.any((column) => column['name'] == 'is_current');

    if (!hasIsCurrentColumn) {
      try {
        await db.execute(
            'ALTER TABLE location ADD COLUMN is_current INTEGER DEFAULT 0');
        print('Added is_current column to location table');
      } catch (e) {
        print('Error adding is_current column: $e');
      }
    }
  }
}
