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
      version: 5, // Incremented version for new notes schema
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
      longitude REAL NOT NULL
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
    if (location['name'] == null ||
        location['latitude'] == null ||
        location['longitude'] == null) {
      throw Exception(
          'Location data is incomplete: name, latitude, and longitude are required.');
    }
    try {
      return await db.insert(
        'location',
        location,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
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
}
