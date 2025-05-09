import 'package:frontend/models/note_model.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:developer';
import 'package:flutter/foundation.dart';

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

    return await openDatabase(
      path,
<<<<<<< HEAD
      version: 5, // Incremented version for new notes schema
=======
      version: 2,
>>>>>>> 5ac083889d9a16af0cc6cec4a1db08759213a99e
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onCreate(Database db, int version) async {
    log("Creating database tables...");
    await db.execute('''
    CREATE TABLE location(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
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
      notification_enabled INTEGER NOT NULL,
      notification_time TEXT NOT NULL DEFAULT '20:00'
    );
    ''');

    await db.execute('''
    CREATE TABLE search_history(
      location TEXT NOT NULL,
      searched_at TEXT NOT NULL,
      lat REAL NOT NULL,
      lon REAL NOT NULL
    );
<<<<<<< HEAD
    ''');
=======
  ''');
>>>>>>> 5ac083889d9a16af0cc6cec4a1db08759213a99e

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
<<<<<<< HEAD

    log("Database tables created with initial data.");
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    log("Upgrading database from version $oldVersion to $newVersion...");
    if (oldVersion < 2) {
      await db.execute('''
      CREATE TABLE notes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        content TEXT,
        reminderTime TEXT
      );
      ''');
      log("Notes table created during onUpgrade.");
    }
    if (oldVersion < 3) {
      await db.execute('DROP TABLE IF EXISTS weather_data');
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
      log("Weather_data table recreated during onUpgrade to version 3.");
    }
    if (oldVersion < 4) {
      await db.execute(
          'ALTER TABLE setting ADD COLUMN notification_time TEXT DEFAULT "20:00"');
      log("Added notification_time column to setting table during onUpgrade to version 4.");
    }
    if (oldVersion < 5) {
      // Drop and recreate notes table to add new fields
      await db.execute('DROP TABLE IF EXISTS notes');
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
      log("Notes table recreated with humidity, temperature, and location fields during onUpgrade to version 5.");
    }
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
=======
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
>>>>>>> 5ac083889d9a16af0cc6cec4a1db08759213a99e
  }

  Future<int> insertWeatherData(Map<String, dynamic> weatherData) async {
    final db = await database;
    try {
      return await db.insert(
        'weather_data',
        weatherData,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      log("Error inserting weather data: $e");
      rethrow;
    }
  }

  Future<int> insertLocation(Map<String, dynamic> location) async {
    final db = await database;
<<<<<<< HEAD
    if (location['name'] == null ||
        location['latitude'] == null ||
        location['longitude'] == null) {
      throw Exception(
          'Location data is incomplete: name, latitude, and longitude are required.');
    }
    try {
=======

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
>>>>>>> 5ac083889d9a16af0cc6cec4a1db08759213a99e
      return await db.insert(
        'location',
        location,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
<<<<<<< HEAD
    } catch (e) {
      log("Error inserting location: $e");
      rethrow;
    }
  }

  Future<int> updateLocation(Map<String, dynamic> location) async {
    final db = await database;
    try {
      return await db.update(
        'location',
        location,
        where: 'id = ?',
        whereArgs: [location['id']],
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      log("Error updating location: $e");
      rethrow;
=======
>>>>>>> 5ac083889d9a16af0cc6cec4a1db08759213a99e
    }
  }

  Future<int> insertHourlyData(Map<String, dynamic> hourlyData) async {
    final db = await database;
    try {
      return await db.insert(
        'hourly_data',
        hourlyData,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      log("Error inserting hourly data: $e");
      rethrow;
    }
  }

  Future<int> insertDailyData(Map<String, dynamic> dailyData) async {
    final db = await database;
    try {
      return await db.insert(
        'daily_data',
        dailyData,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      log("Error inserting daily data: $e");
      rethrow;
    }
  }

  Future<int> insertSetting(Map<String, dynamic> setting) async {
    final db = await database;
    try {
      return await db.insert(
        'setting',
        setting,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      log("Error inserting setting: $e");
      rethrow;
    }
  }

  Future<int> insertSearchHistory(Map<String, dynamic> searchHistory) async {
    final db = await database;
    try {
      return await db.insert(
        'search_history',
        searchHistory,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      log("Error inserting search history: $e");
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getAllLocations() async {
    final db = await database;
    try {
      return await db.query('location');
    } catch (e) {
      log("Error querying locations: $e");
      return [];
    }
  }

<<<<<<< HEAD
=======
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
>>>>>>> 5ac083889d9a16af0cc6cec4a1db08759213a99e
  Future<List<Map<String, dynamic>>> getAllWeatherData() async {
    final db = await database;
    try {
      return await db.query('weather_data');
    } catch (e) {
      log("Error querying weather data: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAllHourlyData() async {
    final db = await database;
    try {
      return await db.query('hourly_data');
    } catch (e) {
      log("Error querying hourly data: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAllDailyData() async {
    final db = await database;
    try {
      return await db.query('daily_data');
    } catch (e) {
      log("Error querying daily data: $e");
      return [];
    }
  }

  Future<void> deleteLocation(int id) async {
    final db = await database;
    try {
      await db.delete(
        'location',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      log("Error deleting location: $e");
      rethrow;
    }
  }

  Future<int> insertNote(Note note) async {
    final db = await database;
    try {
      final id = await db.insert(
        'notes',
        note.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return id; // Return the inserted ID
    } catch (e) {
      log("Error inserting note: $e");
      rethrow;
    }
  }

  Future<List<Note>> getNotes() async {
    final db = await database;
    try {
      final maps = await db.query('notes');
      return List.generate(maps.length, (i) => Note.fromMap(maps[i]));
    } catch (e) {
      log("Error querying notes: $e");
      return [];
    }
  }

  Future<int> deleteNote(int id) async {
    final db = await database;
    try {
      return await db.delete(
        'notes',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      log("Error deleting note: $e");
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getLocationById(int id) async {
    final db = await database;
    try {
      return await db.query(
        'location',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      log("Error querying location by ID: $e");
      return [];
    }
  }

<<<<<<< HEAD
=======
  // Get weather data by location ID
>>>>>>> 5ac083889d9a16af0cc6cec4a1db08759213a99e
  Future<List<Map<String, dynamic>>> getWeatherDataByLocationId(
      int locationId) async {
    final db = await database;
    try {
      return await db.query(
        'weather_data',
        where: 'location_id = ?',
        whereArgs: [locationId],
        orderBy: 'updatedAt DESC',
        limit: 1,
      );
    } catch (e) {
      log("Error querying weather data by location ID: $e");
      return [];
    }
  }

<<<<<<< HEAD
=======
  // Get hourly data by location ID
>>>>>>> 5ac083889d9a16af0cc6cec4a1db08759213a99e
  Future<List<Map<String, dynamic>>> getHourlyDataByLocationId(
      int locationId) async {
    final db = await database;
    try {
      return await db.query(
        'hourly_data',
        where: 'location_id = ?',
        whereArgs: [locationId],
        orderBy: 'time ASC',
      );
    } catch (e) {
      log("Error querying hourly data by location ID: $e");
      return [];
    }
  }

<<<<<<< HEAD
=======
  // Get daily data by location ID
>>>>>>> 5ac083889d9a16af0cc6cec4a1db08759213a99e
  Future<List<Map<String, dynamic>>> getDailyDataByLocationId(
      int locationId) async {
    final db = await database;
    try {
      return await db.query(
        'daily_data',
        where: 'location_id = ?',
        whereArgs: [locationId],
        orderBy: 'time ASC',
      );
    } catch (e) {
      log("Error querying daily data by location ID: $e");
      return [];
    }
  }

<<<<<<< HEAD
=======
  // Xóa hourly data theo location_id
>>>>>>> 5ac083889d9a16af0cc6cec4a1db08759213a99e
  Future<int> deleteHourlyDataByLocationId(int locationId) async {
    final db = await database;
    try {
      return await db.delete(
        'hourly_data',
        where: 'location_id = ?',
        whereArgs: [locationId],
      );
    } catch (e) {
      log("Error deleting hourly data by location ID: $e");
      rethrow;
    }
  }

<<<<<<< HEAD
=======
  // Xóa daily data theo location_id
>>>>>>> 5ac083889d9a16af0cc6cec4a1db08759213a99e
  Future<int> deleteDailyDataByLocationId(int locationId) async {
    final db = await database;
    try {
      return await db.delete(
        'daily_data',
        where: 'location_id = ?',
        whereArgs: [locationId],
      );
    } catch (e) {
      log("Error deleting daily data by location ID: $e");
      rethrow;
    }
  }

<<<<<<< HEAD
=======
  // Xóa weather data theo location_id
>>>>>>> 5ac083889d9a16af0cc6cec4a1db08759213a99e
  Future<int> deleteWeatherDataByLocationId(int locationId) async {
    final db = await database;
    try {
      return await db.delete(
        'weather_data',
        where: 'location_id = ?',
        whereArgs: [locationId],
      );
    } catch (e) {
      log("Error deleting weather data by location ID: $e");
      rethrow;
    }
  }

  Future<void> resetDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'weather.db');

    if (_database != null) {
      await _database!.close();
      _database = null;
    }

    await deleteDatabase(path);
    _database = await _initDatabase();

    log("Database has been completely reset!");
  }

<<<<<<< HEAD
=======
  // Phương thức xóa dữ liệu nhưng giữ cấu trúc bảng
>>>>>>> 5ac083889d9a16af0cc6cec4a1db08759213a99e
  Future<void> clearAllData() async {
    final db = await database;
    try {
      await db.delete('weather_data');
      await db.delete('hourly_data');
      await db.delete('daily_data');
      await db.delete('search_history');
      await db.delete('notes');
      log("All data has been cleared from the database!");
    } catch (e) {
      log("Error clearing all data: $e");
      rethrow;
    }
  }

  Future<int> insertNote(Note note) async {
    final db = await database;
    try {
      final id = await db.insert(
        'notes',
        note.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return id; // Return the inserted ID
    } catch (e) {
      log("Error inserting note: $e");
      rethrow;
    }
  }

  Future<List<Note>> getNotes() async {
    final db = await database;
    try {
      final maps = await db.query('notes');
      return List.generate(maps.length, (i) => Note.fromMap(maps[i]));
    } catch (e) {
      log("Error querying notes: $e");
      return [];
    }
  }

  Future<int> deleteNote(int id) async {
    final db = await database;
    try {
      return await db.delete(
        'notes',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      log("Error deleting note: $e");
      rethrow;
    }
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
