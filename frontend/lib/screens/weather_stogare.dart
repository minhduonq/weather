import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:frontend/screens/add_location_screen.dart';
import 'package:frontend/services/database.dart';
import 'package:frontend/widgets/modals/show_custom.dart';
import 'package:http/http.dart' as http; // For making API calls
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

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('vi', null).then((_) async {
      // Tìm vị trí hiện tại trước khi tải các vị trí đã lưu
      await getCurrentLocation();
      await loadLocations();
    });
  }

  // Hàm lấy vị trí hiện tại
  Future<void> getCurrentLocation() async {
    try {
      // Kiểm tra quyền truy cập vị trí
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('Location permissions are denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('Location permissions are permanently denied');
        return;
      }

      // Lấy vị trí hiện tại
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      setState(() {
        currentPosition = position;
      });

      // Lấy tên thành phố từ tọa độ vị trí
      final cityName = await getCityNameFromCoordinates(
          position.latitude, position.longitude);
      if (cityName != null && cityName.isNotEmpty) {
        setState(() {
          currentLocationName = cityName;
        });

        // Lưu vị trí hiện tại vào database
        final db = DatabaseHelper();
        final currentLocations = await db.getLocationByName(cityName);
        if (currentLocations.isEmpty) {
          final locationId = await db.insertLocation({
            'name': cityName,
            'latitude': position.latitude,
            'longitude': position.longitude,
            'is_current': 1,
          });
          print('Đã lưu vị trí hiện tại: $cityName với ID: $locationId');
        } else {
          // Nếu vị trí đã tồn tại, cập nhật thành vị trí hiện tại
          final locationId = currentLocations.first['id'];
          await db.setCurrentLocation(locationId);
          print('Cập nhật vị trí hiện tại: $cityName với ID: $locationId');
        }
      }
    } catch (e) {
      print('Error getting current location: $e');
    }
  }

  // Hàm lấy tên thành phố từ tọa độ
  Future<String?> getCityNameFromCoordinates(double lat, double lon) async {
    try {
      final url =
          'https://api.openweathermap.org/geo/1.0/reverse?lat=$lat&lon=$lon&limit=1&appid=$apiKey';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          // Ưu tiên lấy tên quận/huyện (district)
          String? cityName = data[0]['name'];
          return cityName;
        }
      } else {
        print('Failed to get city name: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting city name: $e');
    }
    return null;
  }

  Future<void> loadLocations() async {
    setState(() {
      isLoading = true;
    });

    final db = DatabaseHelper();
    final dbLocations = await db.getAllLocations();

    // Tạo bản sao của danh sách để có thể sắp xếp
    List<Map<String, dynamic>> locations =
        List<Map<String, dynamic>>.from(dbLocations);

    // Đảm bảo vị trí hiện tại được đưa lên đầu danh sách
    locations.sort((a, b) {
      if (a['is_current'] == 1) return -1;
      if (b['is_current'] == 1) return 1;
      return 0;
    });

    // Fetch weather data for each location
    List<Map<String, dynamic>> weatherDataList = [];
    for (var location in locations) {
      Map<String, dynamic>? weather;

      // Nếu là vị trí hiện tại và có tọa độ, sử dụng tọa độ để lấy thời tiết
      if (location['is_current'] == 1 && currentPosition != null) {
        weather = await fetchWeatherByCoordinates(
            currentPosition!.latitude, currentPosition!.longitude);
      } else {
        // Ngược lại sử dụng tên thành phố
        weather = await fetchWeather(location['name']);
      }

      if (weather != null) {
        try {
          weatherDataList.add({
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
            'updatedAt':
                DateTime.fromMillisecondsSinceEpoch(weather['dt'] * 1000)
                    .toIso8601String(),
          });
        } catch (e) {
          print('Error processing weather data for ${location['name']}: $e');
        }
      } else {
        print('Could not fetch weather for ${location['name']}');
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
      isLoading = false;
      allLocations = locations;
      if (locations.isNotEmpty) {
        // Địa điểm ưa thích là vị trí hiện tại (đầu tiên sau khi sắp xếp)
        favouriteLocations = [locations.first];
        // Các địa điểm khác là tất cả vị trí còn lại
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

  // Fetch weather data using coordinates
  Future<Map<String, dynamic>?> fetchWeatherByCoordinates(
      double lat, double lon) async {
    final url =
        'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$apiKey&units=metric&lang=vi';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('Failed to fetch weather by coordinates: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error fetching weather by coordinates: $e');
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
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadLocations,
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
                        ...favouriteLocations.map(buildLocationCard),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Làm mới dữ liệu thời tiết
          loadLocations();
        },
        child: Icon(Icons.refresh),
        tooltip: 'Làm mới dữ liệu thời tiết',
      ),
    );
  }

  // Widget này dùng cho các vị trí "khác" - có thể vuốt để xóa
  Widget buildDismissibleLocationCard(Map<String, dynamic> location) {
    return Dismissible(
      key: Key('location-${location['id']}'),
      direction:
          DismissDirection.endToStart, // Chỉ cho phép vuốt từ phải sang trái
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
        // Hiển thị hộp thoại xác nhận xóa
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
        // Xóa vị trí khi người dùng đã xác nhận
        try {
          final db = DatabaseHelper();
          await db.deleteLocation(location['id']);

          // Xóa khỏi danh sách UI
          setState(() {
            otherLocations.removeWhere((item) => item['id'] == location['id']);
            allLocations.removeWhere((item) => item['id'] == location['id']);
          });

          // Hiển thị thông báo
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã xóa vị trí ${location['name']}'),
              action: SnackBarAction(
                label: 'Hoàn tác',
                onPressed: () async {
                  // Hoàn tác xóa vị trí
                  await db.insertLocation({
                    'id': location['id'],
                    'name': location['name'],
                    'latitude': location['latitude'],
                    'longitude': location['longitude'],
                    'is_current': 0,
                  });
                  // Tải lại danh sách
                  await loadLocations();
                },
              ),
            ),
          );
        } catch (e) {
          print('Lỗi khi xóa vị trí: $e');
          // Hiển thị thông báo lỗi
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
