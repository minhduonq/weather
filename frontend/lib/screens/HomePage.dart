import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:convert';
import 'package:frontend/services/database.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../services/constants.dart';
import 'LocationManage.dart';
import 'SearchPlace.dart';
import 'Setting.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  late bool servicePermission = false;
  late LocationPermission permission;

  @override
  void initState() {
    super.initState();
    deleteWeatherDBIfDebug(); // Gọi hàm xóa DB nếu đang debug
    _requestLocationPermission();
  }

  Future<void> _requestLocationPermission() async {
    servicePermission = await Geolocator.isLocationServiceEnabled();
    if (!servicePermission) {
      print('Service disable');
    }
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      // Handle case where user has permanently denied location permission
      print('Location permission denied permanently');
    }
    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      _getCurrentLocation();
    }
  }

  Future<void> _getCurrentLocation() async {
    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      currentPosition = position;
    });
    if (KeyLocation == null) {
      KeyLocation = currentPosition;
    }
    fetchWeatherData(KeyLocation!.latitude, KeyLocation!.longitude);
    // getAQIIndex(KeyLocation!.latitude, KeyLocation!.longitude);
    getLocationName(KeyLocation!.latitude, KeyLocation!.longitude);
    print(KeyLocation!.latitude);
    print(KeyLocation!.longitude);
  }

  Map<String, dynamic> currentData = {};
  Map<String, dynamic> hourlyData = {};
  Map<String, dynamic> dailyData = {};
  Map<String, dynamic> weatherName = {};
  Map<String, dynamic> weatherInfo = {};

  Future<void> getLocationName(double lat, double lon) async {
    final key = HereAPI;
    final lat = currentPosition?.latitude;
    final lon = currentPosition?.longitude;
    final url =
        'https://revgeocode.search.hereapi.com/v1/revgeocode?at=$lat,$lon&apiKey=$key';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      setState(() {
        weatherName = json.decode(utf8.decode(response.bodyBytes));
      });
    } else {
      throw Exception('Fail to load Location name');
    }
    if(LocationName == '') {
      LocationName = weatherName.isNotEmpty ? weatherName["items"][0]["address"]["city"] : "";
    }
    InitialName = weatherName.isNotEmpty ? weatherName["items"][0]["address"]["city"] : "";
  }

  Future<void> fetchWeatherData(double lat, double lon) async {
     // Load detail information
    //Change 192.168.x.x to your localIP, not localhost
    // final uri = Uri.parse(
    //   'http://192.168.1.13:3002/weather/detail?lat=$lat&lon=$lon',
    // );
    final uri =
        'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$API_KEY&units=$type';
    // final response = await http.get(Uri.parse(detail));
    try {
      final response = await http.get(Uri.parse(uri));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        final locationData = {
          'id': data['id'], // ID từ API
          'name': data['name'],
          'latitude': data['coord']['lat'],
          'longitude': data['coord']['lon'],
        };
        // // Lưu vào SQLite
        // final dbHelper = DatabaseHelper();
        // await dbHelper.insertLocation(locationData);
        // // Chuyển đổi dữ liệu từ API thành Map
        // final weatherData = {
        //   'location_id': data['id'], // Thay bằng ID của location tương ứng
        //   'temperature': data['main']['temp'],
        //   'feelsLike': data['main']['feels_like'],
        //   'maxTemp': data['main']['temp_max'],
        //   'minTemp': data['main']['temp_min'],
        //   'pressure': data['main']['pressure'],
        //   'humidity': data['main']['humidity'],
        //   'windSpeed': data['wind']['speed'],
        //   'icon': data['weather'][0]['icon'],
        //   'description': data['weather'][0]['description'],
        //   'sunrise': data['sys']['sunrise'],
        //   'sunset': data['sys']['sunset'],
        //   'cloud': data['clouds']['all'],
        //   'visibility': data['visibility'],
        //   'timeZone': data['timezone'],
        //   'updatedAt': DateTime.now().toIso8601String(),
        // };
        //
        // await dbHelper.insertWeatherData(weatherData);
        setState(() {
          currentData = json.decode(response.body);
        });
      } else {
        setState(() {
          print('Failed to load weather data');
        });
      }
    } catch (e) {
      setState(() {
        print('Error: $e');
      });
    }

    final hourly =
        'https://pro.openweathermap.org/data/2.5/forecast/hourly?lat=$lat&lon=$lon&appid=$API_KEY&cnt=24&units=$type';
    final response2 = await http.get(Uri.parse(hourly));
    if (response2.statusCode == 200) {
      final data = json.decode(response2.body);

      // Lấy location_id từ API
      final locationId = data['city']['id'];

      // Lấy danh sách hourly data
      final List<dynamic> hourlyList = data['list'];

      // Lưu từng mục vào bảng hourly_data
      // final dbHelper = DatabaseHelper();
      // for (var hourly in hourlyList) {
      //   final hourlyData = {
      //     'location_id': locationId,
      //     'time': hourly['dt'],
      //     'temperatureMax': hourly['main']['temp_max'],
      //     'temperatureMin': hourly['main']['temp_min'],
      //     'humidity': hourly['main']['humidity'],
      //     'icon': hourly['weather'][0]['icon'],
      //   };
      //
      //   await dbHelper.insertHourlyData(hourlyData);
      // }

      setState(() {
        hourlyData = json.decode(response2.body);
      });
    } else {
      throw Exception('Failed to load weather data hourly');
    }

    final daily =
        'http://api.openweathermap.org/data/2.5/forecast/daily?lat=$lat&lon=$lon&cnt=7&appid=$API_KEY&units=$type';
    final response3 = await http.get(Uri.parse(daily));
    if (response3.statusCode == 200) {
      final data = json.decode(response3.body);

      // Lấy location_id từ API
      final locationId = data['city']['id'];

      // Lấy danh sách daily data
      final List<dynamic> dailyList = data['list'];

      // Lưu từng mục vào bảng daily_data
      // final dbHelper = DatabaseHelper();
      // for (var daily in dailyList) {
      //   final dailyData = {
      //     'location_id': locationId,
      //     'time': daily['dt'], // Thời gian dự báo
      //     'temperatureMax': daily['temp']['max'], // Nhiệt độ cao nhất
      //     'temperatureMin': daily['temp']['min'], // Nhiệt độ thấp nhất
      //     'humidity': daily['humidity'], // Độ ẩm
      //     'icon': daily['weather'][0]['icon'], // Biểu tượng thời tiết
      //   };
      //
      //   await dbHelper.insertDailyData(dailyData);
      // }

      setState(() {
        dailyData = json.decode(response3.body);
      });
    } else {
      throw Exception('Failed to load weather data daily');
    }
  }



  Future<void> printDatabaseData() async {
    final dbHelper = DatabaseHelper();

    // Lấy dữ liệu từ bảng location
    final locations = await dbHelper.getAllLocations();
    print('Locations: $locations');

    // Lấy dữ liệu từ bảng weather_data
    final weatherData = await dbHelper.getAllWeatherData();
    print('Weather Data: $weatherData');

    // Lấy dữ liệu từ bảng hourly_data
    final hourlyData = await dbHelper.getAllHourlyData();
    print('Hourly Data: $hourlyData');

    // Lấy dữ liệu từ bảng daily_data
    final dailyData = await dbHelper.getAllDailyData();
    print('Daily Data: $dailyData');
  }

  String formatEpochTimeToTime(int epochTime, int timezoneOffsetInSeconds) {
    // Cộng thêm timezone offset để chuyển sang giờ địa phương
    DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(
      (epochTime + timezoneOffsetInSeconds) * 1000,
      isUtc: true, // vì thời gian epoch từ API là UTC
    );

    String formattedTime =
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    return formattedTime;
  }

  String getDayName(int epochTime) {
    DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(epochTime * 1000);
    List<String> weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return weekdays[dateTime.weekday - 1];
  }

  String getWeatherIconPath(String iconCode) {
    return 'assets/svgs/$iconCode.svg';
  }

  void getDataForSelectedPlace(Map<String, dynamic> place) {
    LocationName = place['name'];
    final lat = place['latitude'];
    final lon = place['longitude'];
    fetchWeatherData(lat, lon);
    // getLocationName(lat, lon);
  }

  String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: Text('$LocationName'),
        ),
        backgroundColor: Colors.white,
        drawer: Drawer(
          backgroundColor: Colors.grey[200],
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        onPressed: () {},
                        icon: Image.asset(
                          'assets/svgs/AI.png',
                          width: 60,
                          height: 60,
                        ),
                        iconSize: 45,
                      ),
                      SizedBox(width: 16),
                      IconButton(
                        onPressed: () {
                          Navigator.of(context).push(MaterialPageRoute(builder: (context) => Setting()));
                        },
                        icon: Image.asset(
                          'assets/svgs/setting.png',
                          width: 35,
                          height: 35,
                        ),
                        iconSize: 25,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    '★ Favourite Places',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                ListTile(
                    contentPadding: EdgeInsets.only(left: 52.0),
                    title: Text('$InitialName'),
                    onTap: () {
                      setState(() {
                        LocationName = InitialName;
                        KeyLocation = null;
                        Navigator.of(context).push(MaterialPageRoute(builder: (context) =>  HomePage()));
                      });
                    }
                ),
                ListTile(
                    leading: Icon(Icons.location_searching_sharp),
                    title: Text('Other Places', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(builder: (context) =>  SearchPlace()));
                    }
                ),
                ...selectedPlaces.map((place) {
                  return ListTile(
                    contentPadding: EdgeInsets.only(left: 52.0),
                    title: Text(place['name']),
                    onTap: () {
                      // Thực hiện hành động khi bấm vào địa điểm, ví dụ hiển thị thông tin chi tiết
                      LocationName = OfficialName(place['name']);
                      KeyLocation = Position(
                        latitude: place['latitude'],
                        longitude: place['longitude'],
                        timestamp: DateTime.now(),
                        accuracy: 0.0,
                        altitude: 0.0,
                        heading: 0.0,
                        speed: 0.0,
                        speedAccuracy: 0.0,
                        altitudeAccuracy: 0.0,
                        headingAccuracy: 0.0,
                      );
                      Navigator.of(context).push(MaterialPageRoute(builder: (context) => HomePage()));
                    },
                  );
                }).toList(),
                ListTile(
                  leading: Icon(Icons.notes_outlined),
                  title: Text('Place Management', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(builder: (context) => LocationManage()));
                  },
                ),
                Divider(color: Colors.black54,),
              ],
            ),
          ),
        ),
        body:
            currentData.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Icon của bạn
                            // Image.asset(
                            //   'weather/assets/location.png', // Đường dẫn tới icon của bạn
                            //   width: 15, // Kích thước icon (có thể điều chỉnh)
                            //   height: 15, // Kích thước icon (có thể điều chỉnh)
                            // ),
                            SizedBox(width: 4), // Khoảng cách giữa icon và text
                            // Text "Hà Nội"
                            Text(
                              '${LocationName}',
                              style: TextStyle(fontSize: 19),
                            ),
                          ],
                        ),
                        Text(
                          '${currentData['main']['temp']}\u00B0',
                          style: TextStyle(fontSize: 17),
                        ),
                        Text(
                          'Feel like ${currentData['main']['feels_like']}\u00B0',
                        ),
                        Text(
                          'L: ${currentData['main']['temp_min']} H: ${currentData['main']['temp_max']}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 20),

                        //Hourly Forecast
                        Container(
                          width: MediaQuery.of(context).size.width - 20,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: Colors.white,
                          ),
                          child: ListTile(
                            title: Text(
                              currentData.isNotEmpty
                                  ? capitalize(
                                    currentData['weather'][0]['description'],
                                  )
                                  : '',
                            ),
                            subtitle: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: List.generate(
                                  (hourlyData['list']?.length ?? 0),
                                  (index) {
                                    double popValue =
                                        (hourlyData['list'][index]['pop'] ?? 0)
                                            .toDouble();
                                    int pop1 = (popValue * 100).round();
                                    return Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Column(
                                        children: [
                                          Text(
                                            '${formatEpochTimeToTime(hourlyData['list'][index]['dt'], currentData['timezone'])}',
                                          ),
                                          SvgPicture.asset(
                                            getWeatherIconPath(
                                              hourlyData['list'][index]['weather'][0]['icon'],
                                            ),
                                            width: 50,
                                            height: 50,
                                          ),
                                          Text(
                                            '${hourlyData['list'][index]['main']['temp']}\u00B0',
                                          ),
                                          Row(
                                            children: [
                                              SvgPicture.asset(
                                                "assets/svgs/pop.svg",
                                                width: 15,
                                                height: 15,
                                              ),
                                              Text('$pop1%'),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 10),
                        Container(
                          width: MediaQuery.of(context).size.width - 20,
                          padding: EdgeInsets.symmetric(horizontal: 0),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ListTile(
                            title: Text('Daily Forecast'),
                            subtitle: Column(
                              children: List.generate(
                                (dailyData['list'] as List?)?.length ?? 0,
                                (index) {
                                  final dayName = getDayName(
                                    dailyData['list'][index]['dt'],
                                  );
                                  var maxTemp = double.parse(
                                    dailyData['list'][index]['temp']['max']
                                        .toString(),
                                  );
                                  var minTemp = double.parse(
                                    dailyData['list'][index]['temp']['min']
                                        .toString(),
                                  );
                                  final weatherIcon =
                                      dailyData['list'][index]['weather'][0]['icon'];
                                  var pop = double.parse(
                                    dailyData['list'][index]['pop'].toString(),
                                  );
                                  int max = maxTemp.round();
                                  int min = minTemp.round();
                                  int pop1 = (pop * 100).round();
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width:
                                                (MediaQuery.of(context,).size.width -20) /10 *2.8,
                                            child: Text(
                                              '$dayName',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            width:
                                                (MediaQuery.of( context,).size.width - 20) / 10 * 1.5,
                                            child: Row(
                                              children: [
                                                SvgPicture.asset(
                                                  'assets/svgs/pop.svg',
                                                  width: 15,
                                                ),
                                                Text(' $pop1%'),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            width:
                                                (MediaQuery.of( context,).size.width - 20) / 10 *1.8,
                                            child: SvgPicture.asset(
                                              getWeatherIconPath(weatherIcon),
                                              width: 35,
                                              height: 35,
                                            ),
                                          ),
                                          Container(
                                            //width: (MediaQuery.of(context).size.width-20)*,
                                            child: Row(
                                              children: [
                                                Container(
                                                  padding: EdgeInsets.all(5),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                  ),
                                                  width:
                                                      (MediaQuery.of(
                                                            context,
                                                          ).size.width -
                                                          20) /
                                                      10 *
                                                      1.2,
                                                  child: Text(
                                                    '$max\u00B0',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                Container(
                                                  padding: EdgeInsets.all(5),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                  ),
                                                  width:
                                                      (MediaQuery.of( context,).size.width -20) /10 *1.2,
                                                  child: Text('$min\u00B0',style: TextStyle(fontWeight:FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Box 1: Humidity
                              Expanded(
                                child: Container(
                                  margin: const EdgeInsets.only(
                                    right: 8,
                                  ), // Khoảng cách giữa 2 box
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.blue.withOpacity(0.2), // màu viền
                                      width: 1,
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        'Humidity',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '${currentData['main']['humidity']}%',
                                        style: const TextStyle(fontSize: 24),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Box 2: Sea Level
                              Expanded(
                                child: Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  decoration: BoxDecoration(

                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.blue.withOpacity(0.2),
                                      width: 1,
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        'Sea Level',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '${currentData['main']['sea_level']}',
                                        style: const TextStyle(fontSize: 24),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Box 1: Cloudiness
                              Expanded(
                                child: Container(
                                  margin: const EdgeInsets.only(
                                    right: 8,
                                  ), // Khoảng cách giữa 2 box
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.blue.withOpacity(0.2), // màu viền
                                      width: 1,
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        'Cloud',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '${currentData['clouds']['all']}%',
                                        style: const TextStyle(fontSize: 24),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Box 2: Sea Level
                              Expanded(
                                child: Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  decoration: BoxDecoration(

                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.blue.withOpacity(0.2),
                                      width: 1,
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        'Wind Speed',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '${currentData['wind']['speed']}km/h',
                                        style: const TextStyle(fontSize: 24),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 10),
                        Container(
                          width: MediaQuery.of(context).size.width - 20,
                          height: 300, // Chiều cao của bản đồ
                          decoration: BoxDecoration(
                            // border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: InAppWebView(
                            initialFile: "assets/weather_map.html",
                            onWebViewCreated: (controller) async {
                              if (KeyLocation != null) {
                                await Future.delayed(
                                  Duration(seconds: 1),
                                ); // đảm bảo webView đã load xong
                                controller.evaluateJavascript(
                                  source: '''
      updateMap(${KeyLocation!.latitude}, ${KeyLocation!.longitude});
    ''',
                                );
                              }
                            },
                          ),
                        ),
                        SizedBox(height: 10),
                        Container(
                          width: MediaQuery.of(context).size.width - 20,
                          padding: EdgeInsets.symmetric(horizontal: 0),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),

                          ),
                          child: Row(

                            children: [
                              Expanded(child: Container(
                                padding: EdgeInsets.only(top: 10, bottom: 10),
                                width: (MediaQuery.of(context).size.width - 20)/2,
                                child: Column(
                                  children: [
                                    Text('Sunriset', style: TextStyle(fontWeight: FontWeight.bold),),
                                    Text('${formatEpochTimeToTime(currentData['sys']['sunrise'], currentData['timezone'])}',style: TextStyle(fontWeight: FontWeight.bold)),
                                    SvgPicture.asset("assets/svgs/sunrise.svg", width: 70, height: 70),

                                  ],
                                ),
                              ),
                              ),
                              Expanded(child: Container(
                                width: (MediaQuery.of(context).size.width - 20)/2,
                                padding: EdgeInsets.only(top: 10, bottom: 10),
                                child: Column(
                                  children: [
                                    Text('Sunset', style: TextStyle(fontWeight: FontWeight.bold),),
                                    Text('${formatEpochTimeToTime(currentData['sys']['sunset'], currentData['timezone'])}', style: TextStyle(fontWeight: FontWeight.bold),),
                                    SvgPicture.asset("assets/svgs/sunset.svg", width: 70, height: 70,)
                                  ],
                                ),
                              ),
                              )
                            ],
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          ),
                        ),
                        const SizedBox(height: 10,),
                        Container(
                          width: MediaQuery.of(context).size.width - 20,
                          padding: const EdgeInsets.only(top: 10, bottom: 10, left: 20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),

                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Row(
                              //   children: [
                              //     SvgPicture.asset('assets/svgs/aqi.svg', width: 15),
                              //     Text(' AQI: $aqiIndex')
                              //   ],
                              // ),
                              Row(
                                children: [
                                  SvgPicture.asset('assets/svgs/pressure.svg', width: 15,),
                                  Text(' Pressure: ${currentData['visibility']}nPa'),
                                ],
                              ),
                              // Row(
                              //   children: [
                              //     SvgPicture.asset('assets/svgs/cloudiness.svg', width: 15,),
                              //     Text(' Mây: ${currentData['clouds']['all']}%'),
                              //   ],
                              // ),
                              Row(
                                children: [
                                  SvgPicture.asset('assets/svgs/visibility.svg', width: 15,),
                                  Text(' Visibility: ${currentData['visibility']}m'),
                                ],
                              ),

                            ],
                          ),
                        ),
                        const SizedBox(height: 10,),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Text('  '),
                                SvgPicture.asset('assets/svgs/openweather.svg', height: 15,),
                                const Text(' OpenWeatherMap', style: TextStyle(fontSize: 10, color: Colors.black54),)
                              ],
                            ),
                            Row(
                              children: [
                                Text('Updated at ${formatEpochTimeToTime(currentData['dt'], currentData['timezone'])}   ', style: TextStyle(fontSize: 10),),
                              ],
                            )

                          ],
                        )
                      ],
                    ),
                  ),
                ),
      ),
    );
  }
}
