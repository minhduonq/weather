import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:frontend/services/database.dart';
import 'package:http/http.dart' as http;

class AddLocationScreen extends StatefulWidget {
  @override
  _AddLocationScreenState createState() => _AddLocationScreenState();
}

class _AddLocationScreenState extends State<AddLocationScreen> {
  final TextEditingController _cityController = TextEditingController();
  final String apiKey =
      '2b5630205440fa5d9747bc910681e783'; // Thay bằng API key của bạn
  String _errorMessage = '';
  bool _isLoading = false;

  // Check if the city exists by making an API call to OpenWeatherMap
  Future<bool> validateCity(String cityName) async {
    if (cityName.isEmpty || cityName.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Vui lòng nhập tên thành phố.';
      });
      return false;
    }

    final url =
        'https://api.openweathermap.org/data/2.5/weather?q=${Uri.encodeComponent(cityName)}&appid=$apiKey&units=metric&lang=vi';
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return true; // City exists
      } else {
        setState(() {
          _errorMessage =
              'Không tìm thấy thành phố "$cityName". Vui lòng thử lại.';
        });
        return false;
      }
    } catch (e) {
      setState(() {
        _errorMessage =
            'Có lỗi xảy ra khi kiểm tra thành phố. Vui lòng thử lại.';
      });
      return false;
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Save the location to the database and return to the previous screen
  Future<void> saveLocation() async {
    final cityName = _cityController.text.trim();
    final isValid = await validateCity(cityName);
    if (isValid) {
      final db = DatabaseHelper();
      // Fetch coordinates for the city
      final weatherData = await fetchWeather(cityName);
      if (weatherData != null) {
        await db.insertLocation({
          'name': cityName,
          'latitude': weatherData['coord']['lat'],
          'longitude': weatherData['coord']['lon'],
        });
        Navigator.pop(
            context, true); // Return true to indicate a location was added
      } else {
        setState(() {
          _errorMessage = 'Không thể lấy tọa độ cho thành phố "$cityName".';
        });
      }
    }
  }

  Future<Map<String, dynamic>?> fetchWeather(String cityName) async {
    final url =
        'https://api.openweathermap.org/data/2.5/weather?q=${Uri.encodeComponent(cityName)}&appid=$apiKey&units=metric&lang=vi';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('Failed to fetch weather for $cityName: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error fetching weather for $cityName: $e');
      return null;
    }
  }

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Center(
          child: Text(
            'Thêm địa điểm',
            style: TextStyle(color: Colors.black),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.check, color: Colors.black),
            onPressed: _isLoading ? null : saveLocation,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _cityController,
              decoration: InputDecoration(
                labelText: 'Tên thành phố',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: Icon(Icons.location_city),
              ),
              onSubmitted: (_) => saveLocation(),
            ),
            if (_errorMessage.isNotEmpty) ...[
              SizedBox(height: 16),
              Text(
                _errorMessage,
                style: TextStyle(color: Colors.red, fontSize: 14),
              ),
            ],
            if (_isLoading) ...[
              SizedBox(height: 16),
              Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }
}
