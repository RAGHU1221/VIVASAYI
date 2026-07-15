import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_notifier.dart';
import '../../services/auth_service.dart';
import '../components/primary_button.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  final AuthService _authService = AuthService();
  final _authNotifier = AuthNotifier.instance;
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();
    final confirm = _confirmController.text.trim();

    if (name.isEmpty || phone.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'அனைத்து விவரங்களையும் நிரப்பவும்.');
      return;
    }
    if (phone.length != 10) {
      setState(() => _errorMessage = 'தொலைபேசி எண் 10 இலக்கங்களாக இருக்க வேண்டும்.');
      return;
    }
    if (password.length < 6) {
      setState(() => _errorMessage = 'கடவுச்சொல் குறைந்தது 6 எழுத்துகள் இருக்க வேண்டும்.');
      return;
    }
    if (password != confirm) {
      setState(() => _errorMessage = 'கடவுச்சொற்கள் பொருந்தவில்லை.');
      return;
    }

    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    try {
      final data = await _authService.signup(name, phone, password);

      final token = data['token'] as String?;
      if (token != null) {
        await _authNotifier.setToken(token);
        if (!mounted) return;
        context.go('/dashboard');
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('பதிவு வெற்றி! உள்நுழையவும்.')),
        );
        context.go('/login');
      }
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = _describeError(error, 'பதிவு தோல்வியடைந்தது.'));
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'பதிவு தோல்வியடைந்தது.');
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
    if (data is Map<String, dynamic> && data['error'] != null) {
      return data['error'].toString();
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
                  Text('புதிய கணக்கு',
                      style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text(
                    'உங்கள் விவசாய பயணத்தை தொடங்குங்கள்',
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
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 18)
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'பெயர்',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16)),
                        prefixIcon: const Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 18),
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
                    const SizedBox(height: 18),
                    TextField(
                      controller: _confirmController,
                      decoration: InputDecoration(
                        labelText: 'கடவுச்சொல்லை உறுதிப்படுத்தவும்',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16)),
                        prefixIcon: const Icon(Icons.lock_outline),
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
                          : 'பதிவு செய்க',
                      onPressed: _isLoading ? null : _signup,
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
                    Text('ஏற்கனவே கணக்கு உள்ளதா? ',
                        style: TextStyle(color: Colors.grey[700], fontSize: 16)),
                    GestureDetector(
                      onTap: () => context.go('/login'),
                      child: const Text(
                        'உள் நுழைய',
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
            ],
          ),
        ),
      ),
    );
  }
}
