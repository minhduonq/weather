import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:frontend/screens/add_location_screen.dart';
import 'package:frontend/services/database.dart';
import 'package:frontend/widgets/modals/show_custom.dart';
import 'package:http/http.dart' as http; // For making API calls
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

class WeatherStorageScreen extends StatefulWidget {
  @override
  _WeatherStorageScreenState createState() => _WeatherStorageScreenState();
}

class _WeatherStorageScreenState extends State<WeatherStorageScreen> {
  List<Map<String, dynamic>> favouriteLocations = [];
  List<Map<String, dynamic>> otherLocations = [];
  List<Map<String, dynamic>> allLocations = [];
  String searchQuery = "";

  // Replace with your OpenWeatherMap API key
  final String apiKey = '2b5630205440fa5d9747bc910681e783';

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('vi', null).then((_) {
      loadLocations();
    });
  }

  Future<void> loadLocations() async {
    final db = DatabaseHelper();
    final locations = await db.getAllLocations();

    // Fetch weather data for each location
    List<Map<String, dynamic>> weatherDataList = [];
    for (var location in locations) {
      final weather = await fetchWeather(location['name']);
      if (weather != null) {
        weatherDataList.add({
          'location_id': location['id'],
          'temperature': weather['main']['temp'],
          'feelsLike': weather['main']['feels_like'],
          'maxTemp': weather['main']['temp_max'], // Sửa temp_high thành maxTemp
          'minTemp': weather['main']['temp_min'], // Sửa temp_low thành minTemp
          'pressure': weather['main']['pressure'],
          'humidity': weather['main']['humidity'],
          'windSpeed': weather['wind']['speed'],
          'windDeg': weather['wind']['deg'],
          'windGust':
              weather['wind']['gust'] ?? 0.0, // Nếu không có, để mặc định 0.0
          'icon': weather['weather'][0]['icon'],
          'timeZone': weather['timezone'],
          'cloud': weather['clouds']['all'],
          'visibility': weather['visibility'],
          'sunrise': weather['sys']['sunrise'],
          'sunset': weather['sys']['sunset'],
          'description': weather['weather'][0]['description'],
          'main': weather['weather'][0]['main'],
          'updatedAt': DateTime.fromMillisecondsSinceEpoch(weather['dt'] * 1000)
              .toIso8601String(), // Sửa date thành updatedAt
        });
      }
    }

    // Save weather data to database
    for (var weather in weatherDataList) {
      await db.insertWeatherData(weather);
    }

    final storedWeatherData = await db.getAllWeatherData();
    final weatherByLocation = {
      for (var w in storedWeatherData) w['location_id']: w,
    };

    setState(() {
      allLocations = locations;
      if (locations.isNotEmpty) {
        favouriteLocations = [locations.first];
        otherLocations = locations.skip(1).toList();
      }

      favouriteLocations = favouriteLocations.map((loc) {
        return {
          ...loc,
          'weather': weatherByLocation[loc['id']],
        };
      }).toList();

      otherLocations = otherLocations.map((loc) {
        return {
          ...loc,
          'weather': weatherByLocation[loc['id']],
        };
      }).toList();
    });
  }

  // Fetch weather data from OpenWeatherMap API
  Future<Map<String, dynamic>?> fetchWeather(String cityName) async {
    if (cityName.isEmpty || cityName.trim().isEmpty) {
      print('Error: City name is empty or invalid');
      return null;
    }

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

  List<Map<String, dynamic>> filterLocations(String query) {
    return allLocations.where((location) {
      final name = location['name']?.toString().toLowerCase() ?? '';
      final searchQueryLower = query.toLowerCase();
      return name.contains(searchQueryLower);
    }).toList();
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
            'Manage locations',
            style: TextStyle(color: Colors.black),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: Colors.black),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AddLocationScreen()),
              );
              if (result == true) {
                await loadLocations();
              }
            },
          ),
          IconButton(
            icon: Icon(Icons.more_vert, color: Colors.black),
            onPressed: () {
              showCustomModal(context);
            },
          ),
          IconButton(
            icon: Icon(Icons.search, color: Colors.black),
            onPressed: () {
              showSearch(
                context: context,
                delegate: LocationSearchDelegate(
                  locations: allLocations,
                  onSearch: (query) {
                    setState(() {
                      searchQuery = query;
                      favouriteLocations =
                          filterLocations(query).take(1).toList();
                      otherLocations = filterLocations(query).skip(1).toList();
                    });
                  },
                ),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Favourite location',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            ...favouriteLocations.map(buildLocationCard),
            SizedBox(height: 16),
            Text(
              'Other locations',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            ...otherLocations.map(buildLocationCard),
          ],
        ),
      ),
    );
  }

  Widget buildLocationCard(Map<String, dynamic> location) {
    final weather = location['weather'] ?? {};
    final temp = weather['temperature']?.round() ?? '--';
    final tempHigh =
        weather['maxTemp']?.round() ?? '--'; // Sửa temp_high thành maxTemp
    final tempLow =
        weather['minTemp']?.round() ?? '--'; // Sửa temp_low thành minTemp
    final humidity = weather['humidity'] ?? '--';
    final icon = weather['icon'] ?? '01d';

    String formattedDate = 'Unknown';
    if (weather['updatedAt'] != null) {
      // Sửa date thành updatedAt
      try {
        final dateTime = DateTime.parse(weather['updatedAt']);
        formattedDate = DateFormat('HH:mm EEEE, d MMMM', 'vi').format(dateTime);
        formattedDate = 'lúc $formattedDate';
      } catch (e) {
        formattedDate = 'Unknown';
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.grey.shade200,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 16, color: Colors.grey),
                      SizedBox(width: 4),
                      Text(
                        location['name']?.toString() ?? 'Unknown',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Text(
                    '${location['name']?.toString() ?? 'Unknown'}, Vietnam',
                    style: TextStyle(color: Colors.grey[700], fontSize: 12),
                  ),
                  SizedBox(height: 4),
                  Text(
                    formattedDate,
                    style: TextStyle(color: Colors.grey[700], fontSize: 12),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                Image.network(
                  'https://openweathermap.org/img/wn/$icon@2x.png',
                  width: 40,
                  height: 40,
                  errorBuilder: (_, __, ___) => Icon(Icons.cloud),
                ),
                SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$temp°',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '$tempHigh°/$tempLow°',
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                    Text(
                      'Độ ẩm: $humidity%',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class LocationSearchDelegate extends SearchDelegate {
  final List<Map<String, dynamic>> locations;
  final Function(String) onSearch;

  LocationSearchDelegate({
    required this.locations,
    required this.onSearch,
  });

  @override
  String? get searchFieldLabel => 'Search location';

  @override
  TextInputAction get textInputAction => TextInputAction.search;

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final queryResults = locations.where((location) {
      final name = location['name']?.toString().toLowerCase() ?? '';
      return name.contains(query.toLowerCase());
    }).toList();

    return ListView.builder(
      itemCount: queryResults.length,
      itemBuilder: (context, index) {
        final location = queryResults[index];
        return ListTile(
          title: Text(location['name']?.toString() ?? 'Unknown'),
          subtitle:
              Text('${location['name']?.toString() ?? 'Unknown'}, Vietnam'),
          onTap: () {
            onSearch(query);
            close(context, null);
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final queryResults = locations.where((location) {
      final name = location['name']?.toString().toLowerCase() ?? '';
      return name.contains(query.toLowerCase());
    }).toList();

    return ListView.builder(
      itemCount: queryResults.length,
      itemBuilder: (context, index) {
        final location = queryResults[index];
        return ListTile(
          title: Text(location['name']?.toString() ?? 'Unknown'),
          subtitle:
              Text('${location['name']?.toString() ?? 'Unknown'}, Vietnam'),
          onTap: () {
            onSearch(query);
            close(context, null);
          },
        );
      },
    );
  }
}
