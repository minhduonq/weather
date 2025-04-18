import 'dart:convert';
import '../services/constants.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'LocationManage.dart';

class SearchPlace extends StatefulWidget {
  @override
  _SearchPlaceState createState() => _SearchPlaceState();
}

class _SearchPlaceState extends State<SearchPlace> {
  TextEditingController _searchController = TextEditingController();
  List<String> _places = [];
  Future<void> _searchPlaces(String query) async {

    query = query.replaceAll(' ', '+');

    String apiKey = 't8j30ZcKTjahgwuPbHRDWmqx1JXdaBg4Lz7a82tixWs';
    String coordinates = '21,104';

    // Construct the API URL
    String apiUrl =
        'https://discover.search.hereapi.com/v1/discover?at=$coordinates&q=$query&apiKey=$apiKey';

    // Make the API call
    var response = await http.get(Uri.parse(apiUrl));

    if (response.statusCode == 200) {
      // Parse the response JSON
      data = json.decode(utf8.decode(response.bodyBytes));
      List<dynamic> items = data['items'];

      // Clear previous places
      _places.clear();

      // Add places with resultType 'locality' to the list
      for (var item in items) {
        if (item['resultType'] == 'locality' ) {
          _places.add(item['address']['label']);
        }
        if(item['resultType'] == 'administrativeArea') {
          _places.add(item['address']['label']);
        }
      }
      // Update the UI
      setState(() {});
    } else {
      // Handle API call error
      print('Failed to fetch data: ${response.statusCode}');
    }
  }
  void _selectPlace(String selectedPlace, int index) {
    double lat = data['items'][index]['position']['lat'];
    double lon = data['items'][index]['position']['lng'];

    selectedPlaces.add({
      'name' : OfficialName(selectedPlace),
      'latitude': lat,
      'longitude': lon,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$selectedPlace đã được lưu.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Search Places'),
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.only(left: 10, right: 10),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10)
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Type your place name',
                suffixIcon: IconButton(
                  icon: Icon(Icons.search),
                  onPressed: () {
                    _searchPlaces(_searchController.text);
                  },
                ),
              ),
            ),
          ),

          Expanded(
            child: ListView.builder(
              itemCount: _places.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(_places[index]),
                  onTap: () {
                    _selectPlace(_places[index], index);
                    Navigator.of(context).push(MaterialPageRoute(builder: (context) => LocationManage()));
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}