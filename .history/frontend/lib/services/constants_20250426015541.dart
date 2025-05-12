import 'package:geolocator/geolocator.dart';

Position? KeyLocation;
Position? currentPosition;
String? LocationName = '';
String? InitialName;
String? type = 'metric';
String? lang = 'vi-vn';
String API_KEY = '2b5630205440fa5d9747bc910681e783';
String HereAPI = 't8j30ZcKTjahgwuPbHRDWmqx1JXdaBg4Lz7a82tixWs';
List<Map<String, dynamic>> selectedPlaces = [];
Map<String, dynamic> data = {};

String OfficialName(String name) {
  List<String> parts = name.split(',').map((e) => e.trim()).toList();
  return parts[0];
}
