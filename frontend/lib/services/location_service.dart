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
}
