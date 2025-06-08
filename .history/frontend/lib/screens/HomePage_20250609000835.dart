import 'package:flutter/material.dart';
import 'package:frontend/provider/location_notifier.dart';
import 'package:frontend/screens/weather_stogare.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
import 'dart:math';
import '../services/helpTrans.dart';
import 'package:get/get.dart';

class HomePage extends StatefulWidget {
  final String? highlightLocationName;

  HomePage({super.key, this.highlightLocationName});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  PageController _pageController = PageController();
  int _currentLocationIndex = 0;
  bool _isLoading = true;
  bool _isInitialized = false;
  InAppWebViewController? _webViewController;

  Map<String, dynamic> get currentData => WeatherService.currentData;
  Map<String, dynamic> get hourlyData => WeatherService.hourlyData;
  Map<String, dynamic> get dailyData => WeatherService.dailyData;

  @override
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp().then((_) {
      // Only update the widget after initialization
      if (WeatherService.currentData.isNotEmpty) {
        WeatherWidgetService.updateWeatherWidget();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    if (_isInitialized) return;
    _isInitialized = true;

    try {
      setState(() {
        _isLoading = true;
      });

      final locationNotifier =
          Provider.of<LocationNotifier>(context, listen: false);

      // Load danh sách vị trí
      await locationNotifier.refreshLocations();

      // Set initial location index based on highlightLocationName if provided
      if (widget.highlightLocationName != null) {
        _setHighlightedLocationIndex();
      } else {
        if (KeyLocation == null) {
          // Request current location instead of using a default
          await _requestLocationAndLoadData();
        } else {
          await WeatherService.loadWeatherData(
              KeyLocation!.latitude, KeyLocation!.longitude);
          await WeatherService.getLocationName(
              KeyLocation!.latitude, KeyLocation!.longitude);
          _setCurrentLocationIndex();
        }
      }

      // Only use default location as a last resort if everything else fails
      if (KeyLocation == null && mounted) {
        print(
            "Không thể lấy vị trí hiện tại, hiển thị thông báo cho người dùng");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Không thể lấy vị trí hiện tại. Vui lòng kiểm tra quyền truy cập vị trí.'),
            action: SnackBarAction(
              label: 'Thử lại',
              onPressed: _requestLocationAndLoadData,
            ),
          ),
        );
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print("Lỗi khi khởi tạo ứng dụng: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _setHighlightedLocationIndex() {
    final locations =
        Provider.of<LocationNotifier>(context, listen: false).locations;
    if (locations.isEmpty) {
      _currentLocationIndex = 0;
      return;
    }

    // Find the index of the highlighted location
    int index = locations.indexWhere(
        (location) => location['name'] == widget.highlightLocationName);
    if (index >= 0) {
      _currentLocationIndex = index;
      final location = locations[index];
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
      WeatherService.loadWeatherData(
              location['latitude'], location['longitude'])
          .then((_) {
        _updateMap();
        setState(() {});
      });
      if (_pageController.hasClients) {
        _pageController.jumpToPage(index);
      }
    } else {
      // Fallback to default if highlighted location not found
      _setCurrentLocationIndex();
    }
  }

  void _setCurrentLocationIndex() {
    final locations =
        Provider.of<LocationNotifier>(context, listen: false).locations;
    if (locations.isEmpty) {
      _currentLocationIndex = 0;
      KeyLocation = null;
      LocationName = null;
      KeyLocation = Position(
        latitude: 21.0285,
        longitude: 105.8542,
        timestamp: DateTime.now(),
        accuracy: 0.0,
        altitude: 0.0,
        heading: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
        altitudeAccuracy: 0.0,
        headingAccuracy: 0.0,
      );
      WeatherService.loadWeatherData(
              KeyLocation!.latitude, KeyLocation!.longitude)
          .then((_) {
        WeatherService.getLocationName(
                KeyLocation!.latitude, KeyLocation!.longitude)
            .then((_) {
          setState(() {});
        });
      });
      return;
    }

    for (int i = 0; i < locations.length; i++) {
      final location = locations[i];
      if ((location['isCurrent'] == true && LocationName == InitialName) ||
          (location['name'] == LocationName &&
              location['latitude'] == KeyLocation?.latitude &&
              location['longitude'] == KeyLocation?.longitude)) {
        _currentLocationIndex = i;
        if (_pageController.hasClients) {
          _pageController.jumpToPage(i);
        }
        return;
      }
    }

    _currentLocationIndex = 0;
    final location = locations[0];
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
    WeatherService.loadWeatherData(location['latitude'], location['longitude'])
        .then((_) {
      setState(() {});
    });
  }

  Future<void> _requestLocationAndLoadData() async {
    bool hasPermission = await LocationService.requestLocationPermission();
    if (hasPermission) {
      try {
        // Show loading indicator
        setState(() {
          _isLoading = true;
        });

        // Get current location
        Position? position = await LocationService.getCurrentLocation();

        // Only proceed if position is not null
        if (position != null) {
          KeyLocation = position;

          // Load weather data
          await WeatherService.loadWeatherData(
              position.latitude, position.longitude);

          // Get location name
          await WeatherService.getLocationName(
              position.latitude, position.longitude);

          // Update database and refresh locations
          final locationNotifier =
              Provider.of<LocationNotifier>(context, listen: false);
          await locationNotifier.setCurrentPosition(
              position, LocationName ?? 'Current Location');

          // Update widget
          await WeatherWidgetService.updateWeatherWidget();
        } else {
          // Show dialog to user about location issue
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Không thể lấy vị trí hiện tại. Vui lòng kiểm tra quyền truy cập vị trí.'),
                action: SnackBarAction(
                  label: 'Thử lại',
                  onPressed: () => _requestLocationAndLoadData(),
                ),
              ),
            );
          }
        }
      } catch (e) {
        print("Error getting location: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Lỗi khi lấy vị trí: $e")),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } else {
      // Show permission request dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text("Quyền truy cập vị trí"),
            content: Text(
                "Ứng dụng cần quyền truy cập vị trí để hiển thị thời tiết chính xác cho vị trí của bạn."),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Geolocator.openAppSettings();
                },
                child: Text("Cài đặt"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Đóng"),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    Position? position = await LocationService.getCurrentLocation();
    if (position == null) {
      print("Không lấy được vị trí thực, sử dụng vị trí mặc định.");
      position = Position(
        latitude: 21.0285,
        longitude: 105.8542,
        timestamp: DateTime.now(),
        accuracy: 0.0,
        altitude: 0.0,
        heading: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
        altitudeAccuracy: 0.0,
        headingAccuracy: 0.0,
      );
    }

    if (position != null) {
      setState(() {
        currentPosition = position;
      });
      if (KeyLocation == null) {
        KeyLocation = position;
      }
      await WeatherService.loadWeatherData(
          KeyLocation!.latitude, KeyLocation!.longitude);
      await WeatherService.getLocationName(
          KeyLocation!.latitude, KeyLocation!.longitude);
      Provider.of<LocationNotifier>(context, listen: false)
          .setCurrentPosition(KeyLocation!, LocationName ?? 'Hà Nội');
      print("Vị trí: ${KeyLocation!.latitude}, ${KeyLocation!.longitude}");
      setState(() {
        _isLoading = false;
      });
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
      print(
          "Map updated to: ${KeyLocation!.latitude}, ${KeyLocation!.longitude}");
    }
  }

  Future<void> _refreshData() async {
    if (!mounted) return;
    final locations =
        Provider.of<LocationNotifier>(context, listen: false).locations;
    if (locations.isEmpty) return;

    final currentLocation = locations[_currentLocationIndex];
    try {
      // Ensure weather data is fetched
      await WeatherService.fetchWeatherData(
          currentLocation['latitude'], currentLocation['longitude']);

      if (!currentLocation['isCurrent']) {
        await WeatherService.getLocationName(
            currentLocation['latitude'], currentLocation['longitude']);
      }

      // Only update the widget if we have weather data
      if (WeatherService.currentData.isNotEmpty &&
          WeatherService.currentData['weather'] != null) {
        await WeatherWidgetService.updateWeatherWidget();
      }

      _updateMap();
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print("Error refreshing data: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LocationNotifier>(
      builder: (context, locationNotifier, child) {
        final locations = locationNotifier.locations;
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
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold),
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.chat, color: Colors.white, size: 30),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => Chatbot()),
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
              child: _isLoading || currentData.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _buildMainContent(locations),
            ),
            bottomNavigationBar: Container(
              color: _getBackgroundColor(),
              child: _buildLocationNavigator(locations),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLocationNavigator(List<Map<String, dynamic>> locations) {
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
                MaterialPageRoute(builder: (context) => WeatherStorageScreen()),
              );
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(locations.length, (index) {
              bool isActive = index == _currentLocationIndex;
              bool isHighlighted =
                  locations[index]['name'] == widget.highlightLocationName;
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
                    color: isHighlighted
                        ? Colors.green // Highlight color for selected location
                        : isActive
                            ? Colors.white
                            : Colors.white.withOpacity(0.5),
                  ),
                ),
              );
            }),
          ),
          IconButton(
            icon: Icon(Icons.settings, color: Colors.white),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => Setting()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(List<Map<String, dynamic>> locations) {
    if (locations.isEmpty) {
      return const Center(child: Text('Chưa có vị trí nào. Nhấn + để thêm.'));
    }

    return PageView.builder(
      controller: _pageController,
      itemCount: locations.length,
      onPageChanged: (index) {
        setState(() {
          _currentLocationIndex = index;
          final location = locations[index];
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
          WeatherService.loadWeatherData(
                  location['latitude'], location['longitude'])
              .then((_) {
            _updateMap();
            setState(() {});
          });
        });
      },
      itemBuilder: (context, index) {
        final isHighlighted =
            locations[index]['name'] == widget.highlightLocationName;
        return RefreshIndicator(
          onRefresh: _refreshData,
          color: Colors.white,
          backgroundColor: Colors.lightBlueAccent,
          child: SingleChildScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            child: Container(
              decoration: BoxDecoration(
                border: isHighlighted
                    ? Border.all(
                        color: Colors.green, width: 2) // Visual highlight
                    : null,
              ),
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

  // ... Rest of the methods (_buildCurrentWeather, _buildHourlyForecast, etc.) remain unchanged ...

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
              width: (MediaQuery.of(context).size.width - 20) / 10 * 1.8,
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
              width: (MediaQuery.of(context).size.width - 20) / 10 * 1.2,
              child: SvgPicture.asset(
                FormattingService.getWeatherIconPath(weatherIcon),
                width: 30,
                height: 30,
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
            value: '${currentData['main']['sea_level'] ?? 0} hPa',
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                icon,
                width: 20,
                height: 20,
                color: Colors.white,
              ),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          if (subtitle.isNotEmpty)
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          SizedBox(height: 8),
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
          if (showGauge && gaugeValue != null)
            Container(
              margin: EdgeInsets.only(top: 10),
              height: 50,
              child: CustomPaint(
                painter: GaugePainter(gaugeValue),
                size: Size.infinite,
              ),
            ),
          if (showWindDirection && windDegree != null)
            Container(
              margin: EdgeInsets.only(top: 25),
              height: 50,
              alignment: Alignment.center,
              child: CustomPaint(
                painter: WindDirectionPainter(windDegree, windSpeed ?? 0),
                size: Size(150, 150),
              ),
            ),
          Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
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
            'Radar and Map',
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
                'Sunrise',
                FormattingService.formatEpochTimeToTime(
                    currentData['sys']['sunrise'], currentData['timezone']),
              ),
              _buildSunTimeBox(
                'Sunset',
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
                style: TextStyle(fontSize: 10, color: Colors.white)),
          ],
        ),
        Row(
          children: [
            Text(
              'Updated at ${FormattingService.formatEpochTimeToTime(currentData['dt'], currentData['timezone'])}   ',
              style: TextStyle(fontSize: 10, color: Colors.white),
            ),
          ],
        ),
      ],
    );
  }
}

// ... CustomPainter classes (SunArcPainter, GaugePainter, WindDirectionPainter) remain unchanged ...

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

    // Tính toán phần đường cong mặt trời
    double progress;
    if (currentTime < sunriseTime) {
      progress = 0;
    } else if (currentTime > sunsetTime) {
      progress = 1;
    } else {
      progress = (currentTime - sunriseTime) / (sunsetTime - sunriseTime);
    }

    // Vẽ phần đường cong màu vàng đã đi qua trước
    canvas.drawArc(
      rect,
      pi, // Bắt đầu từ bên trái
      pi * progress, // Theo tiến độ
      false,
      yellowPaint,
    );

    // Vẽ phần đường cong màu xám còn lại
    canvas.drawArc(
      rect,
      pi + pi * progress,
      pi * (1 - progress),
      false,
      grayPaint,
    );

    // Vẽ mặt trời tại vị trí tương ứng
    if (progress > 0 && progress < 1) {
      final double angle =
          pi * progress + pi; // Góc tính từ pi (trái) + progress

      final double sunX = rect.center.dx + rect.width / 2 * cos(angle);
      final double sunY = rect.center.dy + rect.height / 2 * sin(angle);

      // Hiệu ứng phát sáng
      final Paint sunGlowPaint = Paint()
        ..color = Colors.yellow.withOpacity(0.3)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(sunX, sunY),
        12,
        sunGlowPaint,
      );

      // Mặt trời
      final Paint sunPaint = Paint()
        ..color = Colors.yellow
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(sunX, sunY),
        8,
        sunPaint,
      );

      // Các tia sáng
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
