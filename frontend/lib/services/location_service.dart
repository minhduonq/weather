import 'package:frontend/services/database.dart';
import 'package:frontend/services/weather_service.dart';
import 'package:geolocator/geolocator.dart';
import 'constants.dart';

class LocationService {
  // Request location permission and handle responses
  static Future<bool> requestLocationPermission() async {
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
    try {
      return await Geolocator.getCurrentPosition();
    } catch (e) {
      print('Error getting current location: $e');
      return null;
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
