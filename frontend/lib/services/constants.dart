import 'package:geolocator/geolocator.dart';

Position? KeyLocation;
String? LocationName;
String? InitialName;
String? type = 'metric';
String? lang = 'vi-vn';
String API_KEY = '2b5630205440fa5d9747bc910681e783';

String OfficialName(String name) {
  List<String> parts = name.split(',').map((e) => e.trim()).toList();
  return parts[0];
}