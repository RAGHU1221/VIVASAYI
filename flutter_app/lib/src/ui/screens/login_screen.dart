import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_notifier.dart';
import '../../services/auth_service.dart';
import '../components/primary_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  final _authNotifier = AuthNotifier.instance;
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_phoneController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Phone and password are required.');
      return;
    }

    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    try {
      final data = await _authService.login(
        _phoneController.text.trim(),
        _passwordController.text.trim(),
      );

      final token = data['token'] as String?;
      if (token == null) {
        if (!mounted) return;
        setState(() => _errorMessage = 'Unable to login.');
      } else {
        await _authNotifier.setToken(token);
        if (!mounted) return;
        context.go('/dashboard');
      }
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = _describeError(error, 'Login failed.'));
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Login failed.');
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  String _describeError(DioException error, String fallback) {
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout) {
      return 'சர்வரை இணைக்க முடியவில்லை. இணைய இணைப்பு / சர்வர் முகவரியை சரிபார்க்கவும்.';
    }
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      if (data['message'] != null) {
        return data['message'].toString();
      }
      if (data['error'] != null) {
        return data['error'].toString();
      }
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 28.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Image.asset(
                  'assets/images/app_icon.jpg',
                  height: 96,
                ),
              ),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('வணக்கம்',
                      style:
                          TextStyle(fontSize: 34, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text(
                    'உங்கள் விவசாயத்திற்கான பாதுகாப்பான புகுபதிகை',
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                    softWrap: true,
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.04), blurRadius: 18)
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _phoneController,
                      decoration: InputDecoration(
                        labelText: 'தொலைபேசி எண்',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16)),
                        prefixIcon: const Icon(Icons.phone),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'கடவுச்சொல்',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16)),
                        prefixIcon: const Icon(Icons.lock),
                      ),
                      obscureText: true,
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(_errorMessage!,
                          style: const TextStyle(color: Colors.red)),
                    ],
                    const SizedBox(height: 24),
                    PrimaryButton(
                      label: _isLoading
                          ? 'தயவுசெய்து காத்திருங்கள்...'
                          : 'உள் நுழைய',
                      onPressed: _isLoading ? null : _login,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('புதிய பயனரா? ',
                        style: TextStyle(color: Colors.grey[700], fontSize: 16)),
                    GestureDetector(
                      onTap: () => context.push('/signup'),
                      child: const Text(
                        'பதிவு செய்க',
                        style: TextStyle(
                          color: Color(0xFF2E7D32),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('உதவி தேவையா?',
                        style: TextStyle(color: Colors.black54)),
                    const SizedBox(width: 4),
                    TextButton(
  onPressed: () => showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('உதவி & தொடர்பு'),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('📞 அழைக்க: +91 XXXXX XXXXX'),
          SizedBox(height: 8),
          Text('✉️ மின்னஞ்சல்: support@vivasayi.app'),
          SizedBox(height: 8),
          Text('🕐 நேரம்: காலை 9 - மாலை 6'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('சரி'),
        ),
      ],
    ),
  ),
  child: const Text('தொடர்பிற்கு'),
),
                       
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
