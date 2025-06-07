import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatService {
  // Thay đổi URL này thành địa chỉ server FastAPI của bạn
  static const String baseUrl =
      'http://your-server-ip:8000'; // Hoặc 'http://localhost:8000' cho local

  // Model cho tin nhắn
  static Future<String> sendMessage(String message) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/chat'), // Endpoint của FastAPI chatbot
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'message': message,
          // Thêm các parameters khác nếu cần
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['response'] ?? 'Không có phản hồi';
      } else {
        throw Exception('Lỗi server: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Lỗi kết nối: $e');
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
