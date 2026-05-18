import 'package:flutter/material.dart';
import 'package:loansense_ai/core/theme.dart';
import 'package:loansense_ai/data/repositories/loan_repository.dart';

class ChatScreen extends StatefulWidget {
  final String loanId;
  const ChatScreen({super.key, required this.loanId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<Map<String, String>> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final LoanRepository _repository = LoanRepository();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _addSystemMessage("Loan analyzed! I can explain the clauses, detect hidden charges, or translate details into Hindi. What would you like to know?");
  }

  void _addSystemMessage(String text) {
    setState(() {
      _messages.add({"role": "assistant", "content": text});
    });
  }

  Future<void> _sendMessage() async {
    if (_controller.text.isEmpty) return;

    String userQuery = _controller.text;
    setState(() {
      _messages.add({"role": "user", "content": userQuery});
      _controller.clear();
      _isLoading = true;
    });

    try {
      final response = await _repository.chatWithLoan(widget.loanId, userQuery);
      setState(() {
        _messages.add({"role": "assistant", "content": response['answer']});
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _messages.add({"role": "assistant", "content": "Error: ${e.toString()}"});
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LOAN INTELLIGENCE'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                bool isUser = msg['role'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isUser ? AppTheme.primaryGold : AppTheme.cardGrey,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isUser ? 16 : 0),
                        bottomRight: Radius.circular(isUser ? 0 : 16),
                      ),
                    ),
                    child: Text(
                      msg['content']!,
                      style: TextStyle(
                        color: isUser ? Colors.black : Colors.white,
                        fontSize: 15,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: LinearProgressIndicator(color: AppTheme.accentCyan, backgroundColor: Colors.transparent),
            ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppTheme.cardGrey,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Ask about hidden charges...',
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  onPressed: _sendMessage,
                  icon: const Icon(Icons.send_rounded, color: AppTheme.accentCyan),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
