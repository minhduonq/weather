
import 'dart:math';

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

import 'LocationManage.dart';
import 'SearchPlace.dart';
import 'Setting.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
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

  Future<void> _initializeApp() async {
    if (KeyLocation != null) {
      // If we already have a location (from drawer selection), load its data
      await WeatherService.loadWeatherData(KeyLocation!.latitude, KeyLocation!.longitude);
      await WeatherService.getLocationName(KeyLocation!.latitude, KeyLocation!.longitude);
    } else {
      // Otherwise request location permission
      await _requestLocationAndLoadData();
    }
    // Update UI after data is loaded
    setState(() {});
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
      await WeatherService.loadWeatherData(KeyLocation!.latitude, KeyLocation!.longitude);
      await WeatherService.getLocationName(KeyLocation!.latitude, KeyLocation!.longitude);
      print(KeyLocation!.latitude);
      print(KeyLocation!.longitude);

      // Update UI
      setState(() {});
    }
  }

  void _updateMap() {
    if (_webViewController != null && KeyLocation != null) {
      _webViewController!.evaluateJavascript(
        source: '''updateMap(${KeyLocation!.latitude}, ${KeyLocation!.longitude});''',
      );
      print("Map updated to: ${KeyLocation!.latitude}, ${KeyLocation!.longitude}");
    }
  }

  Future<void> _refreshData() async {
    if (!mounted) return;

    // If at a specific location
    if (KeyLocation != null) {
      // Load new data from API
      await WeatherService.fetchWeatherData(KeyLocation!.latitude, KeyLocation!.longitude);

      // Update location name if needed
      if (LocationName != InitialName) {
        await WeatherService.getLocationName(KeyLocation!.latitude, KeyLocation!.longitude);
      }
      _updateMap();
      // Update UI
      setState(() {});
    } else {
      // If location not yet determined, get current location
      await _getCurrentLocation();
      _updateMap();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: Color(0xFF66CEED),
        appBarTheme: AppBarTheme(
          backgroundColor: Color(0xFF66CEED),
          elevation: 0,
        ),
      ),
      home: Scaffold(
        appBar: AppBar(
          title: Text('$LocationName', style: TextStyle(color: Colors.white)),
        ),
        backgroundColor: Color(0xFF66CEED),
        drawer: _buildDrawer(),
        body: currentData.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _buildMainContent(),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: Colors.grey[200],
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drawer header with AI and settings buttons
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: () {},
                    icon: Image.asset('assets/svgs/AI.png', width: 60, height: 60),
                    iconSize: 45,
                  ),
                  SizedBox(width: 16),
                  IconButton(
                    onPressed: () {
                      Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => Setting())
                      );
                    },
                    icon: Image.asset('assets/svgs/setting.png', width: 35, height: 35),
                    iconSize: 25,
                  ),
                ],
              ),
            ),

            // Favorite places section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                '★ Favourite Places',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),

            // Initial location
            ListTile(
                contentPadding: EdgeInsets.only(left: 52.0),
                title: Text('$InitialName'),
                onTap: () {
                  setState(() {
                    LocationName = InitialName;
                    KeyLocation = null;
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => HomePage()
                    ));
                  });
                }
            ),

            // Other places
            ListTile(
                leading: Icon(Icons.location_searching_sharp),
                title: Text('Other Places',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                ),
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => SearchPlace()
                  ));
                }
            ),

            // List of saved locations
            _buildSavedLocationsList(),

            // Place management
            ListTile(
              leading: Icon(Icons.notes_outlined),
              title: Text('Place Management',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
              ),
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => ManageLocationsScreen()
                ));
              },
            ),

            Divider(color: Colors.black54),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedLocationsList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: DatabaseHelper().getAllLocations(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(strokeWidth: 2));
        } else if (snapshot.hasError) {
          return ListTile(
            contentPadding: EdgeInsets.only(left: 52.0),
            title: Text("Error loading locations"),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return ListTile(
            contentPadding: EdgeInsets.only(left: 52.0),
            title: Text("No saved locations"),
          );
        } else {
          return Column(
            children: snapshot.data!.map((location) {
              // Skip current location if it matches InitialName
              if (location['name'] == InitialName) {
                return SizedBox.shrink();
              }

              return ListTile(
                contentPadding: EdgeInsets.only(left: 52.0),
                title: Text(location['name']),
                onTap: () {
                  setState(() {
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

                  // Load data for this location before navigating
                  WeatherService.loadWeatherData(
                      location['latitude'],
                      location['longitude']
                  ).then((_) {
                    _updateMap();
                    setState(() {}); // Update UI with new data
                    Navigator.pop(context); // Close drawer
                  });
                },
              );
            }).toList(),
          );
        }
      },
    );
  }

  Widget _buildMainContent() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      color: Colors.white,
      backgroundColor: Colors.lightBlueAccent,
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height -
                AppBar().preferredSize.height - MediaQuery.of(context).padding.top,
          ),
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
                _buildWeatherDetails(),
                SizedBox(height: 10),
                _buildWeatherMap(),
                SizedBox(height: 10),
                _buildSunriseSunset(),
                SizedBox(height: 10),
                _buildAdditionalInfo(),
                SizedBox(height: 10),
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Individual UI components - these can be implemented as needed following the pattern above
  Widget _buildCurrentWeather() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ListTile(
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${currentData['main']['temp']}\u00B0',
                  style: TextStyle(fontSize: 55, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                SizedBox(height: 10),
                Text(
                  '${currentData['weather'][0]['main']}',
                  style: TextStyle(fontSize: 20, color: Colors.white),
                ),
                SizedBox(height: 30),
                Text('${currentData['main']['temp_min']}\u00B0 / ${currentData['main']['temp_max']}\u00B0',
                    style: TextStyle(color: Colors.white)),
                Text('Feel like ${currentData['main']['feels_like']}\u00B0',
                    style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 0),
        SvgPicture.asset(
            FormattingService.getWeatherIconPath(currentData['weather'][0]['icon']),
            height: 150,
            width: 150
        ),
      ],
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
                ? FormattingService.capitalize(currentData['weather'][0]['description'])
                : '',
            style: TextStyle(color: Colors.white)
        ),
        subtitle: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(
              (hourlyData['list']?.length ?? 0),
                  (index) {
                double popValue = (hourlyData['list'][index]['pop'] ?? 0).toDouble();
                int pop1 = (popValue * 100).round();
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      Text(
                          '${FormattingService.formatEpochTimeToTime(
                              hourlyData['list'][index]['dt'],
                              currentData['timezone']
                          )}',
                          style: TextStyle(color: Colors.white)
                      ),
                      SvgPicture.asset(
                        FormattingService.getWeatherIconPath(
                          hourlyData['list'][index]['weather'][0]['icon'],
                        ),
                        width: 50,
                        height: 50,
                      ),
                      Text(
                          '${hourlyData['list'][index]['main']['temp']}\u00B0',
                          style: TextStyle(color: Colors.white)
                      ),
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
        title: Text('Daily Forecast', style: TextStyle(color: Colors.white)),
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
              final weatherIcon = dailyData['list'][index]['weather'][0]['icon'];
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

  Widget _buildDailyRow(String dayName, int pop, String weatherIcon, int max, int min) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: (MediaQuery.of(context).size.width - 20) / 10 * 2.8,
              child: Text(
                '$dayName',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
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
                  Text(' $pop%', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
            Container(
              width: (MediaQuery.of(context).size.width - 20) / 10 * 1.8,
              child: SvgPicture.asset(
                FormattingService.getWeatherIconPath(weatherIcon),
                width: 35,
                height: 35,
              ),
            ),
            Container(
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    width: (MediaQuery.of(context).size.width - 20) / 10 * 1.2,
                    child: Text(
                      '$max\u00B0',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    width: (MediaQuery.of(context).size.width - 20) / 10 * 1.2,
                    child: Text(
                      '$min\u00B0',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white
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
  }

  Widget _buildWeatherDetails() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 10,
      ),
      child: Column(
        children: [
          // First row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDetailBox('Humidity', '${currentData['main']['humidity']}%'),
              _buildDetailBox('Sea Level', '${currentData['main']['sea_level']}'),
            ],
          ),
          SizedBox(height: 10),
          // Second row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDetailBox('Cloud', '${currentData['clouds']['all']}%'),
              _buildDetailBox('Wind Speed', '${currentData['wind']['speed']}km/h'),
            ],
          ),
        ],
      ),
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
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
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

  Widget _buildWeatherMap() {
    return Container(
      width: MediaQuery.of(context).size.width - 20,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Color(0xFFBBDFEA).withAlpha(38), // Màu xanh đậm như trong hình mẫu
      ),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tiêu đề "Radar và bản đồ"
          Text(
            'Radar và bản đồ',
            style: TextStyle(
              fontSize: 24,
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
            'Nhiệt độ hiện tại là ${currentData['main']['temp'].toStringAsFixed(0)}°',
            style: TextStyle(
              fontSize: 22,
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
    final int sunsetTime = currentData['sys']?['sunset'] ?? (currentTime + 43200); // Mặc định +12h

    return Container(
      width: MediaQuery.of(context).size.width - 20,
      padding: EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Color(0xFFBBDFEA).withAlpha(38),  // Màu xanh đậm như trong hình mẫu
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
                  currentTime: currentTime
              ),
            ),
          ),
          SizedBox(height: 10),
          // Phần hiển thị thời gian bình minh/hoàng hôn
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSunTimeBox(
                'Bình minh',
                FormattingService.formatEpochTimeToTime(
                    currentData['sys']['sunrise'],
                    currentData['timezone']
                ),
              ),
              _buildSunTimeBox(
                'Hoàng hôn',
                FormattingService.formatEpochTimeToTime(
                    currentData['sys']['sunset'],
                    currentData['timezone']
                ),
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
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w400, color: Colors.white),
        ),
        SizedBox(height: 8),
        Text(
          time,
          style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ],
    );
  }


  Widget _buildAdditionalInfo() {
    return Container(
      width: MediaQuery.of(context).size.width - 20,
      padding: const EdgeInsets.only(top: 10, bottom: 10, left: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Color(0xFFBBDFEA).withAlpha(38),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SvgPicture.asset('assets/svgs/pressure.svg', width: 15),
              Text(' Pressure: ${currentData['visibility']}nPa',
                  style: TextStyle(color: Colors.white)),
            ],
          ),
          Row(
            children: [
              SvgPicture.asset('assets/svgs/visibility.svg', width: 15),
              Text(' Visibility: ${currentData['visibility']}m',
                  style: TextStyle(color: Colors.white)),
            ],
          ),
        ],
      ),
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
            const Text(' OpenWeatherMap',
                style: TextStyle(fontSize: 10, color: Colors.black54))
          ],
        ),
        Row(
          children: [
            Text(
              'Updated at ${FormattingService.formatEpochTimeToTime(
                  currentData['dt'], currentData['timezone'])}   ',
              style: TextStyle(fontSize: 10),
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
    final Rect rect = Rect.fromLTRB(widthReduction, size.height * 0.2, size.width - widthReduction, size.height * 2.3);

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

