import 'dart:convert';
import 'package:http/http.dart' as http;

class GitHubService {
  // Backend API URL - thay đổi URL này nếu backend chạy ở địa chỉ khác
  static const String baseUrl = 'http://localhost:3002/github';
  
  // Lấy danh sách commits
  static Future<List<Map<String, dynamic>>> getCommits({
    String owner = 'minhduonq',
    String repo = 'weather',
    int page = 1,
    int perPage = 30,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/commits').replace(queryParameters: {
        'owner': owner,
        'repo': repo,
        'page': page.toString(),
        'per_page': perPage.toString(),
      });
      
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['commits'] != null) {
          return List<Map<String, dynamic>>.from(data['commits']);
        }
      }
      
      print('Lỗi khi lấy commits: ${response.statusCode}');
      return [];
    } catch (e) {
      print('Lỗi khi kết nối API: $e');
      return [];
    }
  }
  
  // Lấy chi tiết một commit
  static Future<Map<String, dynamic>?> getCommitDetail({
    required String sha,
    String owner = 'minhduonq',
    String repo = 'weather',
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/commits/$sha').replace(queryParameters: {
        'owner': owner,
        'repo': repo,
      });
      
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['commit'] != null) {
          return data['commit'];
        }
      }
      
      print('Lỗi khi lấy chi tiết commit: ${response.statusCode}');
      return null;
    } catch (e) {
      print('Lỗi khi kết nối API: $e');
      return null;
    }
  }
  
  // Format thời gian
  static String formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inDays > 7) {
        return '${date.day}/${date.month}/${date.year}';
      } else if (difference.inDays > 0) {
        return '${difference.inDays} ngày trước';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} giờ trước';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} phút trước';
      } else {
        return 'Vừa xong';
      }
    } catch (e) {
      return dateString;
    }
  }
  
  // Lấy short SHA (7 ký tự đầu)
  static String getShortSha(String sha) {
    return sha.length > 7 ? sha.substring(0, 7) : sha;
  }
}
