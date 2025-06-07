import 'package:frontend/services/database.dart';
import 'package:frontend/services/weather_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'constants.dart';

class LocationService {
  // Hàm tạo vị trí mặc định (Hồ Chí Minh)
  static Position getDefaultPosition() {
    return Position(
      latitude: 10.8231,
      longitude: 106.6297,
      timestamp: DateTime.now(),
      accuracy: 0.0,
      altitude: 0.0,
      heading: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
      altitudeAccuracy: 0.0,
      headingAccuracy: 0.0,
    );
  }

  // Request location permission and handle responses
  static Future<bool> requestLocationPermission() async {
    // Nếu đang chạy trên máy ảo và ở chế độ debug, luôn trả về true
    if (kDebugMode) {
      print('Debug mode: Location permission granted automatically');
      return true;
    }

    bool servicePermission = await Geolocator.isLocationServiceEnabled();
    if (!servicePermission) {
      print('Location services disabled');
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      print('Location permission denied permanently');
      return false;
    }

    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  // Get current location
  static Future<Position?> getCurrentLocation() async {
    // Nếu đang chạy trên máy ảo và ở chế độ debug, trả về vị trí mặc định
    if (kDebugMode) {
      print('Debug mode: Using default location (Ho Chi Minh City)');
      return getDefaultPosition();
    }

    try {
      // Thêm timeout để không phải chờ quá lâu
      Position? position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 5),
      );
      return position;
    } catch (e) {
      print('Error getting current location: $e');
      // Nếu có lỗi, trả về vị trí mặc định
      print('Falling back to default location');
      return getDefaultPosition();
    }
  }
  // Get current location and save to database
  static Future<Position?> getCurrentLocationAndSave() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      if (position != null) {
        final dbHelper = DatabaseHelper();
        // Get location name first (using your existing getLocationName function)
        await WeatherService.getLocationName(
            position.latitude, position.longitude);
        String locationName = InitialName ?? 'Current Location';

        // Save to database
        await dbHelper.saveCurrentLocation(
            position.latitude, position.longitude, locationName);
      }
      return position;
    } catch (e) {
      print('Error getting and saving current location: $e');
      return null;
    }
  }
}
