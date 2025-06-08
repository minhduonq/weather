import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:frontend/provider/location_notifier.dart';
import 'package:frontend/screens/HomePage.dart';
import 'package:frontend/screens/SearchPlace.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../services/database.dart';
import '../widgets/modals/show_custom.dart';
//import 'add_location_screen.dart';

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
                  'Ho Chi Minh City');
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
          // Thêm backgroundColor vào Scaffold để đảm bảo màu nền đồng nhất
          backgroundColor: Colors.grey.shade100,
          appBar: AppBar(
            backgroundColor: Colors.grey.shade100,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back,
                  color: Colors
                      .black), // Đổi màu icon thành trắng để phù hợp với nền xanh
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            title: Text(
              'Manage locations',
              style: TextStyle(
                  color: Colors
                      .black), // Đổi màu text thành trắng để phù hợp với nền xanh
              textAlign: TextAlign.center,
            ),
            centerTitle: true, // Căn giữa tiêu đề
            actions: [
              IconButton(
                icon: Icon(Icons.add,
                    color: Colors.black), // Đổi màu icon thành trắng
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => SearchPlace()),
                  );
                  if (result == true) {
                    await locationNotifier.refreshLocations();
                  }
                },
              ),
              IconButton(
                icon: Icon(Icons.more_vert,
                    color: Colors.black), // Đổi màu icon thành trắng
                onPressed: () {
                  showCustomModal(context);
                },
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () => locationNotifier.refreshLocations(),
            child: Container(
              // Đặt height thành double.infinity để mở rộng container xuống toàn bộ màn hình
              height: double.infinity,
              color: Colors.grey.shade100,
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
                          color: Colors.white,
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
                          color: Colors.white,
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
                      // Thêm container trống ở cuối để đảm bảo khoảng trống phía dưới cùng
                      SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
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
      return buildLocationCard(location); // Ngăn xóa vị trí hiện tại
    }

    return Dismissible(
      key: Key('location-${location['id']}'),
      direction: DismissDirection.endToStart,
      // Bỏ dismissThresholds để sử dụng ngưỡng mặc định (0.4)

      // Thay đổi confirmDismiss để tự động xóa sau khi kéo đủ xa
      confirmDismiss: (direction) async {
        try {
          final locationNotifier =
              Provider.of<LocationNotifier>(context, listen: false);

          // Lưu thông tin vị trí để có thể khôi phục nếu cần
          final locationBackup = {
            'name': location['name'],
            'latitude': location['latitude'],
            'longitude': location['longitude'],
            'is_current': 0,
          };

          await locationNotifier.deleteLocation(location['id']);

          // Hiển thị thông báo với tùy chọn hoàn tác
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã xóa vị trí ${location['name']}'),
              action: SnackBarAction(
                label: 'Hoàn tác',
                onPressed: () async {
                  await locationNotifier.addLocation(locationBackup);
                },
              ),
              duration: Duration(seconds: 3), // Thời gian hiển thị thông báo
            ),
          );

          // Trả về true để xác nhận việc xóa và card biến mất
          return true;
        } catch (e) {
          print('Lỗi khi xóa vị trí: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Không thể xóa vị trí. Vui lòng thử lại.'),
            ),
          );
          // Trả về false để card không biến mất khi có lỗi
          return false;
        }
      },

      // Background hiển thị khi kéo sang trái
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 20),
          child: Icon(
            Icons.delete,
            color: Colors.white,
            size: 30,
          ),
        ),
      ),

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
            // Thay đổi màu card thành trắng
            color: Colors.white,
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
            // Thay đổi màu card thành trắng
            color: Colors.white,
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
                  // Thay đổi màu card thành trắng
                  color: Colors.white,
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
                  // Thay đổi màu card thành trắng
                  color: Colors.white,
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

    // Thay đổi màu card thành trắng cho tất cả các card
    final cardColor = Colors.white;
    // Vẫn giữ độ nâng cao hơn cho vị trí hiện tại
    final cardElevation = 0.0;

    return GestureDetector(
      onTap: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomePage(
              highlightLocationName: location['name'],
            ),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: cardColor,
        elevation: cardElevation,
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
                          // Sử dụng màu vàng cho biểu tượng vị trí hiện tại và màu vàng đậm hơn cho vị trí khác
                          color: isCurrentLocation
                              ? Colors.amber.shade600
                              : Colors.amber,
                        ),
                        SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            location['name'].toString(),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              // Màu chữ đồng nhất cho tất cả card
                              color: Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      location['name'].toString(),
                      style: TextStyle(
                        // Màu chữ đồng nhất cho tất cả card
                        color: Colors.grey.shade700,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Text(
                      formattedDate,
                      style: TextStyle(
                        // Màu chữ đồng nhất cho tất cả card
                        color: Colors.grey.shade700,
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
                      color: Colors.grey.shade700,
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
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        '$tempHigh°/$tempLow°',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      Text(
                        'Độ ẩm: $humidity%',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
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
          title: Text(location['name'].toString()),
          onTap: () {
            onSearch(query);
            close(context, location);
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
          title: Text(location['name'].toString()),
          onTap: () {
            onSearch(query);
            close(context, location);
          },
        );
      },
    );
  }
}
