import 'dart:convert';
import 'package:frontend/screens/manage_location.dart';
import 'package:get/get.dart';

import '../services/constants.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../services/constants.dart';
import '../services/database.dart';

import 'manage_location.dart';
import '../services/helpTrans.dart';

class SearchPlace extends StatefulWidget {
  const SearchPlace({Key? key}) : super(key: key); // ✅ Sửa lỗi thiếu `key`

  @override
  _SearchPlaceState createState() => _SearchPlaceState();
}

class _SearchPlaceState extends State<SearchPlace> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final DatabaseHelper dbHelper = DatabaseHelper();
  List<String> _places = [];
  var data;
  bool _isListening = false;
  late stt.SpeechToText _speech;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initializeSpeech();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _animation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  Future<void> _initializeSpeech() async {
    bool available = await _speech.initialize(
      onError: (error) => print('Speech recognition error: $error'),
      onStatus: (status) => print('Speech recognition status: $status'),
    );
    if (!available) {
      print('Speech recognition not available');
    }
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
      MaterialPageRoute(builder: (context) => ManageLocationsScreen()),
    );
  }

  void _listen() async {
    if (!_isListening) {
      try {
        setState(() => _isListening = true);
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
      }
    } else {
      _stopListening();
    }
  }

  void _stopListening() {
    setState(() {
      _isListening = false;
      _speech.stop();
      _animationController.stop();
    });
  }

  void _handleSpeechResult(String recognizedWords) {
    if (recognizedWords.isNotEmpty) {
      setState(() {
        _searchController.text = recognizedWords;
        _onSearchChanged(recognizedWords);
      });
    }
  }

  @override
  void dispose() {
    _speech.stop();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Search Places')),
      body: Stack(
        children: [
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      margin: EdgeInsets.only(top: 20, bottom: 10, left: 16, right: 16),
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
                                icon: Icon(
                                  _isListening ? Icons.mic : Icons.mic_none,
                                  color: _isListening ? Colors.red : null,
                                ),
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
          if (_isListening)
            Center(
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _animation.value,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.8),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          Icons.mic,
                          color: Colors.white,
                          size: 80,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
