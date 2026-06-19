import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';

class AIChatScreen extends StatefulWidget {
  final String? symbol;
  const AIChatScreen({super.key, this.symbol});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _loading = false;
  static const String baseUrl = 'https://gse-stock-api.gabriel-dahaman.workers.dev';

  @override
  void initState() {
    super.initState();
    if (widget.symbol != null) {
      _controller.text = 'Should I buy ${widget.symbol} now?';
    }
    _messages.add({
      'role': 'ai',
      'text': 'Hi! I can help you with GSE stock analysis. Ask me about any stock — buy/sell recommendations, comparisons, or market trends.',
    });
  }

  Future<void> _sendMessage() async {
    final question = _controller.text.trim();
    if (question.isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'text': question});
      _loading = true;
    });
    _controller.clear();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/ai/chat'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'question': question}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _messages.add({'role': 'ai', 'text': data['answer'] ?? 'No response'});
        });
      } else {
        setState(() {
          _messages.add({'role': 'ai', 'text': 'Sorry, I could not process that request.'});
        });
      }
    } catch (e) {
      setState(() {
        _messages.add({'role': 'ai', 'text': 'Connection error. Please try again.'});
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Advisor'),
        backgroundColor: const Color(0xFF006B3F),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    decoration: BoxDecoration(
                      color: isUser ? const Color(0xFF006B3F) : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      msg['text'] ?? '',
                      style: TextStyle(
                        color: isUser ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(),
            ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Ask about any GSE stock...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  mini: true,
                  onPressed: _sendMessage,
                  backgroundColor: const Color(0xFF006B3F),
                  child: const Icon(Icons.send, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}