import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class ChatbotScreen extends StatefulWidget {
  @override
  _ChatbotScreenState createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];

  late final GenerativeModel _model;
  late final ChatSession _chat;
  bool isTyping = false;

  @override
  void initState() {
    super.initState();
    _model = GenerativeModel(
      model: 'gemini-pro',
      apiKey: 'AIzaSyDv21o-mD0f6rkDTSaridF7Sw_TQPAVsMw',
    );
    _chat = _model.startChat();
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
      final response = await _chat.sendMessage(Content.text(text));
      final botText = response.text ?? '(Không có phản hồi)';

      setState(() {
        _messages.removeLast(); // Xóa 'Đang phản hồi...'
        _messages.add({'bot': botText});
        isTyping = false;
      });
    } catch (e) {
      setState(() {
        _messages.removeLast(); // Xóa 'Đang phản hồi...'
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
