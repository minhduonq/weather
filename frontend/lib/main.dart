import 'package:flutter/material.dart';

// Your HomePage class
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFC0C0C0),
      drawer: Drawer(
        backgroundColor: Colors.grey[200],
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icons on top
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Image.asset(
                      '/Users/raiju/weather/assets/AI.png',
                      width: 45,
                      height: 45,
                    ),
                    SizedBox(width: 16),
                    Image.asset(
                      '/Users/raiju/weather/assets/setting.png',
                      width: 25,
                      height: 25,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  '★ Vị trí yêu thích',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: Icon(Icons.location_on),
                title: Text('Hà Nội'),
                trailing: Text('23°C'),
              ),
              Divider(),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Địa điểm khác',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ...List.generate(4, (index) {
                return ListTile(
                  leading: Icon(Icons.location_on_outlined),
                  title: Text('Hà Nội'),
                  trailing: Text('23°C'),
                );
              }),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: StadiumBorder(),
                    ),
                    child: Text('Quản lý vị trí'),
                  ),
                ),
              ),
              Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TextButton.icon(
                  onPressed: () {
                    print('Báo cáo sai vị trí');
                  },
                  icon: Icon(Icons.info_outline, color: Colors.black),
                  label: Text(
                    'Báo cáo sai vị trí',
                    style: TextStyle(color: Colors.black),
                  ),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero, // nếu muốn sát hơn
                    alignment:
                        Alignment.centerLeft, // căn trái cho giống ListTile
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(35), // Chiều cao của AppBar
        child: Container(
          width: 0, // Đặt độ rộng AppBar
          color: Colors.grey[300],
          child: AppBar(
            backgroundColor: Colors.transparent, // Làm nền AppBar trong suốt
            elevation: 0,
            iconTheme: IconThemeData(color: Colors.black),
          ),
        ),
      ),

      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon của bạn
                  Image.asset(
                    '/Users/raiju/weather/assets/location.png', // Đường dẫn tới icon của bạn
                    width: 15, // Kích thước icon (có thể điều chỉnh)
                    height: 15, // Kích thước icon (có thể điều chỉnh)
                  ),
                  SizedBox(width: 4), // Khoảng cách giữa icon và text
                  // Text "Hà Nội"
                  Text('Hà Nội', style: TextStyle(fontSize: 16)),
                ],
              ),

              Text(
                'Hà Nội\n23°C',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
              ),
              Text('H: 32°C  L: 32°C'),
              SizedBox(height: 20),

              // Hourly forecast
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(4, (index) {
                    return Column(
                      children: [
                        Text('Now +$index'),
                        Icon(Icons.cloud, size: 32),
                        Text('23°C'),
                      ],
                    );
                  }),
                ),
              ),
              SizedBox(height: 16),

              Container(
  padding: EdgeInsets.all(12),
  decoration: BoxDecoration(
    color: Colors.grey[200],
    borderRadius: BorderRadius.circular(16),
  ),
  child: LayoutBuilder(
    builder: (context, constraints) {
      double totalWidth = constraints.maxWidth;

      // Tính tỷ lệ width cho các cột
      double dayColumnWidth = totalWidth * 0.25; // Cột ngày
      double iconColumnWidth = totalWidth * 0.15; // Cột icon
      double tempLowColumnWidth = totalWidth * 0.35; // Cột nhiệt độ thấp
      double tempHighColumnWidth = totalWidth * 0.20; // Cột nhiệt độ cao

      return Column(
        children: List.generate(6, (index) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              children: [
                // Cột 1: Ngày
                Container(
                  margin: EdgeInsets.only(left: 8),
                  width: dayColumnWidth,
                  child: Text(
                    [
                      'Hôm nay',
                      'Chủ nhật',
                      'Thứ 2',
                      'Thứ 3',
                      'Thứ 4',
                      'Thứ 5',
                    ][index],
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),

                // Cột 2: Icon mây
                SizedBox(
                  width: iconColumnWidth,
                  child: Icon(Icons.cloud, size: 24),
                ),

                // Cột 3: Nhiệt độ thấp
                SizedBox(
                  width: tempLowColumnWidth,
                  child: Text('23°C', textAlign: TextAlign.center),
                ),

                // Cột 4: Nhiệt độ cao
                SizedBox(
                  width: tempHighColumnWidth,
                  child: Text('32°C', textAlign: TextAlign.center),
                ),
              ],
            ),
          );
        }),
      );
    },
  ),
),

              SizedBox(height: 16),

              // Rain map
              Container(
  padding: EdgeInsets.all(12),
  decoration: BoxDecoration(
    color: Colors.white.withOpacity(0.6),
    borderRadius: BorderRadius.circular(16),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('🌧 Bản đồ lượng mưa'),
      SizedBox(height: 8),
      LayoutBuilder(
        builder: (context, constraints) {
          // Lấy kích thước width của container bao quanh
          double screenWidth = MediaQuery.of(context).size.width;

          return Container(
            width: screenWidth * 0.9,  // Sử dụng phần trăm của width bao quanh
            height: screenWidth * 0.87,  // Đặt chiều cao cho bản đồ
            color: Colors.blue[100],
            child: Center(child: Text('Map Placeholder')),
          );
        },
      ),
    ],
  ),
),


              SizedBox(height: 16),

              // Details
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildInfoCard(
                    'Cảm nhận',
                    '25°C\nGiống với nhiệt độ thực tế',
                  ),
                  _buildInfoCard('Độ ẩm', '37%\nĐộ ẩm trung bình'),
                  _buildInfoCard(
                    'Cảm nhận',
                    '25°C\nGiống với nhiệt độ thực tế',
                  ),
                  _buildInfoCard('Độ ẩm', '37%\nĐộ ẩm trung bình'),
                  _buildInfoCard(
                    '💨 Gió',
                    '15 km/h\nGió giật 30 km/h\nHướng: Đông Nam',
                  ),
                ],
              ),
              SizedBox(height: 80), // Khoảng trống để tránh che bởi nav bar
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.cloud), label: ''),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_pin_circle),
            label: '',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: ''),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String content) {
    return Container(
      width: 160,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text(content),
        ],
      ),
    );
  }
}

// Main function
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const HomePage(), // Update to use HomePage here
    );
  }
}
