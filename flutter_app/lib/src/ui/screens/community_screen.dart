import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../services/api_client.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final TextEditingController _postController = TextEditingController();
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;
  bool _posting = false;

  Dio get _dio => ApiClient.instance.dio;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _postController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final response = await _dio.get('/posts');
      final data = response.data as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _posts = List<Map<String, dynamic>>.from(data['posts'] as List);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('பதிவுகளை ஏற்ற முடியவில்லை.')),
      );
    }
  }

  Future<void> _createPost() async {
    final content = _postController.text.trim();
    if (content.isEmpty || _posting) return;

    setState(() => _posting = true);
    try {
      await _dio.post('/posts', data: {'content': content});
      _postController.clear();
      FocusScope.of(context).unfocus();
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('பதிவிட முடியவில்லை.')),
      );
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  Future<void> _toggleLike(Map<String, dynamic> post) async {
    // Optimistic update
    final wasLiked = post['liked'] == 1 || post['liked'] == true;
    setState(() {
      post['liked'] = wasLiked ? 0 : 1;
      post['like_count'] = (int.tryParse('${post['like_count']}') ?? 0) + (wasLiked ? -1 : 1);
    });

    try {
      final response = await _dio.post('/posts/${post['id']}/like');
      final data = response.data as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        post['liked'] = data['liked'] == true ? 1 : 0;
        post['like_count'] = data['like_count'];
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        post['liked'] = wasLiked ? 1 : 0;
        post['like_count'] = (int.tryParse('${post['like_count']}') ?? 0) + (wasLiked ? 1 : -1);
      });
    }
  }

  Future<void> _deletePost(Map<String, dynamic> post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('பதிவை நீக்கவா?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('வேண்டாம்')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('நீக்கு')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _dio.delete('/posts/${post['id']}');
      _load();
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.statusCode == 404
          ? 'உங்கள் பதிவுகளை மட்டுமே நீக்க முடியும்'
          : 'நீக்க முடியவில்லை.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _reportPost(Map<String, dynamic> post) async {
    try {
      await _dio.post('/posts/${post['id']}/report');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('புகார் பதிவு செய்யப்பட்டது. நன்றி!')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('புகார் அனுப்ப முடியவில்லை.')),
      );
    }
  }

  void _openComments(Map<String, dynamic> post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _CommentsSheet(postId: post['id'] as int, onChanged: _load),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('சமூகங்கள்')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildComposer(),
                  const SizedBox(height: 16),
                  if (_posts.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Column(
                        children: [
                          Icon(Icons.forum, size: 56, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          const Center(child: Text('முதல் பதிவை நீங்களே இடுங்கள்!')),
                        ],
                      ),
                    )
                  else
                    ..._posts.map(_buildPostCard),
                ],
              ),
            ),
    );
  }

  Widget _buildComposer() {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          TextField(
            controller: _postController,
            minLines: 2,
            maxLines: 5,
            maxLength: 1000,
            decoration: const InputDecoration(
              hintText: 'விவசாய அனுபவம், கேள்வி, ஆலோசனை பகிருங்கள்...',
              border: InputBorder.none,
              counterText: '',
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: _posting ? null : _createPost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                icon: _posting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send, size: 16),
                label: const Text('பதிவிடு'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post) {
    final liked = post['liked'] == 1 || post['liked'] == true;
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: primary.withOpacity(0.12),
                child: Text(
                  '${post['author']}'.isNotEmpty ? '${post['author']}'[0] : '?',
                  style: TextStyle(color: primary, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${post['author']}',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Text(
                      '${post['created_at']}'.split(' ').first,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, size: 18, color: Colors.grey.shade600),
                onSelected: (v) {
                  if (v == 'delete') _deletePost(post);
                  if (v == 'report') _reportPost(post);
                },
                itemBuilder: (ctx) => const [
                  PopupMenuItem(value: 'report', child: Text('புகார் செய்')),
                  PopupMenuItem(value: 'delete', child: Text('நீக்கு (என் பதிவு)')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('${post['content']}', style: const TextStyle(fontSize: 14, height: 1.45)),
          const SizedBox(height: 10),
          Row(
            children: [
              InkWell(
                onTap: () => _toggleLike(post),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        liked ? Icons.favorite : Icons.favorite_border,
                        size: 18,
                        color: liked ? Colors.red : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text('${post['like_count']}',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              InkWell(
                onTap: () => _openComments(post),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 17, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text('${post['comment_count']}',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CommentsSheet extends StatefulWidget {
  final int postId;
  final VoidCallback onChanged;

  const _CommentsSheet({required this.postId, required this.onChanged});

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  bool _loading = true;
  bool _sending = false;

  Dio get _dio => ApiClient.instance.dio;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final response = await _dio.get('/posts/${widget.postId}/comments');
      final data = response.data as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _comments = List<Map<String, dynamic>>.from(data['comments'] as List);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final content = _controller.text.trim();
    if (content.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      await _dio.post('/posts/${widget.postId}/comments', data: {'content': content});
      _controller.clear();
      await _load();
      widget.onChanged();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('கருத்து இட முடியவில்லை.')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.65,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('கருத்துகள்', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _comments.isEmpty
                      ? const Center(child: Text('இன்னும் கருத்துகள் இல்லை'))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _comments.length,
                          itemBuilder: (ctx, i) {
                            final c = _comments[i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 13,
                                    backgroundColor: primary.withOpacity(0.12),
                                    child: Text(
                                      '${c['author']}'.isNotEmpty ? '${c['author']}'[0] : '?',
                                      style: TextStyle(fontSize: 12, color: primary),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('${c['author']}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600, fontSize: 12.5)),
                                        Text('${c['content']}',
                                            style: const TextStyle(fontSize: 13.5, height: 1.4)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        maxLength: 500,
                        decoration: InputDecoration(
                          hintText: 'கருத்து எழுதுங்கள்...',
                          counterText: '',
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _sending ? null : _send,
                      icon: Icon(Icons.send, color: primary),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
