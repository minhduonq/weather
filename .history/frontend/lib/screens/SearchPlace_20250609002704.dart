import 'dart:convert';
import 'package:frontend/screens/weather_stogare.dart';

import '../services/constants.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/helpTrans.dart';
import 'package:get/get.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/database.dart';
import 'package:permission_handler/permission_handler.dart';

class SearchPlace extends StatefulWidget {
  const SearchPlace({Key? key}) : super(key: key);

  @override
  _SearchPlaceState createState() => _SearchPlaceState();
}

class _SearchPlaceState extends State<SearchPlace>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  final DatabaseHelper dbHelper = DatabaseHelper();
  List<String> _places = [];
  var data;
  bool _isListening = false;
  late stt.SpeechToText _speech;
  late AnimationController _animationController;
  late Animation<double> _animation;
  // Biến theo dõi khi nào đang xử lý kết quả
  bool _isProcessingResult = false;
  // Biến kiểm soát hiệu ứng hiển thị/ẩn
  bool _showMicAnimation = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _speech = stt.SpeechToText();
    _checkPermissionAndInitialize();

    // Cập nhật animation controller để tạo hiệu ứng "thở"
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Thay đổi range animation để tạo hiệu ứng phóng đại nhẹ nhàng hơn
    _animation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Kiểm tra lại quyền khi ứng dụng được phục hồi
      _checkPermissionAndInitialize();
    }
  }

  Future<void> _checkPermissionAndInitialize() async {
    // Kiểm tra quyền microphone
    var status = await Permission.microphone.status;

    if (status.isDenied) {
      // Yêu cầu quyền nếu chưa được cấp
      status = await Permission.microphone.request();
    }

    if (status.isGranted) {
      await _initializeSpeech();
    } else if (status.isPermanentlyDenied) {
      // Hiển thị dialog khi ứng dụng đã sẵn sàng
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showPermissionDeniedDialog();
        }
      });
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Cần quyền truy cập Microphone'),
          content: Text(
              'Để sử dụng tính năng tìm kiếm bằng giọng nói, bạn cần cấp quyền truy cập microphone trong cài đặt.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Đóng'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
              child: Text('Mở Cài đặt'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _initializeSpeech() async {
    try {
      bool available = await _speech.initialize(
        onError: (error) {
          print('Speech recognition error: $error');
          _handleSpeechStop(); // Tự động dừng khi có lỗi
        },
        onStatus: (status) {
          print('Speech recognition status: $status');
          // Kiểm tra trạng thái để tự động dừng
          if (status == "done" || status == "notListening") {
            _handleSpeechStop();
          }
        },
      );

      if (!available) {
        print('Speech recognition not available');
      }
    } catch (e) {
      print('Error initializing speech recognition: $e');
    }
  }

  void _handleSpeechStop() {
    if (!mounted || !_isListening) return;

    setState(() {
      _isListening = false;
      // Đặt cờ đang xử lý
      _isProcessingResult = true;
    });

    // Dừng animation nhưng vẫn giữ hiển thị
    _animationController.stop();

    // Đợi một chút để hiển thị "Đang xử lý..." trước khi ẩn hoàn toàn
    Future.delayed(Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _showMicAnimation = false;
          _isProcessingResult = false;
        });
      }
    });
  }

  void _onSearchChanged(String query) {
    if (query.isNotEmpty) {
      _searchPlaces(query);
    } else {
      setState(() {
        _places.clear();
      });
    }
  }

  Future<void> _searchPlaces(String query) async {
    query = query.replaceAll(' ', '+');
    String apiKey = 't8j30ZcKTjahgwuPbHRDWmqx1JXdaBg4Lz7a82tixWs';
    String coordinates = '21,104';

    String apiUrl =
        'https://discover.search.hereapi.com/v1/discover?at=$coordinates&q=$query&apiKey=$apiKey';

    var response = await http.get(Uri.parse(apiUrl));

    if (response.statusCode == 200) {
      data = json.decode(utf8.decode(response.bodyBytes));
      List<dynamic> items = data['items'];

      _places.clear();

      for (var item in items) {
        if (item['resultType'] == 'locality' ||
            item['resultType'] == 'administrativeArea') {
          _places.add(item['address']['label']);
        }
      }

      setState(() {});
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể tìm kiếm địa điểm.')),
      );
    }
  }

  Future<void> _selectPlace(String selectedPlace, int index) async {
    double lat = data['items'][index]['position']['lat'];
    double lon = data['items'][index]['position']['lng'];

    List<Map<String, dynamic>> existingLocations =
        await dbHelper.getAllLocations();
    bool alreadyExists = existingLocations
        .any((place) => place['latitude'] == lat && place['longitude'] == lon);

    if (!mounted) return;

    if (alreadyExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$selectedPlace đã tồn tại trong danh sách.'),
        ),
      );
      return;
    }

    await dbHelper.insertLocation({
      'name': OfficialName(selectedPlace),
      'latitude': lat,
      'longitude': lon,
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$selectedPlace đã được lưu vào danh sách.'),
      ),
    );

    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => WeatherStorageScreen()),
    );
  }

  void _listen() async {
    // Kiểm tra quyền truy cập
    var status = await Permission.microphone.status;

    if (!status.isGranted) {
      status = await Permission.microphone.request();

      if (!status.isGranted) {
        if (status.isPermanentlyDenied) {
          _showPermissionDeniedDialog();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  'Cần quyền truy cập microphone để sử dụng tính năng này')));
        }
        return;
      }
    }

    if (!_isListening) {
      // Kiểm tra xem speech recognition đã được khởi tạo chưa
      bool available = await _speech.initialize(
        onError: (error) {
          print('Speech recognition error: $error');
          _handleSpeechStop();
        },
        onStatus: (status) {
          print('Speech recognition status: $status');
          if (status == "done" || status == "notListening") {
            _handleSpeechStop();
          }
        },
      );

      if (!available) {
        print('Speech recognition not available');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Nhận dạng giọng nói không khả dụng trên thiết bị này')),
        );
        return;
      }

      try {
        setState(() {
          _isListening = true;
          _showMicAnimation = true; // Hiển thị hiệu ứng
        });
        _animationController.repeat(reverse: true);

        await _speech.listen(
          onResult: (result) {
            if (result.finalResult) {
              _handleSpeechResult(result.recognizedWords);
            }
          },
          listenFor: Duration(seconds: 30),
          pauseFor: Duration(seconds: 3),
          partialResults: true,
          localeId: 'vi-VN',
          cancelOnError: true,
          listenMode: stt.ListenMode.confirmation,
        );
      } catch (e) {
        print('Error starting speech recognition: $e');
        _stopListening();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể kích hoạt nhận dạng giọng nói')),
        );
      }
    } else {
      _stopListening();
    }
  }

  void _stopListening() {
    _speech.stop();
    setState(() {
      _isListening = false;
      // Đặt cờ hiển thị hiệu ứng xử lý
      _isProcessingResult = true;
    });

    _animationController.stop();

    // Đợi một chút để hiển thị trạng thái "Đang xử lý..." rồi ẩn đi
    Future.delayed(Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _showMicAnimation = false;
          _isProcessingResult = false;
        });
      }
    });
  }

  void _handleSpeechResult(String recognizedWords) {
    if (recognizedWords.isNotEmpty) {
      // Đặt kết quả vào ô tìm kiếm
      _searchController.text = recognizedWords;
      _onSearchChanged(recognizedWords);

      // Cần đợi chút để xử lý trước khi ẩn overlay
      Future.delayed(Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _showMicAnimation = false;
            _isProcessingResult = false;
          });
        }
      });
    } else {
      // Nếu không có từ nào được nhận dạng, ẩn overlay ngay lập tức
      setState(() {
        _showMicAnimation = false;
        _isProcessingResult = false;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _speech.stop();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade100,
        title: Text('search'.tr, style: TextStyle(color: Colors.black)),
        elevation: 0,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      margin: EdgeInsets.only(
                          top: 20, bottom: 10, left: 16, right: 16),
                      padding: EdgeInsets.symmetric(horizontal: 15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(50),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            spreadRadius: 1,
                            blurRadius: 3,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'type_place'.tr,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.only(left: 20, top: 10),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_searchController.text.isNotEmpty)
                                IconButton(
                                  icon: Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    _onSearchChanged('');
                                    setState(() {
                                      _places.clear();
                                    });
                                  },
                                ),
                              InkWell(
                                onTap: _listen,
                                child: Container(
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _isListening
                                        ? Colors.red.withOpacity(0.1)
                                        : Colors.transparent,
                                  ),
                                  child: Icon(
                                    _isListening ? Icons.mic : Icons.mic_none,
                                    color: _isListening
                                        ? Colors.red
                                        : Colors.grey.shade700,
                                  ),
                                ),
                                borderRadius: BorderRadius.circular(25),
                                splashColor: Colors.red.withOpacity(0.3),
                              ),
                              SizedBox(width: 8),
                            ],
                          ),
                        ),
                        onChanged: (value) {
                          _onSearchChanged(value);
                          setState(() {});
                        },
                      ),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: _places.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search,
                              size: 80,
                              color: Colors.grey.shade400,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Search for places'.tr,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _places.length,
                        itemBuilder: (context, index) {
                          return Card(
                            elevation: 0,
                            margin: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            color: Colors.white,
                            child: ListTile(
                              title: Text(
                                _places[index],
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              leading: Icon(
                                Icons.location_on,
                                color: Colors.blue,
                              ),
                              onTap: () => _selectPlace(_places[index], index),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
          // Cải thiện hiệu ứng khi đang lắng nghe - thay đổi từ _isListening sang _showMicAnimation
          if (_showMicAnimation)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.5),
                child: AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Transform.scale(
                            scale: _animation.value,
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.8),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red.withOpacity(0.5),
                                    spreadRadius: 5,
                                    blurRadius: 15,
                                    offset: Offset(0, 0),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.mic,
                                  color: Colors.white,
                                  size: 60,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 24),
                          Text(
                            // Thay đổi text dựa trên trạng thái xử lý
                            _isProcessingResult
                                ? "Processing...".tr
                                : "Listening...".tr,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _stopListening,
                            child: Text("Cancel".tr),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.red,
                              padding: EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
