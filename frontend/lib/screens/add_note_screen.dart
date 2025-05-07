// import 'package:flutter/material.dart';
// import 'package:frontend/models/note_model.dart';
// import 'package:frontend/services/database.dart';
// import 'package:frontend/services/notification_service.dart';
// import 'package:intl/intl.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';
// import 'dart:math' show cos, sqrt, asin;

// class AddNoteScreen extends StatefulWidget {
//   final DatabaseHelper databaseHelper;

//   const AddNoteScreen({required this.databaseHelper, super.key});

//   @override
//   _AddNoteScreenState createState() => _AddNoteScreenState();
// }

// class _AddNoteScreenState extends State<AddNoteScreen> {
//   final TextEditingController _contentController = TextEditingController();
//   DateTime? _selectedDateTime;
//   bool _isLoading = false;
//   String _errorMessage = '';
//   Map<String, dynamic>? _weatherData;
//   final String _apiKey =
//       '2b5630205440fa5d9747bc910681e783'; // From AddLocationScreen

//   @override
//   void initState() {
//     super.initState();
//     _fetchCurrentLocationAndWeather();
//   }

//   Future<void> _fetchCurrentLocationAndWeather() async {
//     setState(() {
//       _isLoading = true;
//       _errorMessage = '';
//     });
//     try {
//       // Request location permission and get current position
//       Position position = await _determinePosition();

//       // Get all locations from database
//       final locations = await widget.databaseHelper.getAllLocations();
//       if (locations.isEmpty) {
//         throw Exception('Không có dữ liệu vị trí trong cơ sở dữ liệu');
//       }

//       // Find closest location using Haversine formula
//       Map<String, dynamic>? closestLocation;
//       double minDistance = double.infinity;
//       for (var loc in locations) {
//         double distance = _calculateDistance(
//           position.latitude,
//           position.longitude,
//           loc['latitude'],
//           loc['longitude'],
//         );
//         if (distance < minDistance) {
//           minDistance = distance;
//           closestLocation = loc;
//         }
//       }

//       if (closestLocation == null) {
//         throw Exception('Không tìm thấy vị trí phù hợp');
//       }

//       // Fetch weather data from OpenWeatherMap API
//       final weatherData = await _fetchWeather(
//           closestLocation['latitude'], closestLocation['longitude']);
//       if (weatherData == null) {
//         throw Exception(
//             'Không thể lấy dữ liệu thời tiết cho ${closestLocation['name']}');
//       }

//       setState(() {
//         _weatherData = {
//           'humidity': weatherData['main']['humidity'].toDouble(),
//           'temperature': weatherData['main']['temp'].toDouble(),
//           'location': closestLocation?['name'],
//           'weather_description': weatherData['weather'][0]['description'],
//           'wind_speed': weatherData['wind']['speed'].toDouble(),
//         };
//       });
//     } catch (e) {
//       if (mounted) {
//         setState(() {
//           _errorMessage = 'Lỗi khi lấy dữ liệu thời tiết: $e';
//         });
//       }
//     } finally {
//       if (mounted) {
//         setState(() {
//           _isLoading = false;
//         });
//       }
//     }
//   }

//   Future<Map<String, dynamic>?> _fetchWeather(double lat, double lon) async {
//     final url =
//         'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$_apiKey&units=metric&lang=vi';
//     try {
//       final response = await http.get(Uri.parse(url));
//       if (response.statusCode == 200) {
//         return jsonDecode(response.body);
//       } else {
//         print(
//             'Failed to fetch weather for lat: $lat, lon: $lon: ${response.statusCode}');
//         return null;
//       }
//     } catch (e) {
//       print('Error fetching weather for lat: $lat, lon: $lon: $e');
//       return null;
//     }
//   }

//   double _calculateDistance(
//       double lat1, double lon1, double lat2, double lon2) {
//     const double p = 0.017453292519943295; // Math.PI / 180
//     final double a = 0.5 -
//         cos((lat2 - lat1) * p) / 2 +
//         cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
//     return 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
//   }

//   Future<Position> _determinePosition() async {
//     bool serviceEnabled;
//     LocationPermission permission;

//     serviceEnabled = await Geolocator.isLocationServiceEnabled();
//     if (!serviceEnabled) {
//       throw Exception('Dịch vụ định vị bị tắt');
//     }

//     permission = await Geolocator.checkPermission();
//     if (permission == LocationPermission.denied) {
//       permission = await Geolocator.requestPermission();
//       if (permission == LocationPermission.denied) {
//         throw Exception('Quyền định vị bị từ chối');
//       }
//     }

//     if (permission == LocationPermission.deniedForever) {
//       throw Exception(
//           'Quyền định vị bị từ chối vĩnh viễn. Vui lòng cấp quyền trong cài đặt.');
//     }

//     return await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.high);
//   }

//   Future<void> _selectDateTime(BuildContext context) async {
//     final DateTime? pickedDate = await showDatePicker(
//       context: context,
//       initialDate: DateTime.now(),
//       firstDate: DateTime.now(),
//       lastDate: DateTime(2101),
//     );
//     if (pickedDate != null) {
//       final TimeOfDay? pickedTime = await showTimePicker(
//         context: context,
//         initialTime: TimeOfDay.now(),
//       );
//       if (pickedTime != null) {
//         setState(() {
//           _selectedDateTime = DateTime(
//             pickedDate.year,
//             pickedDate.month,
//             pickedDate.day,
//             pickedTime.hour,
//             pickedTime.minute,
//           );
//         });
//       }
//     }
//   }

//   Future<void> _saveNote() async {
//     if (_contentController.text.isEmpty ||
//         _selectedDateTime == null ||
//         _weatherData == null) {
//       setState(() {
//         _errorMessage =
//             'Vui lòng nhập nội dung, chọn thời gian và đảm bảo dữ liệu thời tiết';
//       });
//       return;
//     }

//     setState(() {
//       _isLoading = true;
//       _errorMessage = '';
//     });

//     try {
//       final note = Note(
//         content: _contentController.text,
//         reminderTime: _selectedDateTime!,
//         humidity: _weatherData!['humidity'],
//         temperature: _weatherData!['temperature'],
//         location: _weatherData!['location'],
//         weatherDescription: _weatherData!['weather_description'],
//         windSpeed: _weatherData!['wind_speed'],
//       );

//       final noteId = await widget.databaseHelper.insertNote(note);

//       final notificationBody = 'Thời tiết tại ${_weatherData!['location']}:\n'
//           'Nhiệt độ trung bình: ${_weatherData!['temperature']}°C\n'
//           'Độ ẩm trung bình: ${_weatherData!['humidity']}%\n'
//           'Thời tiết: ${_weatherData!['weather_description']}\n'
//           'Tốc độ gió: ${_weatherData!['wind_speed']} m/s\n'
//           'Ngày: ${DateFormat('dd/MM/yyyy HH:mm').format(_selectedDateTime!)}';

//       await NotificationService().scheduleNoteNotification(
//         id: noteId,
//         title: 'Dự báo thời tiết',
//         body: notificationBody,
//         reminderTime: _selectedDateTime!,
//       );

//       if (mounted) {
//         Navigator.pop(context);
//       }
//     } catch (e) {
//       if (mounted) {
//         setState(() {
//           _errorMessage = 'Lỗi khi lưu ghi chú: $e';
//         });
//       }
//     } finally {
//       if (mounted) {
//         setState(() {
//           _isLoading = false;
//         });
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Thêm ghi chú'),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: SingleChildScrollView(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               TextField(
//                 controller: _contentController,
//                 decoration: const InputDecoration(
//                   labelText: 'Nội dung ghi chú',
//                   border: OutlineInputBorder(),
//                 ),
//                 maxLines: 3,
//               ),
//               const SizedBox(height: 16),
//               ListTile(
//                 title: Text(
//                   _selectedDateTime == null
//                       ? 'Chọn thời gian nhắc nhở'
//                       : 'Thời gian: ${DateFormat('dd/MM/yyyy HH:mm').format(_selectedDateTime!)}',
//                 ),
//                 trailing: const Icon(Icons.calendar_today),
//                 onTap: () => _selectDateTime(context),
//               ),
//               const SizedBox(height: 16),
//               _isLoading
//                   ? const Center(child: CircularProgressIndicator())
//                   : ElevatedButton(
//                       onPressed: _saveNote,
//                       child: const Text('Lưu ghi chú'),
//                     ),
//               if (_weatherData != null) ...[
//                 const SizedBox(height: 16),
//                 Text(
//                   'Thời tiết hiện tại tại ${_weatherData!['location']}:\n'
//                   'Nhiệt độ: ${_weatherData!['temperature']}°C\n'
//                   'Độ ẩm: ${_weatherData!['humidity']}%\n'
//                   'Thời tiết: ${_weatherData!['weather_description']}\n'
//                   'Tốc độ gió: ${_weatherData!['wind_speed']} m/s',
//                   style: const TextStyle(fontSize: 16),
//                 ),
//               ],
//               if (_errorMessage.isNotEmpty) ...[
//                 const SizedBox(height: 16),
//                 Text(
//                   _errorMessage,
//                   style: const TextStyle(color: Colors.red, fontSize: 14),
//                 ),
//               ],
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     _contentController.dispose();
//     super.dispose();
//   }
// }
