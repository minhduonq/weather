import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ChatService {
  // Cấu hình URL dựa trên môi trường
  static const String baseUrl = kDebugMode
      ? 'http://10.0.2.2:8000' // Android Emulator
      : 'http://your-production-server.com:8000'; // Production server

  // Model cho tin nhắn
  static Future<String> sendMessage(String message) async {
    try {
      print('Đang gửi tin nhắn đến: $baseUrl/chat');

      final response = await http
          .post(
            Uri.parse('$baseUrl/chat'),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'message': message,
            }),
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
      request.body = jsonEncode({'message': message});

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
