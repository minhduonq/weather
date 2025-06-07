import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

class ChatService {
  // Cấu hình URL dựa trên môi trường
  static const String baseUrl =
      kDebugMode ? 'http://127.0.0.1:8000' : 'http://localhost:8000';

  // Tạo UUID cho user (có thể lưu vào SharedPreferences để persist)
  static String _userId = const Uuid().v4();

  // Getter để có thể access userId từ ngoài nếu cần
  static String get userId => _userId;

  // Setter để có thể set userId từ ngoài (ví dụ từ SharedPreferences)
  static set userId(String id) => _userId = id;

  // Model cho tin nhắn
  static Future<String> sendMessage(String message) async {
    try {
      print('Đang gửi tin nhắn đến: $baseUrl/chat');
      print('User ID: $_userId');

      final requestBody = {
        'uid': _userId,
        'message': message,
      };

      print('Request body: ${jsonEncode(requestBody)}');

      final response = await http
          .post(
            Uri.parse('$baseUrl/chat'),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(Duration(seconds: 30));

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['response'] ?? data['message'] ?? 'Không có phản hồi';
      } else {
        throw Exception(
            'Lỗi server: ${response.statusCode} - ${response.body}');
      }
    } on http.ClientException catch (e) {
      print('ClientException: $e');
      throw Exception('Lỗi kết nối: Không thể kết nối đến server. Kiểm tra:\n'
          '1. Server có đang chạy không?\n'
          '2. URL có đúng không?\n'
          '3. Mạng có ổn định không?\n'
          'Chi tiết: $e');
    } on FormatException catch (e) {
      print('FormatException: $e');
      throw Exception('Lỗi định dạng dữ liệu từ server');
    } catch (e) {
      print('Unknown error: $e');
      throw Exception('Lỗi không xác định: $e');
    }
  }

  // Nếu API có streaming response
  static Stream<String> sendMessageStream(String message) async* {
    try {
      final request = http.Request(
        'POST',
        Uri.parse('$baseUrl/chat/stream'),
      );

      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode({'uid': _userId, 'message': message});

      final streamedResponse = await request.send();

      if (streamedResponse.statusCode == 200) {
        await for (String chunk in streamedResponse.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
          if (chunk.isNotEmpty) {
            yield chunk;
          }
        }
      }
    } catch (e) {
      yield 'Lỗi: $e';
    }
  }
}
