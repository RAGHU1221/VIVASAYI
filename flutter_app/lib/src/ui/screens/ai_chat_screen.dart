import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../services/ai_chat_service.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _ChatMessage {
  final String role; // 'user' | 'assistant'
  final String text;
  _ChatMessage(this.role, this.text);
}

class _AiChatScreenState extends State<AiChatScreen> {
  final AiChatService _service = AiChatService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<_ChatMessage> _messages = [];
  bool _loadingHistory = true;
  bool _sending = false;

  static const _welcomeText =
      'வணக்கம்! நான் உங்கள் விவசாய AI உதவியாளர். பயிர், நோய், உரம், நீர் மேலாண்மை, அரசு திட்டங்கள் பற்றி எதுவும் கேளுங்கள்!';

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final history = await _service.getHistory();
      if (!mounted) return;
      setState(() {
        _messages.clear();
        for (final m in history) {
          _messages.add(_ChatMessage(m['role'] as String, m['message'] as String));
        }
        _loadingHistory = false;
      });
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingHistory = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    _controller.clear();
    setState(() {
      _messages.add(_ChatMessage('user', text));
      _sending = true;
    });
    _scrollToBottom();

    try {
      final reply = await _service.sendMessage(text);
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage('assistant', reply));
        _sending = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      String errorText = 'பதில் பெற முடியவில்லை. மீண்டும் முயற்சிக்கவும்.';
      final data = e.response?.data;
      if (data is Map && data['error'] is String) {
        errorText = data['error'] as String;
      }
      setState(() {
        _messages.add(_ChatMessage('assistant', '⚠️ $errorText'));
        _sending = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage('assistant', '⚠️ பதில் பெற முடியவில்லை. மீண்டும் முயற்சிக்கவும்.'));
        _sending = false;
      });
    }
    _scrollToBottom();
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('உரையாடலை அழிக்கவா?'),
        content: const Text('எல்லா செய்திகளும் நீக்கப்படும். இதை மீட்டெடுக்க முடியாது.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('வேண்டாம்')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('அழி')),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _service.clearHistory();
        if (!mounted) return;
        setState(() => _messages.clear());
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('அழிக்க முடியவில்லை. மீண்டும் முயற்சிக்கவும்.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI உதவியாளர்'),
        actions: [
          if (_messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'உரையாடலை அழி',
              onPressed: _confirmClear,
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loadingHistory
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + 1 + (_sending ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _Bubble(role: 'assistant', text: _welcomeText, primary: primary);
                      }
                      final msgIndex = index - 1;
                      if (msgIndex < _messages.length) {
                        final m = _messages[msgIndex];
                        return _Bubble(role: m.role, text: m.text, primary: primary);
                      }
                      return _TypingIndicator(primary: primary);
                    },
                  ),
          ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'உங்கள் கேள்வியை எழுதுங்கள்...',
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: primary,
                    child: IconButton(
                      icon: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: _sending ? null : _send,
                    ),
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

class _Bubble extends StatelessWidget {
  final String role;
  final String text;
  final Color primary;

  const _Bubble({required this.role, required this.text, required this.primary});

  @override
  Widget build(BuildContext context) {
    final isUser = role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: isUser ? primary : Colors.green.shade50,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isUser ? Colors.white : Colors.black87,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  final Color primary;

  const _TypingIndicator({required this.primary});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: primary),
            ),
            const SizedBox(width: 10),
            const Text('யோசிக்கிறேன்...', style: TextStyle(fontSize: 13, color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}
