import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:frontend/screens/LocationManage.dart';
import 'package:frontend/screens/manage_location.dart';
import 'package:frontend/screens/weather_stogare.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../services/constants.dart';
import '../services/widget_service.dart';
import '../services/weather_service.dart';
import '../services/formatting_service.dart';
import '../services/location_service.dart';
import '../services/database.dart';
import 'SearchPlace.dart';
import 'Setting.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  PageController _pageController = PageController();
  List<Map<String, dynamic>> _locations = [];
  int _currentLocationIndex = 0;
  InAppWebViewController? _webViewController;

  // Getter methods to access data from services
  Map<String, dynamic> get currentData => WeatherService.currentData;
  Map<String, dynamic> get hourlyData => WeatherService.hourlyData;
  Map<String, dynamic> get dailyData => WeatherService.dailyData;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    await _loadSavedLocations();
    if (KeyLocation != null) {
      await WeatherService.loadWeatherData(
          KeyLocation!.latitude, KeyLocation!.longitude);
      await WeatherService.getLocationName(
          KeyLocation!.latitude, KeyLocation!.longitude);
      _setCurrentLocationIndex();
    } else {
      await _requestLocationAndLoadData();
    }
    setState(() {});
  }

  Future<void> _loadSavedLocations() async {
    _locations = [];
    if (currentPosition != null) {
      _locations.add({
        'id': 0,
        'name': InitialName,
        'latitude': currentPosition!.latitude,
        'longitude': currentPosition!.longitude,
        'isCurrent': true
      });
    }
    final savedLocations = await DatabaseHelper().getAllLocations();
    for (var location in savedLocations) {
      if (location['name'] != InitialName) {
        _locations.add({
          'id': location['id'],
          'name': location['name'],
          'latitude': location['latitude'],
          'longitude': location['longitude'],
          'isCurrent': false
        });
      }
    }
  }

  void _setCurrentLocationIndex() {
    if (KeyLocation == null) {
      _currentLocationIndex = 0;
      return;
    }
    for (int i = 0; i < _locations.length; i++) {
      final location = _locations[i];
      if ((location['isCurrent'] == true && LocationName == InitialName) ||
          (location['name'] == LocationName &&
              location['latitude'] == KeyLocation!.latitude &&
              location['longitude'] == KeyLocation!.longitude)) {
        _currentLocationIndex = i;
        if (_pageController.hasClients) {
          _pageController.jumpToPage(i);
        }
        return;
      }
    }
  }

  Future<void> _requestLocationAndLoadData() async {
    bool hasPermission = await LocationService.requestLocationPermission();
    if (hasPermission) {
      await _getCurrentLocation();
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position? position = await LocationService.getCurrentLocation();
      if (position != null) {
        setState(() {
          currentPosition = position;
        });
        if (KeyLocation == null) {
          KeyLocation = currentPosition;
        }
        await WeatherService.loadWeatherData(
            KeyLocation!.latitude, KeyLocation!.longitude);
        await WeatherService.getLocationName(
            KeyLocation!.latitude, KeyLocation!.longitude);
        setState(() {});
      }
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  bool _isDaytime() {
    if (currentData.isEmpty || !currentData.containsKey('sys')) {
      return true;
    }
    final int currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final int sunriseTime = currentData['sys']['sunrise'];
    final int sunsetTime = currentData['sys']['sunset'];
    return currentTime >= sunriseTime && currentTime <= sunsetTime;
  }

  Color _getBackgroundColor() {
    return _isDaytime() ? Color(0xFF66CEED) : Color(0xFF295EA7);
  }

  void _updateMap() {
    if (_webViewController != null && KeyLocation != null) {
      _webViewController!.evaluateJavascript(
        source:
            '''updateMap(${KeyLocation!.latitude}, ${KeyLocation!.longitude});''',
      );
    }
  }

  Future<void> _refreshData() async {
    if (!mounted) return;
    final currentLocation = _locations[_currentLocationIndex];
    try {
      await WeatherService.fetchWeatherData(
          currentLocation['latitude'], currentLocation['longitude']);
      if (!currentLocation['isCurrent']) {
        await WeatherService.getLocationName(
            currentLocation['latitude'], currentLocation['longitude']);
      }
      _updateMap();
      setState(() {});
    } catch (e) {
      print('Error refreshing data: $e');
    }
  }

  String formatEpochTimeToTime(int epochTime, int timezoneOffsetInSeconds) {
    DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(
      (epochTime + timezoneOffsetInSeconds) * 1000,
      isUtc: true,
    );
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String getDayName(int epochTime) {
    DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(epochTime * 1000);
    List<String> weekdays = [
      'Thứ Hai',
      'Thứ Ba',
      'Thứ Tư',
      'Thứ Năm',
      'Thứ Sáu',
      'Thứ Bảy',
      'Chủ Nhật',
    ];
    return weekdays[dateTime.weekday - 1];
  }

  String getWeatherIconPath(String iconCode) {
    return 'assets/svgs/$iconCode.svg';
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: _getBackgroundColor(),
        appBarTheme: AppBarTheme(
          backgroundColor: _getBackgroundColor(),
          elevation: 0,
        ),
      ),
      home: Scaffold(
        appBar: AppBar(
          title: Text(
            LocationName ?? 'Weather',
            style: TextStyle(
                color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.search, color: Colors.white, size: 32),
              onPressed: () {
                Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => SearchPlace()));
              },
            ),
          ],
        ),
        body: AnimatedContainer(
          duration: Duration(milliseconds: 500),
          color: _getBackgroundColor(),
          child: currentData.isEmpty || _locations.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : PageView.builder(
                  controller: _pageController,
                  itemCount: _locations.length,
                  onPageChanged: (index) async {
                    setState(() {
                      _currentLocationIndex = index;
                    });
                    final location = _locations[index];
                    KeyLocation = Position(
                      latitude: location['latitude'],
                      longitude: location['longitude'],
                      timestamp: DateTime.now(),
                      accuracy: 0,
                      altitude: 0,
                      heading: 0,
                      speed: 0,
                      speedAccuracy: 0,
                      altitudeAccuracy: 0,
                      headingAccuracy: 0,
                    );
                    await _refreshData();
                  },
                  itemBuilder: (context, index) {
                    return _buildMainContent();
                  },
                ),
        ),
        bottomNavigationBar: Container(
          color: _getBackgroundColor(),
          child: _buildLocationNavigator(),
        ),
      ),
    );
  }

  Widget _buildLocationNavigator() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Row(
              children: [
                Icon(Icons.menu, color: Colors.white),
                SizedBox(width: 10),
              ],
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => WeatherStorageScreen(),
                ),
              );
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_locations.length, (index) {
              bool isActive = index == _currentLocationIndex;
              return GestureDetector(
                onTap: () {
                  if (_pageController.hasClients) {
                    _pageController.animateToPage(
                      index,
                      duration: Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                },
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 300),
                  margin: EdgeInsets.symmetric(horizontal: 5),
                  height: isActive ? 12 : 8,
                  width: isActive ? 12 : 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        isActive ? Colors.white : Colors.white.withOpacity(0.5),
                  ),
                ),
              );
            }),
          ),
          IconButton(
            icon: Icon(Icons.settings, color: Colors.white),
            onPressed: () {
              Navigator.of(context)
                  .push(MaterialPageRoute(builder: (context) => Setting()));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Location and Temperature
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 4),
                  Text(
                    LocationName ?? _locations[_currentLocationIndex]['name'],
                    style: TextStyle(fontSize: 19, color: Colors.white),
                  ),
                ],
              ),
              if (currentData.containsKey('main'))
                Text(
                  '${currentData['main']['temp'].round()}\u00B0',
                  style: TextStyle(
                      fontSize: 60,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              if (currentData.containsKey('main'))
                Text(
                  'Feels like ${currentData['main']['feels_like'].round()}\u00B0',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              if (currentData.containsKey('main'))
                Text(
                  'L: ${currentData['main']['temp_min'].round()} H: ${currentData['main']['temp_max'].round()}',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              SizedBox(height: 20),

              // Hourly Forecast
              Container(
                width: MediaQuery.of(context).size.width - 32,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListTile(
                  title: Text('Dự báo 48 giờ',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(
                        hourlyData['list']?.length ?? 0,
                        (index) {
                          double popValue =
                              (hourlyData['list'][index]['pop'] ?? 0)
                                  .toDouble();
                          int pop1 = (popValue * 100).round();
                          return Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              children: [
                                Text(formatEpochTimeToTime(
                                    hourlyData['list'][index]['dt'],
                                    currentData['timezone'] ?? 0)),
                                SvgPicture.asset(
                                  getWeatherIconPath(hourlyData['list'][index]
                                      ['weather'][0]['icon']),
                                  width: 50,
                                  height: 50,
                                ),
                                Text(
                                    '${hourlyData['list'][index]['main']['temp'].round()}\u00B0'),
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

              // Daily Forecast
              Container(
                width: MediaQuery.of(context).size.width - 32,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListTile(
                  title: Text('Dự báo hàng ngày',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    children: List.generate(
                      dailyData['list']?.length ?? 0,
                      (index) {
                        final dayName =
                            getDayName(dailyData['list'][index]['dt']);
                        var maxTemp = double.parse(
                            dailyData['list'][index]['temp']['max'].toString());
                        var minTemp = double.parse(
                            dailyData['list'][index]['temp']['min'].toString());
                        final weatherIcon =
                            dailyData['list'][index]['weather'][0]['icon'];
                        var pop = double.parse(
                            dailyData['list'][index]['pop'].toString());
                        int max = maxTemp.round();
                        int min = minTemp.round();
                        int pop1 = (pop * 100).round();
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            children: [
                              Container(
                                width:
                                    (MediaQuery.of(context).size.width - 32) /
                                        10 *
                                        3,
                                child: Text(
                                  dayName,
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              Container(
                                width:
                                    (MediaQuery.of(context).size.width - 32) /
                                        10 *
                                        1.3,
                                child: Row(
                                  children: [
                                    SvgPicture.asset('assets/svgs/pop.svg',
                                        width: 15),
                                    Text(' $pop1%'),
                                  ],
                                ),
                              ),
                              Container(
                                width:
                                    (MediaQuery.of(context).size.width - 32) /
                                        10 *
                                        1.8,
                                child: SvgPicture.asset(
                                  getWeatherIconPath(weatherIcon),
                                  width: 35,
                                  height: 35,
                                ),
                              ),
                              Expanded(
                                child: Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      width:
                                          (MediaQuery.of(context).size.width -
                                                  32) /
                                              10 *
                                              1.2,
                                      child: Text(
                                        '$max\u00B0',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Container(
                                      padding: EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      width:
                                          (MediaQuery.of(context).size.width -
                                                  32) /
                                              10 *
                                              1.2,
                                      child: Text(
                                        '$min\u00B0',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              SizedBox(height: 10),

              // Visibility and Pressure
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Tầm nhìn',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                          Text(
                            currentData.containsKey('visibility')
                                ? '${currentData['visibility'] ~/ 1000} km'
                                : 'N/A',
                            style: TextStyle(fontSize: 24, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(left: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Áp suất',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                          Text(
                            currentData.containsKey('main')
                                ? '${currentData['main']['pressure']} hPa'
                                : 'N/A',
                            style: TextStyle(fontSize: 24, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),

              // Sun Arc
              if (currentData.containsKey('sys'))
                Container(
                  height: 150,
                  child: CustomPaint(
                    painter: SunArcPainter(
                      sunriseTime: currentData['sys']['sunrise'],
                      sunsetTime: currentData['sys']['sunset'],
                      currentTime:
                          DateTime.now().millisecondsSinceEpoch ~/ 1000,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSunTimeBox(
                          'Mặt trời mọc',
                          formatEpochTimeToTime(currentData['sys']['sunrise'],
                              currentData['timezone']),
                        ),
                        _buildSunTimeBox(
                          'Mặt trời lặn',
                          formatEpochTimeToTime(currentData['sys']['sunset'],
                              currentData['timezone']),
                        ),
                      ],
                    ),
                  ),
                ),
              SizedBox(height: 10),

              // Wind Direction
              if (currentData.containsKey('wind'))
                Container(
                  height: 150,
                  child: CustomPaint(
                    painter: WindDirectionPainter(
                      currentData['wind']['deg'].toDouble(),
                      currentData['wind']['speed'].toDouble(),
                    ),
                    child: Center(),
                  ),
                ),
              SizedBox(height: 10),

              // Map
              Container(
                width: MediaQuery.of(context).size.width - 32,
                height: 300,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: InAppWebView(
                  initialFile: "assets/weather_map.html",
                  initialOptions: InAppWebViewGroupOptions(
                    crossPlatform: InAppWebViewOptions(
                      javaScriptEnabled: true,
                    ),
                  ),
                  onWebViewCreated: (controller) {
                    _webViewController = controller;
                    if (KeyLocation != null) {
                      controller.evaluateJavascript(source: '''
                        updateMap(${KeyLocation!.latitude}, ${KeyLocation!.longitude});
                      ''');
                    }
                  },
                ),
              ),
              SizedBox(height: 10),

              // Footer
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSunTimeBox(String title, String time) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w400, color: Colors.white),
        ),
        SizedBox(height: 8),
        Text(
          time,
          style: TextStyle(
              fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Text('  '),
            SvgPicture.asset('assets/svgs/openweather.svg', height: 15),
            const Text(' OpenWeather',
                style: TextStyle(fontSize: 10, color: Colors.white)),
          ],
        ),
        Row(
          children: [
            Text(
              'Cập nhật lúc ${FormattingService.formatEpochTimeToTime(currentData['dt'], currentData['timezone'])}',
              style: TextStyle(fontSize: 10, color: Colors.white),
            ),
          ],
        ),
      ],
    );
  }
}

// Custom Painters (Giữ nguyên từ mã của bạn)
class SunArcPainter extends CustomPainter {
  final int sunriseTime;
  final int sunsetTime;
  final int currentTime;

  SunArcPainter({
    required this.sunriseTime,
    required this.sunsetTime,
    required this.currentTime,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint yellowPaint = Paint()
      ..color = Colors.yellow
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final Paint grayPaint = Paint()
      ..color = Colors.grey.shade400
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    double widthReduction = size.width * 0.1;
    final Rect rect = Rect.fromLTRB(
      widthReduction,
      size.height * 0.2,
      size.width - widthReduction,
      size.height * 2.3,
    );

    double progress;
    if (currentTime < sunriseTime) {
      progress = 0;
    } else if (currentTime > sunsetTime) {
      progress = 1;
    } else {
      progress = (currentTime - sunriseTime) / (sunsetTime - sunriseTime);
    }

    canvas.drawArc(rect, pi, pi * progress, false, yellowPaint);
    canvas.drawArc(
        rect, pi + pi * progress, pi * (1 - progress), false, grayPaint);

    if (progress > 0 && progress < 1) {
      final double angle = pi * progress + pi;
      final double sunX = rect.center.dx + rect.width / 2 * cos(angle);
      final double sunY = rect.center.dy + rect.height / 2 * sin(angle);

      final Paint sunGlowPaint = Paint()
        ..color = Colors.yellow.withOpacity(0.3)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(sunX, sunY), 12, sunGlowPaint);

      final Paint sunPaint = Paint()
        ..color = Colors.yellow
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(sunX, sunY), 8, sunPaint);

      final Paint rayPaint = Paint()
        ..color = Colors.yellow
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;

      const int numRays = 8;
      const double rayLength = 8.0;

      for (int i = 0; i < numRays; i++) {
        double rayAngle = 2 * pi * i / numRays;
        double startX = sunX + 8 * cos(rayAngle);
        double startY = sunY + 8 * sin(rayAngle);
        double endX = sunX + (8 + rayLength) * cos(rayAngle);
        double endY = sunY + (8 + rayLength) * sin(rayAngle);

        canvas.drawLine(Offset(startX, startY), Offset(endX, endY), rayPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class GaugePainter extends CustomPainter {
  final double value;

  GaugePainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = min(size.width / 2, size.height);

    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), pi, pi,
        false, bgPaint);

    final valuePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), pi,
        pi * value, false, valuePaint);

    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final angle = pi + pi * value;
    final dotX = center.dx + radius * cos(angle);
    final dotY = center.dy + radius * sin(angle);

    canvas.drawCircle(Offset(dotX, dotY), 6, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class WindDirectionPainter extends CustomPainter {
  final double windDegree;
  final double windSpeed;

  WindDirectionPainter(this.windDegree, this.windSpeed);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 1.1;

    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawCircle(center, radius, bgPaint);

    final textStyle = TextStyle(
      color: Colors.white,
      fontSize: 16,
      fontWeight: FontWeight.bold,
    );
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    void drawCardinalPoints() {
      textPainter.text = TextSpan(text: 'N', style: textStyle);
      textPainter.layout();
      textPainter.paint(canvas,
          Offset(center.dx - textPainter.width / 2, center.dy - radius - 20));

      textPainter.text = TextSpan(text: 'E', style: textStyle);
      textPainter.layout();
      textPainter.paint(canvas,
          Offset(center.dx + radius + 8, center.dy - textPainter.height / 2));

      textPainter.text = TextSpan(text: 'S', style: textStyle);
      textPainter.layout();
      textPainter.paint(canvas,
          Offset(center.dx - textPainter.width / 2, center.dy + radius + 8));

      textPainter.text = TextSpan(text: 'W', style: textStyle);
      textPainter.layout();
      textPainter.paint(
          canvas,
          Offset(center.dx - radius - textPainter.width - 8,
              center.dy - textPainter.height / 2));
    }

    drawCardinalPoints();

    final arrowAngle = (windDegree - 90) * pi / 180;
    final arrowPositionX = center.dx + radius * 0.85 * cos(arrowAngle);
    final arrowPositionY = center.dy + radius * 0.85 * sin(arrowAngle);

    final arrowheadPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final arrowSize = 6.0;
    final backOffset = 12.0;

    final path = Path();
    path.moveTo(arrowPositionX, arrowPositionY);
    path.lineTo(
        arrowPositionX -
            backOffset * cos(arrowAngle) +
            arrowSize * cos(arrowAngle - pi / 2),
        arrowPositionY -
            backOffset * sin(arrowAngle) +
            arrowSize * sin(arrowAngle - pi / 2));
    path.lineTo(arrowPositionX - backOffset * 0.7 * cos(arrowAngle),
        arrowPositionY - backOffset * 0.7 * sin(arrowAngle));
    path.lineTo(
        arrowPositionX -
            backOffset * cos(arrowAngle) +
            arrowSize * cos(arrowAngle + pi / 2),
        arrowPositionY -
            backOffset * sin(arrowAngle) +
            arrowSize * sin(arrowAngle + pi / 2));
    path.close();

    canvas.drawPath(path, arrowheadPaint);

    final centerCirclePaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius * 0.8, centerCirclePaint);

    textPainter.text = TextSpan(
      text: '${windSpeed.toStringAsFixed(1)}',
      style: TextStyle(
          color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
    );
    textPainter.layout();
    textPainter.paint(
        canvas,
        Offset(center.dx - textPainter.width / 2,
            center.dy - textPainter.height / 2 - 5));

    textPainter.text = TextSpan(
      text: 'km/h',
      style: TextStyle(color: Colors.white, fontSize: 12),
    );
    textPainter.layout();
    textPainter.paint(
        canvas, Offset(center.dx - textPainter.width / 2, center.dy + 10));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
