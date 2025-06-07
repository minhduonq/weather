import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class WeatherChatbot extends StatefulWidget {
  const WeatherChatbot({super.key});

  @override
  State<WeatherChatbot> createState() => _WeatherChatbotState();
}

class _WeatherChatbotState extends State<WeatherChatbot>
    with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  String _streamingMessage = '';
  late AnimationController _typingAnimationController;

  @override
  void initState() {
    super.initState();
    _typingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    // Add welcome message
    _messages.add(ChatMessage(
      text: "Xin chào! Tôi là trợ lý thời tiết AI. Tôi có thể giúp bạn kiểm tra thời tiết hiện tại, dự báo hàng giờ/hàng ngày và đưa ra gợi ý trang phục phù hợp. Bạn muốn biết thời tiết ở đâu?",
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _typingAnimationController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _isLoading) return;

    final userMessage = _messageController.text;
    _messageController.clear();

    setState(() {
      _messages.add(ChatMessage(
        text: userMessage,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
      _streamingMessage = '';
    });

    _scrollToBottom();

    try {
      final uid = 'user_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
      
      final response = await http.post(
        Uri.parse('http://localhost:8000/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'uid': uid,
          'message': userMessage,
        }),
      );

      if (response.statusCode == 200) {
        final responseBody = response.body;
        String accumulatedText = '';
        
        final chunks = responseBody.split('');
        for (int i = 0; i < chunks.length; i++) {
          if (mounted) {
            accumulatedText += chunks[i];
            setState(() {
              _streamingMessage = accumulatedText;
            });
            await Future.delayed(const Duration(milliseconds: 10));
          }
        }

        setState(() {
          _messages.add(ChatMessage(
            text: accumulatedText,
            isUser: false,
            timestamp: DateTime.now(),
          ));
          _streamingMessage = '';
        });
      } else {
        setState(() {
          _messages.add(ChatMessage(
            text: 'Xin lỗi, đã có lỗi xảy ra. Vui lòng thử lại sau.',
            isUser: false,
            timestamp: DateTime.now(),
            isError: true,
          ));
        });
      }
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          text: 'Không thể kết nối đến server. Vui lòng kiểm tra kết nối mạng.',
          isUser: false,
          timestamp: DateTime.now(),
          isError: true,
        ));
      });
    } finally {
      setState(() {
        _isLoading = false;
        _streamingMessage = '';
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onQuickSuggestion(String suggestion) {
    setState(() {
      _messageController.text = suggestion;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF0F9FF), // sky-50
              Color(0xFFDBEAFE), // blue-100
            ],
          ),
        ),
        child: Column(
          children: [
            // Header - Giảm padding
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x1F000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // Giảm padding
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        icon: const Icon(
                          Icons.arrow_back_ios,
                          color: Color(0xFF1F2937),
                          size: 20,
                        ),
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.all(8), 
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF0EA5E9), Color(0xFF2563EB)],
                          ),
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                        ),
                        child: const Icon(
                          Icons.assistant,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Weather Assistant',
                              style: TextStyle(
                                fontSize: 18, 
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                            Text(
                              'Trợ lý thời tiết AI thông minh',
                              style: TextStyle(
                                fontSize: 12, 
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

        
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // Giảm padding
                itemCount: _messages.length + (_isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length) {
                    return _buildStreamingMessage();
                  }
                  return _messages[index];
                },
              ),
            ),

            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x1F000000),
                    blurRadius: 8,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // Giảm padding
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!_isLoading) ...[
                        SizedBox(
                          height: 32, 
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              'Thời tiết Hà Nội hôm nay',
                              'Dự báo 7 ngày tới',
                              'Gợi ý trang phục',
                              'Thời tiết theo giờ',
                            ]
                                .map((suggestion) => Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: ActionChip(
                                        label: Text(
                                          suggestion,
                                          style: const TextStyle(
                                            color: Color(0xFF0369A1),
                                            fontSize: 11,
                                          ),
                                        ),
                                        onPressed: () =>
                                            _onQuickSuggestion(suggestion),
                                        backgroundColor: const Color(0xFFE0F2FE),
                                        side: BorderSide.none,
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    ))
                                .toList(),
                          ),
                        ),
                        const SizedBox(height: 8), 
                      ],

                      // Input Row
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(20), 
                                border: Border.all(
                                  color: const Color(0xFFE5E7EB),
                                ),
                              ),
                              child: TextField(
                                controller: _messageController,
                                decoration: const InputDecoration(
                                  hintText: 'Hỏi về thời tiết...',
                                  hintStyle: TextStyle(
                                    color: Color(0xFF9CA3AF),
                                    fontSize: 14,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16, 
                                    vertical: 10,   
                                  ),
                                  suffixIcon: Icon(
                                    Icons.wb_sunny_outlined,
                                    color: Color(0xFF9CA3AF),
                                    size: 20,
                                  ),
                                ),
                                maxLines: null,
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) => _sendMessage(),
                                enabled: !_isLoading,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF0EA5E9), Color(0xFF2563EB)],
                              ),
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0EA5E9).withOpacity(0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(22),
                                onTap: _isLoading ? null : _sendMessage,
                                child: Center(
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        )
                                      : const Icon(
                                          Icons.send,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreamingMessage() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12), 
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32, 
            height: 32,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF059669)],
              ),
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
            child: const Icon(
              Icons.assistant,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 8), 
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12), 
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_streamingMessage.isNotEmpty)
                    Text(
                      _streamingMessage,
                      style: const TextStyle(
                        color: Color(0xFF1F2937),
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: _typingAnimationController,
                        builder: (context, child) {
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(3, (index) {
                              final delay = index * 0.3;
                              final opacity = ((_typingAnimationController.value + delay) % 1.0 > 0.5) ? 1.0 : 0.3;
                              return Container(
                                margin: const EdgeInsets.only(right: 3),
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0EA5E9).withOpacity(opacity),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              );
                            }),
                          );
                        },
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Đang trả lời...',
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage extends StatelessWidget {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isError;

  const ChatMessage({
    super.key,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12), 
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32, 
              height: 32,
              decoration: BoxDecoration(
                gradient: isError
                    ? const LinearGradient(
                        colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                      )
                    : const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                      ),
                borderRadius: const BorderRadius.all(Radius.circular(16)),
              ),
              child: const Icon(
                Icons.assistant,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 8), 
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12), 
              decoration: BoxDecoration(
                gradient: isUser
                    ? const LinearGradient(
                        colors: [Color(0xFF0EA5E9), Color(0xFF2563EB)],
                      )
                    : null,
                color: isUser
                    ? null
                    : isError
                        ? const Color(0xFFFEF2F2)
                        : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: isUser
                    ? null
                    : Border.all(
                        color: isError
                            ? const Color(0xFFFECACA)
                            : const Color(0xFFE5E7EB),
                      ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    text,
                    style: TextStyle(
                      color: isUser
                          ? Colors.white
                          : isError
                              ? const Color(0xFF991B1B)
                              : const Color(0xFF1F2937),
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6), 
                  Text(
                    _formatTime(timestamp),
                    style: TextStyle(
                      color: isUser
                          ? const Color(0xFFBFDBFE)
                          : const Color(0xFF6B7280),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8), /
            Container(
              width: 32, 
              height: 32,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0EA5E9), Color(0xFF2563EB)],
                ),
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
              child: const Icon(
                Icons.person,
                color: Colors.white,
                size: 16,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }
}