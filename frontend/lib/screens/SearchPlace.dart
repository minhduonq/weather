import 'dart:convert';
import 'package:frontend/screens/manage_location.dart';

import '../services/constants.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/database.dart';

class SearchPlace extends StatefulWidget {
  @override
  _SearchPlaceState createState() => _SearchPlaceState();
}

class _SearchPlaceState extends State<SearchPlace> {
  TextEditingController _searchController = TextEditingController();
  List<String> _places = [];
  Future<void> _searchPlaces(String query) async {

    query = query.replaceAll(' ', '+');

    String apiKey = 't8j30ZcKTjahgwuPbHRDWmqx1JXdaBg4Lz7a82tixWs';
    String coordinates = '21,104';

    // Construct the API URL
    String apiUrl =
        'https://discover.search.hereapi.com/v1/discover?at=$coordinates&q=$query&apiKey=$apiKey';

    // Make the API call
    var response = await http.get(Uri.parse(apiUrl));

    if (response.statusCode == 200) {
      // Parse the response JSON
      data = json.decode(utf8.decode(response.bodyBytes));
      List<dynamic> items = data['items'];

      // Clear previous places
      _places.clear();

      // Add places with resultType 'locality' to the list
      for (var item in items) {
        if (item['resultType'] == 'locality' ) {
          _places.add(item['address']['label']);
        }
        if(item['resultType'] == 'administrativeArea') {
          _places.add(item['address']['label']);
        }
      }
      // Update the UI
      setState(() {});
    } else {
      // Handle API call error
      print('Failed to fetch data: ${response.statusCode}');
    }
  }
  void _selectPlace(String selectedPlace, int index) async {
    double lat = data['items'][index]['position']['lat'];
    double lon = data['items'][index]['position']['lng'];
    String name = OfficialName(selectedPlace);

    try {
    // Gọi API OpenWeatherMap để lấy ID và thông tin thời tiết
    final uri = 'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$API_KEY&units=$type';
    final response = await http.get(Uri.parse(uri));
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      
      // Lấy ID từ OpenWeather API
      final locationId = data['id'];
      
      // Lưu vào database
      final dbHelper = DatabaseHelper();
      
      // Lưu location trước
      final locationData = {
        'id': locationId,
        'name': name,
        'latitude': lat,
        'longitude': lon,
      };
      await dbHelper.insertLocation(locationData);
      
      // Lưu weather data
      final weatherData = {
        'location_id': locationId,
        'temperature': data['main']['temp'],
        'feelsLike': data['main']['feels_like'],
        'maxTemp': data['main']['temp_max'],
        'minTemp': data['main']['temp_min'],
        'pressure': data['main']['pressure'],
        'humidity': data['main']['humidity'],
        'windSpeed': data['wind']['speed'],
        'icon': data['weather'][0]['icon'],
        'description': data['weather'][0]['description'],
        'sunrise': data['sys']['sunrise'],
        'sunset': data['sys']['sunset'],
        'cloud': data['clouds']['all'],
        'visibility': data['visibility'],
        'timeZone': data['timezone'],
        'updatedAt': DateTime.now().toIso8601String(),
      };
      await dbHelper.insertWeatherData(weatherData);
      
      // Tiếp tục tải dữ liệu dự báo (hourly và daily)
      // await _fetchForecastData(lat, lng, locationId);
      
      // Đóng dialog loading
      Navigator.pop(context);
      
      // Hiển thị thông báo thành công
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name đã được lưu thành công')),
      );
    } else {
      // Đóng dialog loading
      Navigator.pop(context);
      
      // Hiển thị thông báo lỗi
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể tải dữ liệu thời tiết. Vui lòng thử lại sau.')),
      );
    }
  } catch (e) {
    // Đóng dialog loading
    Navigator.pop(context);
    
    // Hiển thị thông báo lỗi
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã xảy ra lỗi: $e')),
    );
  }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Search Places'),
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.only(left: 10, right: 10),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10)
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Type your place name',
                suffixIcon: IconButton(
                  icon: Icon(Icons.search),
                  onPressed: () {
                    _searchPlaces(_searchController.text);
                  },
                ),
              ),
            ),
          ),

          Expanded(
            child: ListView.builder(
              itemCount: _places.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(_places[index]),
                  onTap: () {
                    _selectPlace(_places[index], index);
                    Navigator.of(context).push(MaterialPageRoute(builder: (context) => ManageLocationsScreen()));
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}