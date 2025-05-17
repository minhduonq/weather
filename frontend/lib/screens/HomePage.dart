import 'dart:math';
import 'package:frontend/screens/weather_stogare.dart';
import 'package:get/get.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:frontend/screens/manage_location.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../services/constants.dart';
import '../services/widget_service.dart';
import '../services/weather_service.dart';
import '../services/formatting_service.dart';
import '../services/location_service.dart';
import '../services/database.dart';
import '../services/helpTrans.dart';
import 'SearchPlace.dart';
import 'Setting.dart';
import 'Chatbot.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  PageController _pageController = PageController();
  List<Map<String, dynamic>> _locations = [];
  int _currentLocationIndex = 0;
  bool _isLoading = true; // Thêm biến trạng thái loading
  bool _isInitialized = false;

  InAppWebViewController? _webViewController;

  // Getter methods to access data from services
  Map<String, dynamic> get currentData => WeatherService.currentData;
  Map<String, dynamic> get hourlyData => WeatherService.hourlyData;
  Map<String, dynamic> get dailyData => WeatherService.dailyData;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Chạy sau khi build hoàn tất để tránh lỗi setState trong build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
    if (mounted) {
      setState(() {});
    }
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
      if (mounted) {
        setState(() {});
      }
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
    await WeatherService.loadWeatherData(
        currentLocation['latitude'], currentLocation['longitude']);
    if (!currentLocation['isCurrent']) {
      await WeatherService.getLocationName(
          currentLocation['latitude'], currentLocation['longitude']);
    }
    _updateMap();
    if (mounted) {
      setState(() {});
    }
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
              icon: Icon(Icons.chat, color: Colors.white, size: 30),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => ChatbotScreen()),
                );
              },
            ),
            IconButton(
              icon: Icon(Icons.search, color: Colors.white, size: 32),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => SearchPlace()),
                );
              },
            ),
          ],
        ),
        body: AnimatedContainer(
          duration: Duration(milliseconds: 500),
          color: _getBackgroundColor(),
          child: currentData.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _buildMainContent(),
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
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => WeatherStorageScreen()));
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
    if (_locations.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return PageView.builder(
      controller: _pageController,
      itemCount: _locations.length,
      onPageChanged: (index) async {
        setState(() {
          _currentLocationIndex = index;
          final location = _locations[index];
          LocationName = location['name'];
          KeyLocation = Position(
            latitude: location['latitude'],
            longitude: location['longitude'],
            timestamp: DateTime.now(),
            accuracy: 0.0,
            altitude: 0.0,
            heading: 0.0,
            speed: 0.0,
            speedAccuracy: 0.0,
            altitudeAccuracy: 0.0,
            headingAccuracy: 0.0,
          );
        });
        await WeatherService.loadWeatherData(
            KeyLocation!.latitude, KeyLocation!.longitude);
        if (!_locations[index]['isCurrent']) {
          await WeatherService.getLocationName(
              KeyLocation!.latitude, KeyLocation!.longitude);
        }
        _updateMap();
        if (mounted) {
          setState(() {});
        }
      },
      itemBuilder: (context, index) {
        return RefreshIndicator(
          onRefresh: _refreshData,
          color: Colors.white,
          backgroundColor: Colors.lightBlueAccent,
          child: SingleChildScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildCurrentWeather(),
                  SizedBox(height: 20),
                  _buildHourlyForecast(),
                  SizedBox(height: 10),
                  _buildDailyForecast(),
                  SizedBox(height: 10),
                  _buildWeatherDetailsGrid(),
                  SizedBox(height: 10),
                  _buildWeatherMap(),
                  SizedBox(height: 10),
                  _buildSunriseSunset(),
                  SizedBox(height: 10),
                  _buildFooter(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCurrentWeather() {
    return Container(
      height: 180,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            left: 16,
            top: 0,
            right: 100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${currentData['main']['temp']}\u00B0',
                  style: TextStyle(
                      fontSize: 55,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                  overflow: TextOverflow.visible,
                ),
                SizedBox(height: 10),
                Text(
                  currentData.isNotEmpty &&
                          currentData['weather'] != null &&
                          currentData['weather'].isNotEmpty
                      ? '${currentData['weather'][0]['main']}'
                      : '',
                  style: TextStyle(fontSize: 22, color: Colors.white),
                ),
                SizedBox(height: 10),
                Text(
                    '${currentData['main']['temp_min']}\u00B0 / ${currentData['main']['temp_max']}\u00B0',
                    style: TextStyle(color: Colors.white, fontSize: 18)),
                Text('Feel like ${currentData['main']['feels_like']}\u00B0',
                    style: TextStyle(color: Colors.white, fontSize: 18)),
              ],
            ),
          ),
          Positioned(
            right: 10,
            top: 0,
            child: SvgPicture.asset(
                FormattingService.getWeatherIconPath(
                    currentData['weather'][0]['icon']),
                height: 150,
                width: 150),
          ),
        ],
      ),
    );
  }

  Widget _buildHourlyForecast() {
    return Container(
      width: MediaQuery.of(context).size.width - 20,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Color(0xFFBBDFEA).withAlpha(38),
      ),
      child: ListTile(
        title: Text(
            currentData.isNotEmpty
                ? FormattingService.capitalize(
                    currentData['weather'][0]['description'])
                : '',
            style: TextStyle(color: Colors.white, fontSize: 20)),
        subtitle: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(
              (hourlyData['list']?.length ?? 0),
              (index) {
                double popValue =
                    (hourlyData['list'][index]['pop'] ?? 0).toDouble();
                int pop1 = (popValue * 100).round();
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      Text(
                          '${FormattingService.formatEpochTimeToTime(hourlyData['list'][index]['dt'], currentData['timezone'])}',
                          style: TextStyle(color: Colors.white)),
                      SvgPicture.asset(
                        FormattingService.getWeatherIconPath(
                          hourlyData['list'][index]['weather'][0]['icon'],
                        ),
                        width: 50,
                        height: 50,
                      ),
                      Text('${hourlyData['list'][index]['main']['temp']}\u00B0',
                          style: TextStyle(color: Colors.white)),
                      Row(
                        children: [
                          SvgPicture.asset(
                            "assets/svgs/pop.svg",
                            width: 15,
                            height: 15,
                          ),
                          Text('$pop1%', style: TextStyle(color: Colors.white)),
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
    );
  }

  Widget _buildDailyForecast() {
    if (dailyData.isEmpty || dailyData['list'] == null) {
      return Container();
    }
    Map<String, dynamic> uniqueDays = {};
    for (var item in dailyData['list']) {
      final dayName = FormattingService.getDayName(item['dt']);
      if (!uniqueDays.containsKey(dayName)) {
        uniqueDays[dayName] = item;
      }
    }
    List<MapEntry<String, dynamic>> sortedEntries = uniqueDays.entries.toList();
    return Container(
      width: MediaQuery.of(context).size.width - 20,
      padding: EdgeInsets.symmetric(horizontal: 0),
      decoration: BoxDecoration(
        color: Color(0xFFBBDFEA).withAlpha(38),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        title: trWithStyle(
          'daily_forecast',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          children: List.generate(
            min(sortedEntries.length, 7),
            (index) {
              final entry = sortedEntries[index];
              final dayData = entry.value;
              final dayName = entry.key;
              var maxTemp = double.parse(dayData['temp']['max'].toString());
              var minTemp = double.parse(dayData['temp']['min'].toString());
              final weatherIcon = dayData['weather'][0]['icon'];
              var pop = double.parse(dayData['pop'].toString());
              int max = maxTemp.round();
              int min = minTemp.round();
              int pop1 = (pop * 100).round();
              return _buildDailyRow(dayName, pop1, weatherIcon, max, min);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDailyRow(
      String dayName, int pop, String weatherIcon, int max, int min) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: (MediaQuery.of(context).size.width - 20) / 10 * 2.5,
              child: Text(
                '$dayName',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              width: (MediaQuery.of(context).size.width - 20) / 10 * 1.5,
              child: Row(
                children: [
                  SvgPicture.asset(
                    'assets/svgs/pop.svg',
                    width: 15,
                  ),
                  Text(
                    ' $pop%',
                    style: TextStyle(color: Colors.white, fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              width: (MediaQuery.of(context).size.width - 20) / 10 * 1.5,
              child: SvgPicture.asset(
                FormattingService.getWeatherIconPath(weatherIcon),
                width: 35,
                height: 35,
              ),
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '$max\u00B0',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 19),
                      overflow: TextOverflow.visible,
                    ),
                  ),
                  SizedBox(width: 10),
                  Container(
                    width: 45,
                    alignment: Alignment.centerRight,
                    child: Text(
                      '$min\u00B0',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 18),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  SizedBox(width: 8),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailBox(String title, String value) {
    return Expanded(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Color(0xFFBBDFEA).withAlpha(38),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text(
              value,
              style: const TextStyle(fontSize: 24, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherDetailsGrid() {
    return Container(
      width: MediaQuery.of(context).size.width - 20,
      child: GridView.count(
        physics: NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        crossAxisCount: 2,
        childAspectRatio: 0.9,
        mainAxisSpacing: 10.0,
        crossAxisSpacing: 10.0,
        children: [
          _buildDetailCard(
            icon: 'assets/svgs/humidity.svg',
            title: 'Humidity'.tr,
            value: '${currentData['main']['humidity']}%',
            subtitle: '',
            progress: currentData['main']['humidity'] / 100,
            colorStart: Colors.blue.shade100,
            colorEnd: Colors.blue.shade500,
          ),
          _buildDetailCard(
            icon: 'assets/svgs/pressure.svg',
            title: 'Pressure'.tr,
            value: '${currentData['main']['pressure']} mb',
            subtitle: '',
            showGauge: true,
            gaugeValue: currentData['main']['pressure'] / 1050,
          ),
          _buildDetailCard(
            icon: 'assets/svgs/wind.svg',
            title: 'Wind'.tr,
            value: '',
            subtitle: '',
            showWindDirection: true,
            windDegree: currentData['wind'] != null &&
                    currentData['wind']['deg'] != null
                ? currentData['wind']['deg'].toDouble()
                : 0.0,
            windSpeed: currentData['wind'] != null &&
                    currentData['wind']['speed'] != null
                ? currentData['wind']['speed'].toDouble()
                : 0.0,
          ),
          _buildDetailCard(
            icon: 'assets/svgs/visibility.svg',
            title: 'Visibility'.tr,
            value:
                '${(currentData['visibility'] / 1000).toStringAsFixed(2)} km',
            subtitle: '',
          ),
          _buildDetailCard(
            icon: 'assets/svgs/sea_level.svg',
            title: 'Sea Level'.tr,
            value: '${currentData['main']['sea_level']} hPa',
            subtitle: '',
          ),
          _buildDetailCard(
            icon: 'assets/svgs/cloudiness.svg',
            title: 'Clouds'.tr,
            value: '${currentData['clouds']['all']}%',
            subtitle: '',
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard({
    required String icon,
    required String title,
    required String value,
    required String subtitle,
    double? progress,
    Color? colorStart,
    Color? colorEnd,
    bool showGauge = false,
    bool showWindDirection = false,
    double? gaugeValue,
    double? windDegree,
    double? windSpeed,
  }) {
    return Container(
      padding: EdgeInsets.all(10), // Reduced from 15
      decoration: BoxDecoration(
        color: Color(0xFFBBDFEA).withAlpha(38),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SvgPicture.asset(
                icon,
                width: 16, // Reduced from 20
                height: 16,
                color: Colors.white,
              ),
              SizedBox(width: 6), // Reduced from 8
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14, // Reduced from 16
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 6), // Reduced from 8
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12, // Reduced from 14
            ),
          ),
          SizedBox(height: 6), // Reduced from 8
          if (progress != null)
            Container(
              margin: EdgeInsets.only(top: 6), // Reduced from 10
              height: 5, // Reduced from 6
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white.withOpacity(0.3),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    colorStart?.withOpacity(1.0) ?? Colors.blue,
                  ),
                ),
              ),
            ),
          if (showGauge && gaugeValue != null)
            Container(
              margin: EdgeInsets.only(top: 6), // Reduced from 10
              height: 30, // Reduced from 50
              child: CustomPaint(
                painter: GaugePainter(gaugeValue),
                size: Size.infinite,
              ),
            ),
          if (showWindDirection && windDegree != null)
            Container(
              margin: EdgeInsets.only(top: 4), // Reduced from 5
              height: 30, // Reduced from 50
              alignment: Alignment.center,
              child: CustomPaint(
                painter: WindDirectionPainter(windDegree, windSpeed ?? 0),
                size: Size(100, 100), // Reduced from 150x150
              ),
            ),
          SizedBox(height: 6), // Replaced Spacer with fixed height
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 24, // Reduced from 32
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherMap() {
    return Container(
      width: MediaQuery.of(context).size.width - 20,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Color(0xFFBBDFEA).withAlpha(38),
      ),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'radar_and_map'.tr,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 300,
              width: double.infinity,
              child: InAppWebView(
                initialFile: "assets/weather_map.html",
                onWebViewCreated: (controller) async {
                  _webViewController = controller;
                  _updateMap();
                },
              ),
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Current temperature is ${currentData['main']['temp'].toStringAsFixed(0)}°',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w400,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSunriseSunset() {
    final int currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final int sunriseTime = currentData['sys']?['sunrise'] ?? currentTime;
    final int sunsetTime =
        currentData['sys']?['sunset'] ?? (currentTime + 43200);
    return Container(
      width: MediaQuery.of(context).size.width - 20,
      padding: EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Color(0xFFBBDFEA).withAlpha(38),
      ),
      child: Column(
        children: [
          SizedBox(
            width: MediaQuery.of(context).size.width - 60,
            height: 100,
            child: CustomPaint(
              painter: SunArcPainter(
                  sunriseTime: sunriseTime,
                  sunsetTime: sunsetTime,
                  currentTime: currentTime),
            ),
          ),
          SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSunTimeBox(
                'Sunrise'.tr,
                FormattingService.formatEpochTimeToTime(
                    currentData['sys']['sunrise'], currentData['timezone']),
              ),
              _buildSunTimeBox(
                'Sunset'.tr,
                FormattingService.formatEpochTimeToTime(
                    currentData['sys']['sunset'], currentData['timezone']),
              ),
            ],
          ),
        ],
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
                style: TextStyle(fontSize: 10, color: Colors.white))
          ],
        ),
        Row(
          children: [
            Text(
              'Updated at ${FormattingService.formatEpochTimeToTime(currentData['dt'], currentData['timezone'])}   ',
              style: TextStyle(fontSize: 10, color: Colors.white),
            ),
          ],
        )
      ],
    );
  }
}

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

    canvas.drawArc(
      rect,
      pi,
      pi * progress,
      false,
      yellowPaint,
    );

    canvas.drawArc(
      rect,
      pi + pi * progress,
      pi * (1 - progress),
      false,
      grayPaint,
    );

    if (progress > 0 && progress < 1) {
      final double angle = pi * progress + pi;
      final double sunX = rect.center.dx + rect.width / 2 * cos(angle);
      final double sunY = rect.center.dy + rect.height / 2 * sin(angle);
      final Paint sunGlowPaint = Paint()
        ..color = Colors.yellow.withOpacity(0.3)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(sunX, sunY),
        12,
        sunGlowPaint,
      );
      final Paint sunPaint = Paint()
        ..color = Colors.yellow
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(sunX, sunY),
        8,
        sunPaint,
      );
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
        canvas.drawLine(
          Offset(startX, startY),
          Offset(endX, endY),
          rayPaint,
        );
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
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );
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
        color: Colors.white,
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2 - 5,
      ),
    );
    textPainter.text = TextSpan(
      text: 'km/h',
      style: TextStyle(
        color: Colors.white,
        fontSize: 12,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy + 10,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
