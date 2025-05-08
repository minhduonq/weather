import 'dart:math';
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

import 'LocationManage.dart';
import 'SearchPlace.dart';
import 'Setting.dart';
import 'Chatbot.dart';

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
    // Lấy danh sách các vị trí đã lưu
    await _loadSavedLocations();

    if (KeyLocation != null) {
      // If we already have a location (from drawer selection), load its data
      await WeatherService.loadWeatherData(
          KeyLocation!.latitude, KeyLocation!.longitude);
      await WeatherService.getLocationName(
          KeyLocation!.latitude, KeyLocation!.longitude);

      // Tìm và đặt index cho vị trí hiện tại
      _setCurrentLocationIndex();
    } else {
      // Otherwise request location permission
      await _requestLocationAndLoadData();
    }
    // Update UI after data is loaded
    setState(() {});
  }

  Future<void> _loadSavedLocations() async {
    _locations = [];

    // Thêm vị trí hiện tại của người dùng đầu tiên
    if (currentPosition != null) {
      _locations.add({
        'id': 0,
        'name': InitialName,
        'latitude': currentPosition!.latitude,
        'longitude': currentPosition!.longitude,
        'isCurrent': true
      });
    }

    // Thêm các vị trí đã lưu
    final savedLocations = await DatabaseHelper().getAllLocations();
    for (var location in savedLocations) {
      // Bỏ qua nếu trùng với vị trí hiện tại
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

      // Load weather data
      await WeatherService.loadWeatherData(
          KeyLocation!.latitude, KeyLocation!.longitude);
      await WeatherService.getLocationName(
          KeyLocation!.latitude, KeyLocation!.longitude);
      print(KeyLocation!.latitude);
      print(KeyLocation!.longitude);

      // Update UI
      setState(() {});
    }
  }

  // Kiểm tra xem thời gian hiện tại có phải ban ngày không
  bool _isDaytime() {
    if (currentData.isEmpty || !currentData.containsKey('sys')) {
      return true; // Mặc định là ban ngày nếu không có dữ liệu
    }

    final int currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final int sunriseTime = currentData['sys']['sunrise'];
    final int sunsetTime = currentData['sys']['sunset'];

    return currentTime >= sunriseTime && currentTime <= sunsetTime;
  }

// Lấy màu nền phù hợp với thời gian hiện tại
  Color _getBackgroundColor() {
    return _isDaytime()
        ? Color(0xFF66CEED) // Màu ban ngày (màu hiện tại)
        : Color(0xFF295EA7); // Màu ban đêm
  }

  void _updateMap() {
    if (_webViewController != null && KeyLocation != null) {
      _webViewController!.evaluateJavascript(
        source:
            '''updateMap(${KeyLocation!.latitude}, ${KeyLocation!.longitude});''',
      );
      print(
          "Map updated to: ${KeyLocation!.latitude}, ${KeyLocation!.longitude}");
    }
  }

  Future<void> _refreshData() async {
    if (!mounted) return;

    // Get current location from PageView
    final currentLocation = _locations[_currentLocationIndex];

    // Load new data from API
    await WeatherService.fetchWeatherData(
        currentLocation['latitude'], currentLocation['longitude']);

    // Update location name if needed
    if (!currentLocation['isCurrent']) {
      await WeatherService.getLocationName(
          currentLocation['latitude'], currentLocation['longitude']);
    }

    _updateMap();
    // Update UI
    setState(() {});
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
            // Nút chatbot
            IconButton(
              icon: Icon(Icons.chat, color: Colors.white, size: 30),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => ChatbotScreen()),
                );
              },
            ),

            // Nút tìm kiếm
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
        // Phần nội dung chính
        body: AnimatedContainer(
          duration: Duration(milliseconds: 500),
          color: _getBackgroundColor(),
          child: currentData.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _buildMainContent(),
        ),
        // Chuyển indicator xuống dưới
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
          // Nút menu bên trái
          IconButton(
            icon: Row(
              children: [
                Icon(Icons.menu, color: Colors.white),
                SizedBox(
                  width: 10,
                ),
              ],
            ),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => ManageLocationsScreen()));
            },
          ),

          // Phần indicator dots ở giữa
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

          // NÚT THÊM CHATBOT Ở ĐÂY
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
      onPageChanged: (index) {
        setState(() {
          _currentLocationIndex = index;
          // Cập nhật KeyLocation và LocationName
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

          // Load weather data for this location
          WeatherService.loadWeatherData(
                  location['latitude'], location['longitude'])
              .then((_) {
            _updateMap();
            setState(() {}); // Update UI with new data
          });
        });
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

  Widget _buildLocationIndicator() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Các chỉ báo trang
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
        SizedBox(height: 8),
      ],
    );
  }

  Widget _buildCurrentWeather() {
    return Container(
      height: 180, // Chiều cao cố định cho container
      width: double.infinity, // Chiều rộng đầy đủ
      child: Stack(
        fit: StackFit.expand, // Đảm bảo Stack điền đầy Container
        children: [
          // Phần thông tin nhiệt độ
          Positioned(
            left: 16,
            top: 0,
            right:
                100, // Để lại không gian cho icon, nhưng text có thể đè lên khi cần
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${currentData['main']['temp']}\u00B0',
                  style: TextStyle(
                      fontSize: 55,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                  overflow: TextOverflow.visible, // Cho phép text tràn ra
                ),
                SizedBox(height: 10),
                Text(
                  '${currentData['weather'][0]['main']}',
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

          // Icon thời tiết - đặt phía bên phải
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

  // Implement remaining UI components similarly
  Widget _buildHourlyForecast() {
    // Implement the hourly forecast UI component
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
    // Implement the daily forecast UI component
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
            min((dailyData['list'] as List?)?.length ?? 0, 7),
            (index) {
              final dayName = FormattingService.getDayName(
                dailyData['list'][index]['dt'],
              );
              var maxTemp = double.parse(
                dailyData['list'][index]['temp']['max'].toString(),
              );
              var minTemp = double.parse(
                dailyData['list'][index]['temp']['min'].toString(),
              );
              final weatherIcon =
                  dailyData['list'][index]['weather'][0]['icon'];
              var pop = double.parse(
                dailyData['list'][index]['pop'].toString(),
              );
              int max = maxTemp.round();
              int min = minTemp.round();
              int pop1 = (pop * 100).round();

              // Implementation continues...
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
            // Day name (giảm chiều rộng để dành không gian cho nhiệt độ)
            Container(
              width: (MediaQuery.of(context).size.width - 20) / 10 * 2.5,
              child: Text(
                '$dayName',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 18),
                overflow: TextOverflow
                    .ellipsis, // Thêm overflow để cắt văn bản nếu cần
              ),
            ),

            // Pop (giữ nguyên)
            Container(
              width: (MediaQuery.of(context).size.width - 20) / 10 * 1.5,
              child: Row(
                children: [
                  SvgPicture.asset(
                    'assets/svgs/pop.svg',
                    width: 15,
                  ),
                  Text(' $pop%',
                      style: TextStyle(color: Colors.white, fontSize: 15)),
                ],
              ),
            ),

            // Weather icon
            Container(
              width: (MediaQuery.of(context).size.width - 20) /
                  10 *
                  1.5, // Giảm nhẹ chiều rộng
              child: SvgPicture.asset(
                FormattingService.getWeatherIconPath(weatherIcon),
                width: 35,
                height: 35,
              ),
            ),

            // Temperature values (tăng chiều rộng để chứa đủ giá trị độ F lớn)
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Max temperature
                  Container(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '$max\u00B0',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 19),
                      overflow:
                          TextOverflow.visible, // Cho phép hiển thị đầy đủ
                    ),
                  ),
                  SizedBox(width: 10), // Khoảng cách giữa max và min

                  // Min temperature
                  Container(
                    width: 45, // Chiều rộng cố định để chứa đủ độ F
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
                  SizedBox(width: 8), // Thêm khoảng trống bên phải
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
        crossAxisCount: 2, // 2 cột
        childAspectRatio: 0.9, // Tỷ lệ chiều rộng/chiều cao
        mainAxisSpacing: 10.0, // Khoảng cách giữa các hàng
        crossAxisSpacing: 10.0, // Khoảng cách giữa các cột
        children: [
          // Độ ẩm
          _buildDetailCard(
            icon: 'assets/svgs/humidity.svg',
            title: 'Humidity'.tr,
            value: '${currentData['main']['humidity']}%',
            subtitle: '',
            progress: currentData['main']['humidity'] / 100,
            colorStart: Colors.blue.shade100,
            colorEnd: Colors.blue.shade500,
          ),

          // Áp suất
          _buildDetailCard(
            icon: 'assets/svgs/pressure.svg',
            title: 'Pressure'.tr,
            value: '${currentData['main']['pressure']} mb',
            subtitle: '',
            showGauge: true,
            gaugeValue: currentData['main']['pressure'] /
                1050, // Chia cho giá trị max để có tỷ lệ từ 0-1
          ),

          // Gió
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

          // Tầm nhìn
          _buildDetailCard(
            icon: 'assets/svgs/visibility.svg',
            title: 'Visibility'.tr,
            value:
                '${(currentData['visibility'] / 1000).toStringAsFixed(2)} km',
            subtitle: '',
          ),

          // Sea Level
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
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Color(0xFFBBDFEA).withAlpha(38),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header với icon và tiêu đề
          Row(
            children: [
              SvgPicture.asset(
                icon,
                width: 20,
                height: 20,
                color: Colors.white,
              ),
              SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          SizedBox(
            height: 8,
          ),

          // Subtitle
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          SizedBox(
            height: 8,
          ),
          // Progress bar (nếu có)
          if (progress != null)
            Container(
              margin: EdgeInsets.only(top: 10),
              height: 6,
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

          // Gauge (cho áp suất)
          if (showGauge && gaugeValue != null)
            Container(
              margin: EdgeInsets.only(top: 10),
              height: 50,
              child: CustomPaint(
                painter: GaugePainter(gaugeValue),
                size: Size.infinite,
              ),
            ),

          // Wind Direction
          if (showWindDirection && windDegree != null)
            Container(
              margin: EdgeInsets.only(top: 5),
              height: 50,
              alignment: Alignment.center,
              child: CustomPaint(
                painter: WindDirectionPainter(windDegree, windSpeed ?? 0),
                size: Size(150, 150),
              ),
            ),
          Spacer(),
          // Giá trị
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
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
        color:
            Color(0xFFBBDFEA).withAlpha(38), // Màu xanh đậm như trong hình mẫu
      ),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tiêu đề "Radar và bản đồ"
          Text(
            'radar_and_map'.tr,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 12),

          // Container cho bản đồ với bo tròn
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

          // Nhiệt độ hiện tại
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
    // Lấy thời gian hiện tại tính bằng epoch seconds
    final int currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // Kiểm tra an toàn để tránh lỗi nếu không có dữ liệu
    final int sunriseTime = currentData['sys']?['sunrise'] ?? currentTime;
    final int sunsetTime =
        currentData['sys']?['sunset'] ?? (currentTime + 43200); // Mặc định +12h

    return Container(
      width: MediaQuery.of(context).size.width - 20,
      padding: EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color:
            Color(0xFFBBDFEA).withAlpha(38), // Màu xanh đậm như trong hình mẫu
      ),
      child: Column(
        children: [
          // Phần vẽ đường cong
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
          // Phần hiển thị thời gian bình minh/hoàng hôn
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
    // Điều chỉnh vị trí của đường cong - nâng lên cao hơn
    // Thay đổi từ size.height thành size.height * 0.5 để nâng trung tâm lên
    final Rect rect = Rect.fromLTRB(widthReduction, size.height * 0.2,
        size.width - widthReduction, size.height * 2.3);

    // Vẽ đường cong màu xám toàn bộ
    canvas.drawArc(
      rect,
      0, // Bắt đầu từ góc 0 (bên phải)
      -pi, // Đi 180 độ ngược chiều kim đồng hồ
      false,
      grayPaint,
    );

    // Tính toán phần đường cong mặt trời
    double progress;
    if (currentTime < sunriseTime) {
      progress = 0;
    } else if (currentTime > sunsetTime) {
      progress = 1;
    } else {
      progress = (currentTime - sunriseTime) / (sunsetTime - sunriseTime);
    }

    // Vẽ phần đường cong vàng
    canvas.drawArc(
      rect,
      0, // Bắt đầu từ góc 0 (bên phải)
      -pi * progress, // Đi ngược chiều kim đồng hồ theo tiến độ
      false,
      yellowPaint,
    );

    // Thay thế đoạn code vẽ chấm tròn bằng đoạn code vẽ mặt trời
    if (progress > 0 && progress < 1) {
      final double angle = -pi * progress;
      final double sunX = rect.center.dx + rect.width / 2 * cos(angle);
      final double sunY = rect.center.dy + rect.height / 2 * sin(angle);

      // Vẽ vòng tròn ngoài làm hiệu ứng phát sáng
      final Paint sunGlowPaint = Paint()
        ..color = Colors.yellow.withOpacity(0.3)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(sunX, sunY),
        12, // Kích thước lớn hơn cho hiệu ứng phát sáng
        sunGlowPaint,
      );

      // Vẽ vòng tròn chính của mặt trời
      final Paint sunPaint = Paint()
        ..color = Colors.yellow
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(sunX, sunY),
        8, // Kích thước mặt trời
        sunPaint,
      );

      // Vẽ các tia sáng xung quanh mặt trời
      final Paint rayPaint = Paint()
        ..color = Colors.yellow
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;

      const int numRays = 8; // Số lượng tia sáng
      const double rayLength = 8.0; // Độ dài của tia sáng

      for (int i = 0; i < numRays; i++) {
        double rayAngle = 2 * pi * i / numRays;
        double startX = sunX + 8 * cos(rayAngle); // Bắt đầu từ mép mặt trời
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
  final double value; // 0.0 to 1.0

  GaugePainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = min(size.width / 2, size.height);

    // Vẽ cung đo
    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), pi, pi,
        false, bgPaint);

    // Vẽ phần đã đạt được
    final valuePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), pi,
        pi * value, false, valuePaint);

    // Vẽ chấm hiển thị vị trí hiện tại
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
    final radius = min(size.width, size.height) /
        1.1; // Giảm tỷ lệ từ 2 xuống 2.5 để có nhiều không gian hơn

    // Vẽ vòng tròn đo
    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawCircle(center, radius, bgPaint);

    // Vẽ các điểm chính (N, E, S, W)
    final textStyle = TextStyle(
      color: Colors.white,
      fontSize: 16, // Tăng kích thước font
      fontWeight: FontWeight.bold, // Làm đậm hơn
    );
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    // Thêm nhãn cho các hướng
    void drawCardinalPoints() {
      // North
      textPainter.text = TextSpan(text: 'N', style: textStyle);
      textPainter.layout();
      textPainter.paint(
          canvas,
          Offset(center.dx - textPainter.width / 2,
              center.dy - radius - 20 // Thêm khoảng cách để hiển thị rõ hơn
              ));

      // East
      textPainter.text = TextSpan(text: 'E', style: textStyle);
      textPainter.layout();
      textPainter.paint(canvas,
          Offset(center.dx + radius + 8, center.dy - textPainter.height / 2));

      // South
      textPainter.text = TextSpan(text: 'S', style: textStyle);
      textPainter.layout();
      textPainter.paint(canvas,
          Offset(center.dx - textPainter.width / 2, center.dy + radius + 8));

      // West
      textPainter.text = TextSpan(text: 'W', style: textStyle);
      textPainter.layout();
      textPainter.paint(
          canvas,
          Offset(center.dx - radius - textPainter.width - 8,
              center.dy - textPainter.height / 2));
    }

    drawCardinalPoints();

    // Chuyển đổi góc từ độ sang radian và điều chỉnh để 0 độ là hướng Bắc
    final arrowAngle = (windDegree - 90) * pi / 180;

    // Tính toán vị trí của đầu mũi tên (trên đường tròn)
    final arrowPositionX = center.dx + radius * 0.85 * cos(arrowAngle);
    final arrowPositionY = center.dy + radius * 0.85 * sin(arrowAngle);

    // Vẽ đầu mũi tên to hơn và rõ ràng hơn
    final arrowheadPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Tạo một mũi tên lớn hơn
    final arrowSize = 6.0; // Tăng kích thước
    final backOffset = 12.0; // Khoảng cách phần đuôi của mũi tên

    final path = Path();

    // Điểm mũi tên (đỉnh)
    path.moveTo(arrowPositionX, arrowPositionY);

    // Điểm bên trái của mũi tên
    path.lineTo(
        arrowPositionX -
            backOffset * cos(arrowAngle) +
            arrowSize * cos(arrowAngle - pi / 2),
        arrowPositionY -
            backOffset * sin(arrowAngle) +
            arrowSize * sin(arrowAngle - pi / 2));

    // Điểm giữa phía sau (lõm vào)
    path.lineTo(arrowPositionX - backOffset * 0.7 * cos(arrowAngle),
        arrowPositionY - backOffset * 0.7 * sin(arrowAngle));

    // Điểm bên phải của mũi tên
    path.lineTo(
        arrowPositionX -
            backOffset * cos(arrowAngle) +
            arrowSize * cos(arrowAngle + pi / 2),
        arrowPositionY -
            backOffset * sin(arrowAngle) +
            arrowSize * sin(arrowAngle + pi / 2));

    // Đóng path để tạo hình mũi tên hoàn chỉnh
    path.close();

    // Vẽ mũi tên
    canvas.drawPath(path, arrowheadPaint);

    // Vẽ hình tròn ở giữa cho tốc độ gió
    final centerCirclePaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius * 0.8, centerCirclePaint);

    // Vẽ tốc độ gió ở giữa
    textPainter.text = TextSpan(
      text: '${windSpeed.toStringAsFixed(1)}',
      style: TextStyle(
        color: Colors.white,
        fontSize: 24, // Tăng kích thước
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

    // Vẽ "km/h" bên dưới
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
        center.dy + 10, // Đặt xuống dưới một chút
      ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
