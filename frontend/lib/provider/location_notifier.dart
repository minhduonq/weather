import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../services/database.dart';

class LocationNotifier extends ChangeNotifier {
  List<Map<String, dynamic>> _locations = [];
  Position? _currentPosition;
  String? _currentLocationName;

  List<Map<String, dynamic>> get locations => _locations;
  Position? get currentPosition => _currentPosition;
  String? get currentLocationName => _currentLocationName;

  Future<void> refreshLocations() async {
    final db = DatabaseHelper();
    final dbLocations = await db.getAllLocations();
    _locations = [];

    // Add current position
    if (_currentPosition != null && _currentLocationName != null) {
      _locations.add({
        'id': 0,
        'name': _currentLocationName,
        'latitude': _currentPosition!.latitude,
        'longitude': _currentPosition!.longitude,
        'is_current': true,
      });
    }

    // Add stored locations
    for (var location in dbLocations) {
      if (location['name'] != _currentLocationName) {
        _locations.add({
          'id': location['id'],
          'name': location['name'],
          'latitude': location['latitude'],
          'longitude': location['longitude'],
          'is_current': location['is_current'] == 1,
        });
      }
    }

    // Sort to put current location first
    _locations.sort((a, b) {
      if (a['is_current'] == true) return -1;
      if (b['is_current'] == true) return 1;
      return 0;
    });

    notifyListeners();
  }

  Future<void> setCurrentPosition(Position position, String name) async {
    _currentPosition = position;
    _currentLocationName = name;
    await refreshLocations();
  }

  Future<void> deleteLocation(int id) async {
    final db = DatabaseHelper();
    await db.deleteLocation(id);
    await refreshLocations();
  }

  Future<void> addLocation(Map<String, dynamic> locationData) async {
    final db = DatabaseHelper();
    await db.insertLocation(locationData);
    await refreshLocations();
  }
}
