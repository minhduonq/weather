import 'package:flutter/material.dart';
import 'package:frontend/screens/HomePage.dart';
import 'package:geolocator/geolocator.dart';
import '../services/constants.dart';
import 'SearchPlace.dart';

class LocationManage extends StatefulWidget {
  @override
  _LocationManageState createState() => _LocationManageState();
}

class _LocationManageState extends State<LocationManage> {
  bool editMode = false; // Variable to track edit mode
  List<bool> selectedToDelete =
      []; // List to track selected places for deletion

  @override
  void initState() {
    super.initState();
    // Initialize selectedToDelete list based on selectedPlaces length
    selectedToDelete = List.generate(selectedPlaces.length, (index) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Places Management'),
        actions: [
          // Move these buttons to actions instead of in the title
          IconButton(
            onPressed: () {
              Navigator.of(context)
                  .push(MaterialPageRoute(builder: (context) => SearchPlace()));
            },
            icon: Icon(Icons.add),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                // Toggle edit mode
                editMode = !editMode;
                if (!editMode) {
                  // Clear selectedToDelete list when exiting edit mode
                  selectedToDelete =
                      List.generate(selectedPlaces.length, (index) => false);
                }
              });
            },
            icon: Icon(Icons.edit),
          ),
          // Confirm button to delete selected places
          if (editMode)
            IconButton(
              onPressed: deleteSelectedPlaces,
              icon: Icon(Icons.delete_forever_rounded),
            ),
        ],
      ),
      body: ListView.builder(
        itemCount: selectedPlaces.length,
        itemBuilder: (context, index) {
          final place = selectedPlaces[index];
          return ListTile(
            title: Row(
              children: [
                // Display checkbox only in edit mode
                if (editMode)
                  Checkbox(
                    value: selectedToDelete[index],
                    onChanged: (value) {
                      setState(() {
                        selectedToDelete[index] = value!;
                      });
                    },
                  ),
                SizedBox(
                    width: editMode
                        ? 10
                        : 0), // Add spacing between checkbox and place name
                Expanded(
                    child: Text(place['name'],
                        overflow: TextOverflow
                            .ellipsis)), // Wrap with Expanded to prevent overflow
              ],
            ),
            onTap: () {
              if (!editMode) {
                setState(() {
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
                  currentPosition = KeyLocation;
                  Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => HomePage()));
                });
              }
            },
          );
        },
      ),
    );
  }

  // Function to delete selected places
  void deleteSelectedPlaces() {
    setState(() {
      for (int i = selectedToDelete.length - 1; i >= 0; i--) {
        if (selectedToDelete[i]) {
          selectedPlaces.removeAt(i);
          selectedToDelete.removeAt(i);
        }
      }
      // Exit edit mode after deletion
      editMode = false;
    });
  }
}
