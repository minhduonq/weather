import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:frontend/screens/add_location_screen.dart';
import 'package:frontend/services/database.dart';
import 'package:frontend/widgets/modals/show_custom.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:geolocator/geolocator.dart';

class WeatherStorageScreen extends StatefulWidget {
  @override
  _WeatherStorageScreenState createState() => _WeatherStorageScreenState();
}

class _WeatherStorageScreenState extends State<WeatherStorageScreen> {
  List<Map<String, dynamic>> favouriteLocations = [];
  List<Map<String, dynamic>> otherLocations = [];
  List<Map<String, dynamic>> allLocations = [];
  String searchQuery = "";
  bool isLoading = true;
  String? currentLocationName;
  Position? currentPosition;

  // Replace with your OpenWeatherMap API key
  final String apiKey = '2b5630205440fa5d9747bc910681e783';

  // Cache control
  final Duration maxCacheAge = Duration(minutes: 30);

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('vi', null).then((_) {
      // Show cached data immediately, then refresh
      _loadCachedDataAndRefresh();
    });
  }

  // Load cached data first, then refresh in background
  Future<void> _loadCachedDataAndRefresh() async {
    // 1. First load cached weather data to display immediately
    await _loadCachedData();

    // 2. Then update current location and refresh data in background
    if (mounted) {
      _refreshDataInBackground();
    }
  }

  // Load cached data from database
  Future<void> _loadCachedData() async {
    try {
      final db = DatabaseHelper();
      final dbLocations = await db.getAllLocations();
      final storedWeatherData = await db.getAllWeatherData();

      // Create a map of weather data by location ID for quick lookup
      final weatherByLocation = {
        for (var w in storedWeatherData) w['location_id']: w,
      };

      // Process locations
      _processLocations(dbLocations, weatherByLocation);

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print('Error loading cached data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  // Refresh data in background
  Future<void> _refreshDataInBackground() async {
    try {
      // Get current location in background
      await getCurrentLocation();

      // Load fresh data from API
      await loadLocations(showLoadingIndicator: false);
    } catch (e) {
      print('Error refreshing data: $e');
    }
  }

  // Process locations and sort them
  void _processLocations(List<Map<String, dynamic>> locations,
      Map<dynamic, dynamic> weatherByLocation) {
    // Sort locations (current location first)
    locations.sort((a, b) {
      if (a['is_current'] == 1) return -1;
      if (b['is_current'] == 1) return 1;
      return 0;
    });

    // Add weather data to locations
    final locationsWithWeather = locations.map((loc) {
      return {
        ...loc,
        'weather': weatherByLocation[loc['id']],
      };
    }).toList();

    // Update state with processed locations
    setState(() {
      allLocations = locationsWithWeather;
      if (locationsWithWeather.isNotEmpty) {
        favouriteLocations = [locationsWithWeather.first];
        otherLocations = locationsWithWeather.skip(1).toList();
      }
    });
  }

  // Get current location with timeout
  Future<void> getCurrentLocation() async {
    try {
      // Check location permission with timeout
      LocationPermission permission = await Geolocator.checkPermission()
          .timeout(Duration(seconds: 3),
              onTimeout: () => LocationPermission.denied);

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission().timeout(
            Duration(seconds: 5),
            onTimeout: () => LocationPermission.denied);

        if (permission == LocationPermission.denied) {
          print('Location permissions are denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('Location permissions are permanently denied');
        return;
      }

      // Get current position with timeout
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(Duration(seconds: 5), onTimeout: () {
        throw Exception('Location timeout');
      });

      currentPosition = position;

      // Get city name from coordinates
      final cityName = await getCityNameFromCoordinates(
          position.latitude, position.longitude);

      if (cityName != null && cityName.isNotEmpty) {
        currentLocationName = cityName;

        // Update location in database
        final db = DatabaseHelper();
        // final currentLocations = await db.getLocationByName(cityName);

        // if (currentLocations.isEmpty) {
        //   await db.insertLocation({
        //     'name': cityName,
        //     'latitude': position.latitude,
        //     'longitude': position.longitude,
        //     'is_current': 1,
        //   });
        // } else {
        //   // await db.setCurrentLocation(currentLocations.first['id']);
        // }
      }
    } catch (e) {
      print('Error getting current location: $e');
    }
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

  Future<void> loadLocations({bool showLoadingIndicator = true}) async {
    if (showLoadingIndicator) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      final db = DatabaseHelper();
      final dbLocations = await db.getAllLocations();

      // Create a copy of the list that we can sort
      List<Map<String, dynamic>> locations =
          List<Map<String, dynamic>>.from(dbLocations);

      // Make sure current location is at the top
      locations.sort((a, b) {
        if (a['is_current'] == 1) return -1;
        if (b['is_current'] == 1) return 1;
        return 0;
      });

      // Get cached weather data first
      final storedWeatherData = await db.getAllWeatherData();
      final weatherByLocation = {
        for (var w in storedWeatherData) w['location_id']: w,
      };

      // Check if we need to refresh any weather data
      List<Future<void>> updateFutures = [];
      final now = DateTime.now();

      for (var location in locations) {
        final weatherData = weatherByLocation[location['id']];
        bool needsUpdate = true;

        // Check if cache is valid
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

      // Update all weather data in parallel
      if (updateFutures.isNotEmpty) {
        await Future.wait(updateFutures);

        // Reload weather data after updates
        final updatedWeatherData = await db.getAllWeatherData();
        final updatedWeatherByLocation = {
          for (var w in updatedWeatherData) w['location_id']: w,
        };

        // Process locations with updated weather data
        _processLocations(locations, updatedWeatherByLocation);
      } else {
        // No updates needed, just process with existing data
        _processLocations(locations, weatherByLocation);
      }
    } catch (e) {
      print('Error loading locations: $e');
    } finally {
      if (showLoadingIndicator && mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // Update weather for a single location
  Future<void> _updateWeatherForLocation(
      DatabaseHelper db, Map<String, dynamic> location) async {
    try {
      Map<String, dynamic>? weather;

      // Use coordinates for current location, city name for others
      if (location['is_current'] == 1 && currentPosition != null) {
        weather = await fetchWeatherByCoordinates(
            currentPosition!.latitude, currentPosition!.longitude);
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

  // Fetch weather with timeout
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

  // Fetch weather by coordinates with timeout
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
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () => loadLocations(showLoadingIndicator: false),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vị trí hiện tại',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                      ...favouriteLocations.map(buildLocationCard),
                    SizedBox(height: 16),
                    Text(
                      'Vị trí khác',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                      ...otherLocations.map(
                          (location) => buildDismissibleLocationCard(location)),
                  ],
                ),
              ),
            ),
          ),
          if (isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => loadLocations(),
        child: Icon(Icons.refresh),
        tooltip: 'Làm mới dữ liệu thời tiết',
      ),
    );
  }

  // Widget for other locations - can be swiped to delete
  Widget buildDismissibleLocationCard(Map<String, dynamic> location) {
    return Dismissible(
      key: Key('location-${location['id']}'),
      direction: DismissDirection.endToStart, // Only allow right to left swipe
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
        // Show delete confirmation dialog
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
          final db = DatabaseHelper();
          await db.deleteLocation(location['id']);

          setState(() {
            otherLocations.removeWhere((item) => item['id'] == location['id']);
            allLocations.removeWhere((item) => item['id'] == location['id']);
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã xóa vị trí ${location['name']}'),
              action: SnackBarAction(
                label: 'Hoàn tác',
                onPressed: () async {
                  await db.insertLocation({
                    'id': location['id'],
                    'name': location['name'],
                    'latitude': location['latitude'],
                    'longitude': location['longitude'],
                    'is_current': 0,
                  });
                  await loadLocations();
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
    final weather = location['weather'] ?? {};
    final temp = weather['temperature']?.round() ?? '--';
    final tempHigh = weather['maxTemp']?.round() ?? '--';
    final tempLow = weather['minTemp']?.round() ?? '--';
    final humidity = weather['humidity'] ?? '--';
    final icon = weather['icon'] ?? '01d';

    String formattedDate = 'Unknown';
    if (weather['updatedAt'] != null) {
      try {
        final dateTime = DateTime.parse(weather['updatedAt']);
        formattedDate = DateFormat('HH:mm EEEE, d MMMM', 'vi').format(dateTime);
        formattedDate = 'lúc $formattedDate';
      } catch (e) {
        formattedDate = 'Unknown';
      }
    }

    bool isCurrentLocation = location['is_current'] == 1;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isCurrentLocation ? Colors.blue.shade100 : Colors.grey.shade200,
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
                          color: isCurrentLocation ? Colors.blue : Colors.grey),
                      SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          location['name']?.toString() ?? 'Unknown',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isCurrentLocation
                                  ? Colors.blue.shade800
                                  : Colors.black),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${location['name']?.toString() ?? 'Unknown'}, Vietnam',
                    style: TextStyle(color: Colors.grey[700], fontSize: 12),
                    overflow: TextOverflow.ellipsis,
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
              mainAxisSize: MainAxisSize.min,
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
