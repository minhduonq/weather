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
      text:
          "Xin chào! Tôi là trợ lý thời tiết AI. Tôi có thể giúp bạn kiểm tra thời tiết hiện tại, dự báo hàng giờ/hàng ngày và đưa ra gợi ý trang phục phù hợp. Bạn muốn biết thời tiết ở đâu?",
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
      final uid =
          'user_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';

      final response = await http.post(
        Uri.parse('http://localhost:8000/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'uid': uid,
          'message': userMessage,
        }),
      );

      if (response.statusCode == 200) {
        // Handle streaming response
        final responseBody = response.body;
        String accumulatedText = '';

        // Simulate streaming by processing chunks
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
            // Header
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
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF0EA5E9), Color(0xFF2563EB)],
                          ),
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                        child: const Icon(
                          Icons.assistant,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Weather Assistant',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          Text(
                            'Trợ lý thời tiết AI thông minh',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Chat Messages
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length + (_isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length) {
                    return _buildStreamingMessage();
                  }
                  return _messages[index];
                },
              ),
            ),

            // Input Area
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
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Quick Suggestions
                      if (!_isLoading) ...[
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              'Thời tiết Hà Nội hôm nay',
                              'Dự báo 7 ngày tới',
                              'Gợi ý trang phục',
                              'Thời tiết theo giờ',
                            ]
                                .map((suggestion) => Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: ActionChip(
                                        label: Text(
                                          suggestion,
                                          style: const TextStyle(
                                            color: Color(0xFF0369A1),
                                            fontSize: 12,
                                          ),
                                        ),
                                        onPressed: () =>
                                            _onQuickSuggestion(suggestion),
                                        backgroundColor:
                                            const Color(0xFFE0F2FE),
                                        side: BorderSide.none,
                                      ),
                                    ))
                                .toList(),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Input Row
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: const Color(0xFFE5E7EB),
                                ),
                              ),
                              child: TextField(
                                controller: _messageController,
                                decoration: const InputDecoration(
                                  hintText:
                                      'Hỏi về thời tiết, dự báo hoặc gợi ý trang phục...',
                                  hintStyle: TextStyle(
                                    color: Color(0xFF9CA3AF),
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                  suffixIcon: Icon(
                                    Icons.wb_sunny_outlined,
                                    color: Color(0xFF9CA3AF),
                                  ),
                                ),
                                maxLines: null,
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) => _sendMessage(),
                                enabled: !_isLoading,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF0EA5E9), Color(0xFF2563EB)],
                              ),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      const Color(0xFF0EA5E9).withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(24),
                                onTap: _isLoading ? null : _sendMessage,
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    Colors.white),
                                          ),
                                        )
                                      : const Icon(
                                          Icons.send,
                                          color: Colors.white,
                                          size: 24,
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
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF059669)],
              ),
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
            child: const Icon(
              Icons.assistant,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
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
                children: [
                  if (_streamingMessage.isNotEmpty)
                    Text(
                      _streamingMessage,
                      style: const TextStyle(
                        color: Color(0xFF1F2937),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      AnimatedBuilder(
                        animation: _typingAnimationController,
                        builder: (context, child) {
                          return Row(
                            children: List.generate(3, (index) {
                              final delay = index * 0.3;
                              final opacity =
                                  ((_typingAnimationController.value + delay) %
                                              1.0 >
                                          0.5)
                                      ? 1.0
                                      : 0.3;
                              return Container(
                                margin: const EdgeInsets.only(right: 4),
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0EA5E9)
                                      .withOpacity(opacity),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              );
                            }),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Đang trả lời...',
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 12,
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
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: isError
                    ? const LinearGradient(
                        colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                      )
                    : const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                      ),
                borderRadius: const BorderRadius.all(Radius.circular(20)),
              ),
              child: const Icon(
                Icons.assistant,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(16),
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
                borderRadius: BorderRadius.circular(16),
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
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatTime(timestamp),
                    style: TextStyle(
                      color: isUser
                          ? const Color(0xFFBFDBFE)
                          : const Color(0xFF6B7280),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 12),
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0EA5E9), Color(0xFF2563EB)],
                ),
                borderRadius: BorderRadius.all(Radius.circular(20)),
              ),
              child: const Icon(
                Icons.person,
                color: Colors.white,
                size: 20,
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
