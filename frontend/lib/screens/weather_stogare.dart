import 'package:flutter/material.dart';
import 'package:frontend/services/database.dart';
import 'package:frontend/widgets/modals/show_custom.dart';

class WeatherStorageScreen extends StatefulWidget {
  @override
  _WeatherStorageScreenState createState() => _WeatherStorageScreenState();
}

class _WeatherStorageScreenState extends State<WeatherStorageScreen> {
  List<Map<String, dynamic>> favouriteLocations = [];
  List<Map<String, dynamic>> otherLocations = [];
  List<Map<String, dynamic>> allLocations = []; // Lưu trữ tất cả các địa điểm
  String searchQuery = ""; // Biến lưu trữ từ khóa tìm kiếm

  @override
  void initState() {
    super.initState();
    loadLocations();
  }

  Future<void> loadLocations() async {
    final db = DatabaseHelper();
    final locations = await db.getAllLocations();
    final weatherDataList = await db.getAllWeatherData();

    final weatherByLocation = {
      for (var w in weatherDataList) w['location_id']: w,
    };

    setState(() {
      allLocations = locations; // Lưu tất cả các địa điểm
      // Ví dụ: lấy 1 địa điểm đầu làm "favourite", cònlại là "others"
      if (locations.isNotEmpty) {
        favouriteLocations = [locations.first];
        otherLocations = locations.skip(1).toList();
      }

      // Gắn weather tương ứng vào mỗi location
      favouriteLocations = favouriteLocations.map((loc) {
        return {
          ...loc,
          'weather': weatherByLocation[loc['id']],
        };
      }).toList();

      otherLocations = otherLocations.map((loc) {
        return {
          ...loc,
          'weather': weatherByLocation[loc['id']],
        };
      }).toList();
    });
  }

  // Hàm lọc địa điểm dựa trên từ khóa tìm kiếm
  List<Map<String, dynamic>> filterLocations(String query) {
    return allLocations.where((location) {
      final name = location['name'].toLowerCase();
      final searchQueryLower = query.toLowerCase();
      return name
          .contains(searchQueryLower); // Lọc các địa điểm chứa từ khóa tìm kiếm
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Center(
          child: Text(
            'Manage locations',
            style: TextStyle(color: Colors.black),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: Colors.black),
            onPressed: () {
              // Handle add location
            },
          ),
          IconButton(
            icon: Icon(Icons.more_vert, color: Colors.black),
            onPressed: () {
              showCustomModal(context);
            },
          ),
          // TextField tìm kiếm
          IconButton(
            icon: Icon(Icons.search, color: Colors.black),
            onPressed: () {
              showSearch(
                context: context,
                delegate: LocationSearchDelegate(
                  locations: allLocations,
                  onSearch: (query) {
                    setState(() {
                      searchQuery = query;
                      favouriteLocations = filterLocations(query)
                          .take(1)
                          .toList(); // Lọc favourite locations
                      otherLocations = filterLocations(query)
                          .skip(1)
                          .toList(); // Lọc other locations
                    });
                  },
                ),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Favourite location',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            ...favouriteLocations.map(buildLocationCard),
            SizedBox(height: 16),
            Text(
              'Other locations',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            ...otherLocations.map(buildLocationCard),
          ],
        ),
      ),
    );
  }

  Widget buildLocationCard(Map<String, dynamic> location) {
    final weather = location['weather'] ?? {};
    final temp = weather['temperature']?.round() ?? '--';
    final icon = weather['icon'] ?? '01d'; // Mặc định nếu không có icon

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.grey.shade200,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(location['name'],
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text('${location['name']}, Vietnam',
                      style: TextStyle(color: Colors.grey[700])),
                ],
              ),
            ),
            Row(
              children: [
                Image.network(
                  'https://openweathermap.org/img/wn/$icon@2x.png', // Link hình ảnh icon thời tiết
                  width: 40,
                  height: 40,
                  errorBuilder: (_, __, ___) => Icon(
                      Icons.cloud), // Nếu không có hình, hiển thị icon cloud
                ),
                SizedBox(width: 8),
                Text('$temp°', style: TextStyle(fontSize: 20)),
              ],
            )
          ],
        ),
      ),
    );
  }
}

// Định nghĩa delegate cho tìm kiếm
class LocationSearchDelegate extends SearchDelegate {
  final List<Map<String, dynamic>> locations;
  final Function(String) onSearch;

  LocationSearchDelegate({
    required this.locations,
    required this.onSearch,
  });

  @override
  String? get searchFieldLabel => 'Search location';

  @override
  TextInputAction get textInputAction => TextInputAction.search;

  // Phương thức để tạo giao diện các hành động (ví dụ: clear, search)
  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: Icon(Icons.clear),
        onPressed: () {
          query = ''; // Xóa kết quả tìm kiếm
        },
      ),
    ];
  }

  // Phương thức để tạo giao diện phía bên trái (ví dụ: icon quay lại)
  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null); // Đóng tìm kiếm khi nhấn nút quay lại
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final queryResults = locations.where((location) {
      final name = location['name'].toLowerCase();
      return name.contains(query.toLowerCase());
    }).toList();

    return ListView.builder(
      itemCount: queryResults.length,
      itemBuilder: (context, index) {
        final location = queryResults[index];
        return ListTile(
          title: Text(location['name']),
          subtitle: Text('${location['name']}, Vietnam'),
          onTap: () {
            onSearch(query); // Cập nhật danh sách sau khi tìm kiếm
            close(context, null);
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final queryResults = locations.where((location) {
      final name = location['name'].toLowerCase();
      return name.contains(query.toLowerCase());
    }).toList();

    return ListView.builder(
      itemCount: queryResults.length,
      itemBuilder: (context, index) {
        final location = queryResults[index];
        return ListTile(
          title: Text(location['name']),
          subtitle: Text('${location['name']}, Vietnam'),
          onTap: () {
            onSearch(query); // Cập nhật danh sách sau khi tìm kiếm
            close(context, null);
          },
        );
      },
    );
  }
}
