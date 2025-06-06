import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ChatbotScreen extends StatefulWidget {
  @override
  _ChatbotScreenState createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];

  bool isTyping = false;
  final String apiKey = 'AIzaSyDv21o-mD0f6rkDTSaridF7Sw_TQPAVsMw';
  List<Map<String, String>> conversationHistory = [];

  Future<String> sendMessageToGemini(String message) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$apiKey',
    );

    final headers = {'Content-Type': 'application/json'};

    // Thêm tin nhắn mới vào history
    conversationHistory.add({"role": "user", "text": message});

    // Tạo phần body từ lịch sử hội thoại
    final body = jsonEncode({
      "contents": conversationHistory.map((msg) {
        return {
          "role": msg["role"],
          "parts": [
            {"text": msg["text"]}
          ]
        };
      }).toList()
    });

    final response = await http.post(url, headers: headers, body: body);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final botReply = data['candidates']?[0]?['content']?['parts']?[0]
              ?['text'] ??
          '(không có phản hồi)';

      // Thêm phản hồi của bot vào history
      conversationHistory.add({"role": "model", "text": botReply});

      return botReply;
    } else {
      throw Exception('Lỗi API: ${response.body}');
    }
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'user': text});
      isTyping = true;
      _messages.add({'bot': 'Đang phản hồi...'});
    });

    _controller.clear();

    try {
      final botReply = await sendMessageToGemini(text);

      setState(() {
        _messages.removeLast();
        _messages.add({'bot': botReply});
        isTyping = false;
      });
    } catch (e) {
      setState(() {
        _messages.removeLast();
        _messages.add({'bot': 'Lỗi: ${e.toString()}'});
        isTyping = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chatbot', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blueAccent,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final isUser = _messages[index].containsKey('user');
                final message =
                    isUser ? _messages[index]['user'] : _messages[index]['bot'];

                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: EdgeInsets.symmetric(vertical: 4),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.blue : Colors.grey[300],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      message!,
                      style: TextStyle(
                          color: isUser ? Colors.white : Colors.black87),
                    ),
                  ),
                );
              },
            ),
          ),
          if (isTyping)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                'Bot đang gõ...',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: 'Nhập tin nhắn...',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send, color: Colors.blue),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
