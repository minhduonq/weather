import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../services/constants.dart';
import '../services/database.dart'; // 👈 Thêm dòng này
import 'LocationManage.dart';

class SearchPlace extends StatefulWidget {
  @override
  _SearchPlaceState createState() => _SearchPlaceState();
}

class _SearchPlaceState extends State<SearchPlace> {
  final TextEditingController _searchController = TextEditingController();
  final DatabaseHelper dbHelper = DatabaseHelper(); // 👈 SQLite helper
  List<String> _places = [];
  var data;
  bool _isListening = false;
  late stt.SpeechToText _speech;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
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
      print('Failed to fetch data: ${response.statusCode}');
    }
  }

  Future<void> _selectPlace(String selectedPlace, int index) async {
    double lat = data['items'][index]['position']['lat'];
    double lon = data['items'][index]['position']['lng'];

    // Kiểm tra xem địa điểm đã tồn tại trong SQLite chưa
    List<Map<String, dynamic>> existingLocations =
        await dbHelper.getAllLocations();
    bool alreadyExists = existingLocations.any((place) =>
        place['latitude'] == lat && place['longitude'] == lon);

    if (alreadyExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$selectedPlace đã tồn tại trong danh sách.'),
        ),
      );
      return;
    }

    // Thêm địa điểm mới vào SQLite
    await dbHelper.insertLocation({
      'name': OfficialName(selectedPlace),
      'latitude': lat,
      'longitude': lon,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$selectedPlace đã được lưu vào danh sách.'),
      ),
    );

    // Điều hướng nếu cần:
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => LocationManage()),
    );
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) {
            _searchController.text = val.recognizedWords;
            _onSearchChanged(val.recognizedWords);
          },
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đang lấy vị trí hiện tại...')),
      );

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Dịch vụ định vị đang tắt.')),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Quyền truy cập vị trí bị từ chối.')),
        );
        return;
      }

      Position position =
          await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      double lat = position.latitude;
      double lon = position.longitude;
      String coordinates = '$lat,$lon';
      String query = 'location';
      String apiKey = 't8j30ZcKTjahgwuPbHRDWmqx1JXdaBg4Lz7a82tixWs';
      String apiUrl =
          'https://discover.search.hereapi.com/v1/discover?at=$coordinates&q=$query&apiKey=$apiKey';

      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        List<dynamic> items = data['items'];

        _places.clear();
        for (var item in items) {
          if (item['resultType'] == 'locality' ||
              item['resultType'] == 'administrativeArea') {
            _places.add(item['address']['label']);
          }
        }

        if (_places.isEmpty) {
          _places.add('Không tìm thấy địa điểm phù hợp gần bạn.');
        }

        setState(() {});
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể lấy địa điểm từ HERE API.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã xảy ra lỗi khi lấy vị trí.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Search Places')),
      body: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  margin: EdgeInsets.only(top: 20, bottom: 10, left: 16),
                  padding: EdgeInsets.symmetric(horizontal: 15),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Type your place name',
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
                          IconButton(
                            icon:
                                Icon(_isListening ? Icons.mic : Icons.mic_none),
                            onPressed: _listen,
                          ),
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
              Container(
                margin: EdgeInsets.only(top: 20, bottom: 10, right: 16, left: 8),
                child: IconButton(
                  icon: Icon(Icons.my_location, color: Colors.black),
                  iconSize: 30,
                  onPressed: _getCurrentLocation,
                ),
              ),
            ],
          ),
          Expanded(
            child: ListView.separated(
              itemCount: _places.length,
              separatorBuilder: (context, index) => Divider(
                color: Colors.grey,
                height: 1,
                indent: 16,
                endIndent: 16,
              ),
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(_places[index]),
                  onTap: () => _selectPlace(_places[index], index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
