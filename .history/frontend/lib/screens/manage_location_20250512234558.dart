import 'package:flutter/material.dart';
import 'package:frontend/services/database.dart';
import 'package:get/get.dart';

class ManageLocationsScreen extends StatefulWidget {
  @override
  _ManageLocationsScreenState createState() => _ManageLocationsScreenState();
}

class _ManageLocationsScreenState extends State<ManageLocationsScreen> {
  List<bool> selectedLocations = [];
  int? favouriteIndex;

  final DatabaseHelper dbHelper = DatabaseHelper();
  final db = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  // Tải dữ liệu từ cơ sở dữ liệu
  Future<void> _loadLocations() async {
    List<Map<String, dynamic>> locationData = await dbHelper.getAllLocations();
    setState(() {
      selectedLocations = List.generate(locationData.length, (_) => false);
    });
  }

  // Chọn tất cả các địa điểm
  void _selectAll() {
    setState(() {
      bool allSelected = selectedLocations.every((element) => element);
      selectedLocations =
          List.generate(selectedLocations.length, (_) => !allSelected);
    });
  }

  // Thiết lập địa điểm yêu thích
  void _setFavourite() async {
    if (selectedLocations.contains(true)) {
      int selectedLocationIndex = selectedLocations.indexOf(true);
      List<Map<String, dynamic>> locations = await dbHelper.getAllLocations();
      Map<String, dynamic> selectedLocation = locations[selectedLocationIndex];

      setState(() {
        favouriteIndex = selectedLocationIndex;
      });
      // Bạn có thể lưu lại thông tin yêu thích vào cơ sở dữ liệu ở đây
    }
  }

  // Xóa các địa điểm đã chọn
  void _deleteSelected() async {
    List<Map<String, dynamic>> locations = await dbHelper.getAllLocations();
    for (int i = locations.length - 1; i >= 0; i--) {
      if (selectedLocations[i]) {
        await dbHelper.deleteLocation(locations[i]['id']);
        setState(() {
          selectedLocations.removeAt(i);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('selected_locations'.tr,
            style: TextStyle(color: Colors.grey[700])),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: GestureDetector(
              onTap: _selectAll,
              child: Center(
                child: Text("all".tr, style: TextStyle(color: Colors.grey)),
              ),
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: dbHelper.getAllLocations(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('no_locations'.tr));
          }

          List<Map<String, dynamic>> locations = snapshot.data!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              sectionTitle('favourite_location'.tr),
              locationTile(0, locations),
              sectionTitle('other_locations'.tr),
              for (int i = 1; i < locations.length; i++)
                locationTile(i, locations),
            ],
          );
        },
      ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          children: [
            Expanded(
              child: TextButton.icon(
                onPressed: _setFavourite,
                icon: Icon(Icons.check),
                label: Text('set_favourite'.tr),
              ),
            ),
            VerticalDivider(),
            Expanded(
              child: TextButton.icon(
                onPressed: _deleteSelected,
                icon: Icon(Icons.delete),
                label: Text('delete'.tr),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Text(title, style: TextStyle(color: Colors.grey)),
    );
  }

  Widget locationTile(int index, List<Map<String, dynamic>> locations) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[300],
          border: Border.all(
            color: selectedLocations[index] ? Colors.blue : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: ListTile(
          leading: Checkbox(
            value: selectedLocations[index],
            onChanged: (bool? value) {
              setState(() {
                selectedLocations[index] = value!;
              });
            },
          ),
          title: Text(locations[index]['name'],
              style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(
              '${locations[index]['latitude']}, ${locations[index]['longitude']}'),
          trailing: Icon(Icons.expand_more),
        ),
      ),
    );
  }
}
