import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:get/get.dart'; // Thêm import này
import 'constants.dart';
import 'database.dart';

class WeatherService {
  // Thay thế các biến thông thường bằng Rx variables
  static final RxMap<String, dynamic> _currentData = RxMap<String, dynamic>({});
  static final RxMap<String, dynamic> _hourlyData = RxMap<String, dynamic>({});
  static final RxMap<String, dynamic> _dailyData = RxMap<String, dynamic>({});
  static final RxMap<String, dynamic> _weatherName = RxMap<String, dynamic>({});

  // Getters cho các biến Rx
  static Map<String, dynamic> get currentData => _currentData;
  static Map<String, dynamic> get hourlyData => _hourlyData;
  static Map<String, dynamic> get dailyData => _dailyData;
  static Map<String, dynamic> get weatherName => _weatherName;

  // Phương thức _processDailyData giữ nguyên
  static Map<String, dynamic> _processDailyData(Map<String, dynamic> rawData) {
    if (rawData.isEmpty || rawData['list'] == null) {
      return rawData;
    }

    // Nhóm dữ liệu theo ngày
    Map<String, dynamic> uniqueDays = {};
    List<dynamic> list = List.from(rawData['list']);

    for (var item in list) {
      // Tạo khóa theo ngày từ timestamp
      final DateTime date =
          DateTime.fromMillisecondsSinceEpoch(item['dt'] * 1000);
      final String dayKey = "${date.year}-${date.month}-${date.day}";

      if (!uniqueDays.containsKey(dayKey)) {
        uniqueDays[dayKey] = item;
      }
    }

    // Tạo lại danh sách đã lọc
    List<dynamic> uniqueList = uniqueDays.values.toList();

    // Cập nhật lại danh sách trong rawData
    Map<String, dynamic> processedData = Map.from(rawData);
    processedData['list'] = uniqueList;

    return processedData;
  }

  static Future<void> fetchWeatherData(double lat, double lon) async {
    final uri =
        'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$API_KEY&units=${type.value}';
    try {
      final response = await http.get(Uri.parse(uri));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        final locationData = {
          'id': data['id'],
          'name': LocationName,
          'latitude': data['coord']['lat'],
          'longitude': data['coord']['lon'],
        };

        // Save to SQLite
        final dbHelper = DatabaseHelper();
        await dbHelper.insertLocation(locationData);

        final weatherData = {
          'location_id': data['id'],
          'temperature': data['main']['temp'],
          'feelsLike': data['main']['feels_like'],
          'maxTemp': data['main']['temp_max'],
          'minTemp': data['main']['temp_min'],
          'pressure': data['main']['pressure'],
          'humidity': data['main']['humidity'],
          'windSpeed': data['wind']['speed'],
          'windDeg': data['wind']['deg'],
          'windGust': data['wind']['gust'],
          'icon': data['weather'][0]['icon'],
          'description': data['weather'][0]['description'],
          'main': data['weather'][0]['main'],
          'sunrise': data['sys']['sunrise'],
          'sunset': data['sys']['sunset'],
          'cloud': data['clouds']['all'],
          'visibility': data['visibility'],
          'timeZone': data['timezone'],
          'updatedAt': DateTime.now().toIso8601String(),
        };

        await dbHelper.insertWeatherData(weatherData);
        // Cập nhật biến Rx thay vì gán trực tiếp
        _currentData.assignAll(data);
      } else {
        print('Failed to load weather data');
      }
    } catch (e) {
      print('Error: $e');
    }

    // Fetch hourly forecast
    await fetchHourlyForecast(lat, lon);

    // Fetch daily forecast
    await fetchDailyForecast(lat, lon);
  }

  static Future<void> fetchHourlyForecast(double lat, double lon) async {
    final hourly =
        'https://pro.openweathermap.org/data/2.5/forecast/hourly?lat=$lat&lon=$lon&appid=$API_KEY&cnt=24&units=${type.value}';
    try {
      final response = await http.get(Uri.parse(hourly));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Get location_id from API
        final locationId = data['city']['id'];

        // Get hourly data list
        final List<dynamic> hourlyList = data['list'];

        // Save each item to hourly_data table
        final dbHelper = DatabaseHelper();
        for (var hourly in hourlyList) {
          final hourlyData = {
            'location_id': locationId,
            'time': hourly['dt'],
            'temperatureMax': hourly['main']['temp_max'],
            'temperatureMin': hourly['main']['temp_min'],
            'humidity': hourly['main']['humidity'],
            'icon': hourly['weather'][0]['icon'],
          };

          await dbHelper.insertHourlyData(hourlyData);
        }

        // Cập nhật biến Rx thay vì gán trực tiếp
        _hourlyData.assignAll(data);
      } else {
        throw Exception('Failed to load weather data hourly');
      }
    } catch (e) {
      print('Error fetching hourly forecast: $e');
    }
  }

  static Future<void> fetchDailyForecast(double lat, double lon) async {
    final daily =
        'http://api.openweathermap.org/data/2.5/forecast/daily?lat=$lat&lon=$lon&cnt=7&appid=$API_KEY&units=${type.value}';
    try {
      final response = await http.get(Uri.parse(daily));
      if (response.statusCode == 200) {
        final rawData = json.decode(response.body);
        final data = _processDailyData(rawData);

        // Get location_id from API
        final locationId = data['city']['id'];

        // Get daily data list
        final List<dynamic> dailyList = data['list'];

        // Save each item to daily_data table
        final dbHelper = DatabaseHelper();
        for (var daily in dailyList) {
          final dailyData = {
            'location_id': locationId,
            'time': daily['dt'],
            'temperatureMax': daily['temp']['max'],
            'temperatureMin': daily['temp']['min'],
            'humidity': daily['humidity'],
            'icon': daily['weather'][0]['icon'],
          };

          await dbHelper.insertDailyData(dailyData);
        }

        // Cập nhật biến Rx thay vì gán trực tiếp
        _dailyData.assignAll(data);
      } else {
        throw Exception('Failed to load weather data daily');
      }
    } catch (e) {
      print('Error fetching daily forecast: $e');
    }
  }

  // Cập nhật load methods
  static Future<void> loadWeatherDataFromDatabase(int locationId) async {
    final dbHelper = DatabaseHelper();

    // Load location data
    final locations = await dbHelper.getLocationById(locationId);
    if (locations.isNotEmpty) {
      final location = locations.first;

      // Load current weather data
      final weatherDataList =
          await dbHelper.getWeatherDataByLocationId(locationId);
      if (weatherDataList.isNotEmpty) {
        final weatherData = weatherDataList.first;
        // Convert database data to format expected by UI
        final currentDataMap = {
          'id': locationId,
          'name': location['name'],
          'coord': {'lat': location['latitude'], 'lon': location['longitude']},
          'main': {
            'temp': weatherData['temperature'],
            'feels_like': weatherData['feelsLike'],
            'temp_max': weatherData['maxTemp'],
            'temp_min': weatherData['minTemp'],
            'pressure': weatherData['pressure'],
            'humidity': weatherData['humidity'],
            'sea_level': weatherData['pressure']
          },
          'wind': {
            'speed': weatherData['windSpeed'],
            'deg': weatherData['windDeg'],
            'gust': weatherData['windGust']
          },
          'clouds': {'all': weatherData['cloud']},
          'sys': {
            'sunrise': weatherData['sunrise'],
            'sunset': weatherData['sunset']
          },
          'weather': [
            {
              'description': weatherData['description'],
              'main': weatherData['main'],
              'icon': weatherData['icon']
            }
          ],
          'visibility': weatherData['visibility'],
          'timezone': weatherData['timeZone'],
          'dt': DateTime.now().millisecondsSinceEpoch ~/ 1000
        };

        // Cập nhật biến Rx
        _currentData.assignAll(currentDataMap);
      }

      // Load hourly data
      await loadHourlyDataFromDatabase(locationId, location);

      // Load daily data
      await loadDailyDataFromDatabase(locationId, location);
    }
  }

  static Future<void> loadHourlyDataFromDatabase(
      int locationId, Map<String, dynamic> location) async {
    final dbHelper = DatabaseHelper();
    final hourlyDataList = await dbHelper.getHourlyDataByLocationId(locationId);

    if (hourlyDataList.isNotEmpty) {
      // Convert database data to format expected by UI
      final hourlyDataMap = {
        'city': {
          'id': locationId,
          'name': location['name'],
          'coord': {'lat': location['latitude'], 'lon': location['longitude']}
        },
        'list': hourlyDataList
            .map((hourly) => {
                  'dt': hourly['time'],
                  'main': {
                    'temp': double.parse(
                        ((hourly['temperatureMax'] + hourly['temperatureMin']) /
                                2)
                            .toStringAsFixed(1)),
                    'temp_max': double.parse(
                        hourly['temperatureMax'].toStringAsFixed(1)),
                    'temp_min': double.parse(
                        hourly['temperatureMin'].toStringAsFixed(1)),
                    'humidity': hourly['humidity']
                  },
                  'weather': [
                    {'icon': hourly['icon']}
                  ],
                  'pop': 0.0 // Default value for precipitation probability
                })
            .toList()
      };

      // Cập nhật biến Rx
      _hourlyData.assignAll(hourlyDataMap);
    }
  }

  static Future<void> loadDailyDataFromDatabase(
      int locationId, Map<String, dynamic> location) async {
    final dbHelper = DatabaseHelper();
    final dailyDataList = await dbHelper.getDailyDataByLocationId(locationId);

    if (dailyDataList.isNotEmpty) {
      // Convert database data to format expected by UI
      final dailyDataMap = {
        'city': {
          'id': locationId,
          'name': location['name'],
          'coord': {'lat': location['latitude'], 'lon': location['longitude']}
        },
        'list': dailyDataList
            .map((daily) => {
                  'dt': daily['time'],
                  'temp': {
                    'max': double.parse(
                        daily['temperatureMax'].toStringAsFixed(1)),
                    'min':
                        double.parse(daily['temperatureMin'].toStringAsFixed(1))
                  },
                  'humidity': daily['humidity'],
                  'weather': [
                    {'icon': daily['icon']}
                  ],
                  'pop': 0.0
                })
            .toList()
      };

      // Cập nhật biến Rx
      _dailyData.assignAll(dailyDataMap);
    }
  }

  // Helper method to try loading from database first, then fetch from API if needed
  static Future<void> loadWeatherData(double lat, double lon) async {
    try {
      // First try to find a nearby location in the database
      final dbHelper = DatabaseHelper();
      final locations = await dbHelper.getAllLocations();

      int? locationId;
      for (var location in locations) {
        double dLat = location['latitude'] - lat;
        double dLon = location['longitude'] - lon;
        // If location is very close (within ~1km), use it
        if (dLat * dLat + dLon * dLon < 0.0001) {
          locationId = location['id'];
          break;
        }
      }

      if (locationId != null) {
        // Load from database
        await loadWeatherDataFromDatabase(locationId);

        // Check if data is recent (less than 1 hour old)
        final weatherDataList =
            await dbHelper.getWeatherDataByLocationId(locationId);
        if (weatherDataList.isNotEmpty) {
          final updatedAt = DateTime.parse(weatherDataList.first['updatedAt']);
          final now = DateTime.now();
          final difference = now.difference(updatedAt);

          // If data is recent, return without fetching from API
          if (difference.inHours < 1) {
            return;
          }
        }
      }

      // If no recent data found in database, fetch from API
      await fetchWeatherData(lat, lon);
    } catch (e) {
      print('Error loading weather data: $e');
      // If all else fails, fetch from API
      await fetchWeatherData(lat, lon);
    }
  }

  // Get location name from coordinates
  static Future<void> getLocationName(double lat, double lon) async {
    final key = HereAPI;
    final url =
        'https://revgeocode.search.hereapi.com/v1/revgeocode?at=$lat,$lon&apiKey=$key';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final nameData = json.decode(utf8.decode(response.bodyBytes));
        // Cập nhật biến Rx
        _weatherName.assignAll(nameData);

        if (LocationName == '') {
          LocationName = _weatherName.isNotEmpty
              ? _weatherName["items"][0]["address"]["city"]
              : "";
        }
        InitialName = _weatherName.isNotEmpty
            ? _weatherName["items"][0]["address"]["city"]
            : "";
      } else {
        throw Exception('Fail to load Location name');
      }
    } catch (e) {
      print('Error getting location name: $e');
    }
  }
}
