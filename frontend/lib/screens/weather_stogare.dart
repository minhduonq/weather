import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:frontend/provider/location_notifier.dart';
import 'package:frontend/screens/HomePage.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../services/database.dart';
import '../widgets/modals/show_custom.dart';
import 'add_location_screen.dart';

class WeatherStorageScreen extends StatefulWidget {
  @override
  _WeatherStorageScreenState createState() => _WeatherStorageScreenState();
}

class _WeatherStorageScreenState extends State<WeatherStorageScreen> {
  final String apiKey = '2b5630205440fa5d9747bc910681e783';
  final Duration maxCacheAge = Duration(minutes: 30);

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('vi', null).then((_) {
      _checkAndSetEmulatorLocation();
      _loadCachedDataAndRefresh();
    });
  }

  Future<void> _checkAndSetEmulatorLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(Duration(seconds: 3), onTimeout: () {
        throw Exception('Likely running on emulator');
      });
      print('Running on physical device with position: $position');
      await Provider.of<LocationNotifier>(context, listen: false)
          .setCurrentPosition(
              position,
              await getCityNameFromCoordinates(
                      position.latitude, position.longitude) ??
                  'Unknown');
    } catch (e) {
      print('Likely running on emulator or location not available: $e');
      await _setupDefaultEmulatorLocation();
    }
  }

  Future<void> _setupDefaultEmulatorLocation() async {
    try {
      final db = Provider.of<DatabaseHelper>(context, listen: false);
      await db.resetCurrentLocation();
      const String defaultCity = 'Ho Chi Minh City';
      const double defaultLat = 10.8231;
      const double defaultLon = 106.6297;

      final existingLocations = await db.getLocationByName(defaultCity);
      int locationId;
      if (existingLocations.isEmpty) {
        locationId = await db.insertLocation({
          'name': defaultCity,
          'latitude': defaultLat,
          'longitude': defaultLon,
          'is_current': 1,
        });
      } else {
        locationId = existingLocations.first['id'];
        await db.setCurrentLocation(locationId);
      }

      final existingWeather = await db.getWeatherDataByLocationId(locationId);
      if (existingWeather.isEmpty) {
        await _fetchWeatherForEmulator(
            locationId, defaultLat, defaultLon, defaultCity);
      }

      final position = Position(
        latitude: defaultLat,
        longitude: defaultLon,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      );

      await Provider.of<LocationNotifier>(context, listen: false)
          .setCurrentPosition(position, defaultCity);
      print('Default emulator location set to: $defaultCity');
    } catch (e) {
      print('Error setting up default emulator location: $e');
    }
  }

  Future<void> _fetchWeatherForEmulator(
      int locationId, double lat, double lon, String cityName) async {
    try {
      final weatherData = await fetchWeatherByCoordinates(lat, lon);
      if (weatherData != null) {
        final db = Provider.of<DatabaseHelper>(context, listen: false);
        await db.insertWeatherData({
          'location_id': locationId,
          'temperature': weatherData['main']['temp'],
          'feelsLike': weatherData['main']['feels_like'],
          'maxTemp': weatherData['main']['temp_max'],
          'minTemp': weatherData['main']['temp_min'],
          'pressure': weatherData['main']['pressure'],
          'humidity': weatherData['main']['humidity'],
          'windSpeed': weatherData['wind']['speed'],
          'windDeg': weatherData['wind']['deg'],
          'windGust': weatherData['wind']['gust'] ?? 0.0,
          'icon': weatherData['weather'][0]['icon'],
          'timeZone': weatherData['timezone'],
          'cloud': weatherData['clouds']['all'],
          'visibility': weatherData['visibility'],
          'sunrise': weatherData['sys']['sunrise'],
          'sunset': weatherData['sys']['sunset'],
          'description': weatherData['weather'][0]['description'],
          'main': weatherData['weather'][0]['main'],
          'updatedAt': DateTime.now().toIso8601String(),
        });
        print('Weather data fetched for emulator location: $cityName');
      }
    } catch (e) {
      print('Error fetching weather for emulator: $e');
    }
  }

  Future<void> _loadCachedDataAndRefresh() async {
    await Provider.of<LocationNotifier>(context, listen: false)
        .refreshLocations();
    _refreshDataInBackground();
  }

  Future<void> _refreshDataInBackground() async {
    try {
      final db = Provider.of<DatabaseHelper>(context, listen: false);
      final locations = await db.getAllLocations();
      final storedWeatherData = await db.getAllWeatherData();
      final weatherByLocation = {
        for (var w in storedWeatherData) w['location_id']: w,
      };

      List<Future<void>> updateFutures = [];
      final now = DateTime.now();
      for (var location in locations) {
        final weatherData = weatherByLocation[location['id']];
        bool needsUpdate = true;
        if (weatherData != null && weatherData['updatedAt'] != null) {
          try {
            final lastUpdated = DateTime.parse(weatherData['updatedAt']);
            needsUpdate = now.difference(lastUpdated) > maxCacheAge;
          } catch (e) {
            needsUpdate = true;
          }
        }
        if (needsUpdate) {
          updateFutures.add(_updateWeatherForLocation(db, location));
        }
      }
      if (updateFutures.isNotEmpty) {
        await Future.wait(updateFutures);
        await Provider.of<LocationNotifier>(context, listen: false)
            .refreshLocations();
      }
    } catch (e) {
      print('Error refreshing data: $e');
    }
  }

  Future<void> _updateWeatherForLocation(
      DatabaseHelper db, Map<String, dynamic> location) async {
    try {
      Map<String, dynamic>? weather;
      final locationNotifier =
          Provider.of<LocationNotifier>(context, listen: false);
      if (location['is_current'] == 1 &&
          locationNotifier.currentPosition != null) {
        weather = await fetchWeatherByCoordinates(
            locationNotifier.currentPosition!.latitude,
            locationNotifier.currentPosition!.longitude);
      } else {
        weather = await fetchWeather(location['name']);
      }

      if (weather != null) {
        final weatherData = {
          'location_id': location['id'],
          'temperature': weather['main']['temp'],
          'feelsLike': weather['main']['feels_like'],
          'maxTemp': weather['main']['temp_max'],
          'minTemp': weather['main']['temp_min'],
          'pressure': weather['main']['pressure'],
          'humidity': weather['main']['humidity'],
          'windSpeed': weather['wind']['speed'],
          'windDeg': weather['wind']['deg'],
          'windGust': weather['wind']['gust'] ?? 0.0,
          'icon': weather['weather'][0]['icon'],
          'timeZone': weather['timezone'],
          'cloud': weather['clouds']['all'],
          'visibility': weather['visibility'],
          'sunrise': weather['sys']['sunrise'],
          'sunset': weather['sys']['sunset'],
          'description': weather['weather'][0]['description'],
          'main': weather['weather'][0]['main'],
          'updatedAt': DateTime.fromMillisecondsSinceEpoch(weather['dt'] * 1000)
              .toIso8601String(),
        };
        await db.insertWeatherData(weatherData);
      }
    } catch (e) {
      print('Error updating weather for ${location['name']}: $e');
    }
  }

  Future<Map<String, dynamic>?> fetchWeather(String cityName) async {
    if (cityName.isEmpty || cityName.trim().isEmpty) {
      return null;
    }
    final url =
        'https://api.openweathermap.org/data/2.5/weather?q=${Uri.encodeComponent(cityName)}&appid=$apiKey&units=metric&lang=vi';
    try {
      final response =
          await http.get(Uri.parse(url)).timeout(Duration(seconds: 5));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Error fetching weather for $cityName: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> fetchWeatherByCoordinates(
      double lat, double lon) async {
    final url =
        'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$apiKey&units=metric&lang=vi';
    try {
      final response =
          await http.get(Uri.parse(url)).timeout(Duration(seconds: 5));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Error fetching weather by coordinates: $e');
    }
    return null;
  }

  Future<String?> getCityNameFromCoordinates(double lat, double lon) async {
    try {
      final url =
          'https://api.openweathermap.org/geo/1.0/reverse?lat=$lat&lon=$lon&limit=1&appid=$apiKey';
      final response =
          await http.get(Uri.parse(url)).timeout(Duration(seconds: 5));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          return data[0]['name'];
        }
      }
    } catch (e) {
      print('Error getting city name: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LocationNotifier>(
      builder: (context, locationNotifier, child) {
        // Filter locations to exclude those with invalid names
        final locations = locationNotifier.locations.where((location) {
          final name = location['name']?.toString();
          return name != null && name.isNotEmpty && name != 'Unknown';
        }).toList();

        // Separate favourite (current) and other locations
        final favouriteLocations =
            locations.isNotEmpty ? [locations.first] : [];
        final otherLocations = locations.length > 1 ? locations.sublist(1) : [];

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.blue,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            title: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Manage locations',
                  style: TextStyle(color: Colors.black),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.add, color: Colors.black),
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => AddLocationScreen()),
                  );
                  if (result == true) {
                    await locationNotifier.refreshLocations();
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
                onPressed: () async {
                  final selectedLocation =
                      await showSearch<Map<String, dynamic>>(
                    context: context,
                    delegate: LocationSearchDelegate(
                      locations: locations, // Use filtered locations
                      onSearch: (query) {
                        // No need for setState as Consumer will rebuild
                      },
                    ),
                  );
                  if (selectedLocation != null) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => HomePage(
                          highlightLocationName: selectedLocation['name'],
                        ),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
          body: Container(
            color: Colors.white,
            child: Stack(
              children: [
                RefreshIndicator(
                  onRefresh: () => locationNotifier.refreshLocations(),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SingleChildScrollView(
                      physics: AlwaysScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Vị trí hiện tại',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 8),
                          if (favouriteLocations.isEmpty)
                            Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              color: Colors.grey.shade200,
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Center(
                                  child: Text(
                                    'Chưa có vị trí nào được thêm. Nhấn nút + để thêm vị trí.',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            )
                          else
                            ...favouriteLocations
                                .map((location) => buildLocationCard(location)),
                          SizedBox(height: 16),
                          Text(
                            'Vị trí khác',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 8),
                          if (otherLocations.isEmpty)
                            Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              color: Colors.grey.shade200,
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Center(
                                  child: Text(
                                    'Không có vị trí khác.',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            )
                          else
                            ...otherLocations.map((location) =>
                                buildDismissibleLocationCard(location)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => locationNotifier.refreshLocations(),
            child: Icon(Icons.refresh),
            tooltip: 'Làm mới dữ liệu thời tiết',
          ),
        );
      },
    );
  }

  Widget buildDismissibleLocationCard(Map<String, dynamic> location) {
    if (location['is_current'] == 1) {
      return buildLocationCard(location); // Prevent dismissing current location
    }
    return Dismissible(
      key: Key('location-${location['id']}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        child: Icon(
          Icons.delete,
          color: Colors.white,
          size: 30,
        ),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Xác nhận xóa'),
              content: Text(
                  'Bạn có chắc chắn muốn xóa vị trí "${location['name']}" không?'),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('Hủy'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text('Xóa'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
              ],
            );
          },
        );
      },
      onDismissed: (direction) async {
        try {
          final locationNotifier =
              Provider.of<LocationNotifier>(context, listen: false);
          await locationNotifier.deleteLocation(location['id']);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã xóa vị trí ${location['name']}'),
              action: SnackBarAction(
                label: 'Hoàn tác',
                onPressed: () async {
                  await locationNotifier.addLocation({
                    'name': location['name'],
                    'latitude': location['latitude'],
                    'longitude': location['longitude'],
                    'is_current': 0,
                  });
                },
              ),
            ),
          );
        } catch (e) {
          print('Lỗi khi xóa vị trí: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Không thể xóa vị trí. Vui lòng thử lại.')),
          );
        }
      },
      child: buildLocationCard(location),
    );
  }

  Widget buildLocationCard(Map<String, dynamic> location) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: Provider.of<DatabaseHelper>(context, listen: false)
          .getWeatherDataByLocationId(location['id']),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.hasError) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: Colors.grey.shade200,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Text(
                  'Lỗi khi tải dữ liệu thời tiết: ${snapshot.error}',
                  style: TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        Map<String, dynamic> weather = {};
        if (snapshot.data?.isEmpty ?? true) {
          return FutureBuilder<Map<String, dynamic>?>(
            future: fetchWeatherByCoordinates(
                location['latitude'], location['longitude']),
            builder: (context, weatherSnapshot) {
              if (weatherSnapshot.connectionState == ConnectionState.waiting) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }

              if (weatherSnapshot.hasError || weatherSnapshot.data == null) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  color: Colors.grey.shade200,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Center(
                      child: Text(
                        'Không thể tải dữ liệu thời tiết. Vui lòng thử lại.',
                        style: TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                );
              }

              weather = weatherSnapshot.data!;
              Provider.of<DatabaseHelper>(context, listen: false)
                  .insertWeatherData({
                'location_id': location['id'],
                'temperature': weather['main']['temp'],
                'feelsLike': weather['main']['feels_like'],
                'maxTemp': weather['main']['temp_max'],
                'minTemp': weather['main']['temp_min'],
                'pressure': weather['main']['pressure'],
                'humidity': weather['main']['humidity'],
                'windSpeed': weather['wind']['speed'],
                'windDeg': weather['wind']['deg'],
                'windGust': weather['wind']['gust'] ?? 0.0,
                'icon': weather['weather'][0]['icon'],
                'timeZone': weather['timezone'],
                'cloud': weather['clouds']['all'],
                'visibility': weather['visibility'],
                'sunrise': weather['sys']['sunrise'],
                'sunset': weather['sys']['sunset'],
                'description': weather['weather'][0]['description'],
                'main': weather['weather'][0]['main'],
                'updatedAt': DateTime.now().toIso8601String(),
              });

              return _buildWeatherCard(location, weather);
            },
          );
        }

        weather = snapshot.data!.first;
        return _buildWeatherCard(location, weather);
      },
    );
  }

  Widget _buildWeatherCard(
      Map<String, dynamic> location, Map<String, dynamic> weather) {
    final temp =
        weather['temperature'] != null ? weather['temperature'].round() : '--';
    final tempHigh =
        weather['maxTemp'] != null ? weather['maxTemp'].round() : '--';
    final tempLow =
        weather['minTemp'] != null ? weather['minTemp'].round() : '--';
    final humidity = weather['humidity'] ?? '--';
    final icon = weather['icon'] ?? '01d';

    String formattedDate = 'Chưa cập nhật';
    if (weather['updatedAt'] != null) {
      try {
        final dateTime = DateTime.parse(weather['updatedAt']);
        formattedDate = DateFormat('HH:mm EEEE, d MMMM', 'vi').format(dateTime);
        formattedDate = 'lúc $formattedDate';
      } catch (e) {
        print('Lỗi định dạng updatedAt: $e');
      }
    }

    bool isCurrentLocation = location['is_current'] == 1;

    // Define distinct background colors
    final cardColor =
        isCurrentLocation ? Colors.blue.shade400 : Colors.grey.shade300;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: cardColor, // Apply the distinct background color
      elevation: isCurrentLocation
          ? 6
          : 3, // Slightly higher elevation for current location
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
                      Icon(
                        isCurrentLocation
                            ? Icons.my_location
                            : Icons.location_on,
                        size: 16,
                        color: isCurrentLocation ? Colors.white : Colors.amber,
                      ),
                      SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          location['name']?.toString() ?? 'Unknown',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isCurrentLocation
                                ? Colors.white
                                : Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    location['name']?.toString() ??
                        'Unknown', // Removed ", Vietnam"
                    style: TextStyle(
                      color: isCurrentLocation
                          ? Colors.white70
                          : Colors.grey.shade700,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Text(
                    formattedDate,
                    style: TextStyle(
                      color: isCurrentLocation
                          ? Colors.white70
                          : Colors.grey.shade700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.network(
                  'https://openweathermap.org/img/wn/$icon@2x.png',
                  width: 40,
                  height: 40,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.cloud,
                    color:
                        isCurrentLocation ? Colors.white : Colors.grey.shade700,
                  ),
                ),
                SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$temp°',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color:
                            isCurrentLocation ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      '$tempHigh°/$tempLow°',
                      style: TextStyle(
                        fontSize: 14,
                        color: isCurrentLocation
                            ? Colors.white70
                            : Colors.grey.shade700,
                      ),
                    ),
                    Text(
                      'Độ ẩm: $humidity%',
                      style: TextStyle(
                        fontSize: 12,
                        color: isCurrentLocation
                            ? Colors.white70
                            : Colors.grey.shade700,
                      ),
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

class LocationSearchDelegate extends SearchDelegate<Map<String, dynamic>> {
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
        close(context, {});
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
            close(context, location); // Trả về địa điểm được chọn
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
            close(context, location); // Trả về địa điểm được chọn
          },
        );
      },
    );
  }
}
