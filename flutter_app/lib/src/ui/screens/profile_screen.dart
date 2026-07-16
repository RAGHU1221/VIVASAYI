import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _authService.getProfile();
      if (!mounted) return;
      setState(() {
        final profile = result['profile'];
        _profile = profile is Map ? Map<String, dynamic>.from(profile) : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to load profile information.';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _editEmail() async {
    final controller = TextEditingController(text: '${_profile?['email'] ?? ''}' == '-' ? '' : '${_profile?['email'] ?? ''}');
    String? errorText;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('மின்னஞ்சல் புதுப்பிக்க'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.emailAddress,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'example@mail.com',
              errorText: errorText,
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('ரத்து செய்'),
            ),
            ElevatedButton(
              onPressed: () async {
                final email = controller.text.trim();
                if (email.isNotEmpty && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                  setDialogState(() => errorText = 'சரியான மின்னஞ்சலை உள்ளிடவும்');
                  return;
                }
                try {
                  final result = await _authService.updateProfile(email: email);
                  if (!mounted) return;
                  setState(() {
                    _profile = Map<String, dynamic>.from(result['profile'] as Map);
                  });
                  Navigator.of(dialogContext).pop(true);
                } on DioException catch (e) {
                  final serverMsg = (e.response?.data is Map) ? e.response?.data['error'] as String? : null;
                  setDialogState(() => errorText = serverMsg ?? 'புதுப்பிக்க முடியவில்லை. மீண்டும் முயற்சிக்கவும்.');
                } catch (_) {
                  setDialogState(() => errorText = 'புதுப்பிக்க முடியவில்லை. மீண்டும் முயற்சிக்கவும்.');
                }
              },
              child: const Text('சேமி'),
            ),
          ],
        ),
      ),
    );

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('மின்னஞ்சல் புதுப்பிக்கப்பட்டது')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: const Text('ப்ரொஃபைல்'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
                : _profile == null
                    ? const Center(child: Text('பயனர் தகவல் இல்லை.', style: TextStyle(fontSize: 16)))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 32,
                                backgroundColor: Colors.green.shade100,
                                child: const Icon(Icons.person, size: 34, color: Colors.green),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('வணக்கம், ${_profile!['name'] ?? 'விவசாயி'}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 6),
                                  Text('தொலைபேசி: ${_profile!['phone'] ?? '-'}', style: const TextStyle(color: Colors.black54)),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          _ProfileInfoCard(profile: _profile!),
                          const SizedBox(height: 24),
                          Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('கணக்கு நிலை', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  Text(_profile!['is_active'] == 1 ? 'செயலில் உள்ளது' : 'செயலில் இல்லை'),
                                  const SizedBox(height: 8),
                                  Text('சேர்ந்த தேதி: ${_profile!['created_at'] ?? '-'}'),
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

class _ProfileInfoCard extends StatelessWidget {
  final Map<String, dynamic> profile;

  const _ProfileInfoCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          children: [
            _ProfileRow(label: 'மின்னஞ்சல்', value: profile['email'] ?? '-'),
            _ProfileRow(label: 'பங்கு', value: profile['role'] ?? '-'),
            _ProfileRow(label: 'மொழி', value: profile['language'] ?? '-'),
          ],
        ),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final String label;
  final String value;

  const _ProfileRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Expanded(child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(child: Text(value, textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}
