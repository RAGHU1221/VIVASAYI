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
    if (_phoneController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
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
      final message = error.response?.data is Map<String, dynamic>
          ? error.response?.data['error']?.toString() ?? 'Login failed.'
          : 'Login failed.';
      if (!mounted) return;
      setState(() => _errorMessage = message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Login failed.');
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendOtp() async {
    if (_phoneController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Phone number is required for OTP.');
      return;
    }

    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    try {
      await _authService.requestOtp(_phoneController.text.trim());
      if (!mounted) return;
      context.go('/otp', extra: {'phone': _phoneController.text.trim()});
    } on DioException catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Unable to request OTP.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Unable to request OTP.');
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
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
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('வணக்கம்', style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Text('உங்கள் விவசாயத்திற்கான பாதுகாப்பான புகுபதிகை', style: TextStyle(fontSize: 16, color: Colors.black54)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 18)],
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _phoneController,
                      decoration: InputDecoration(
                        labelText: 'தொலைபேசி எண்',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        prefixIcon: const Icon(Icons.phone),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'கடவுச்சொல்',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        prefixIcon: const Icon(Icons.lock),
                      ),
                      obscureText: true,
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                    ],
                    const SizedBox(height: 24),
                    PrimaryButton(
                      label: _isLoading ? 'தயவுசெய்து காத்திருங்கள்...' : 'உள் நுழைய',
                      onPressed: _isLoading ? null : _login,
                    ),
                    const SizedBox(height: 14),
                    PrimaryButton(
                      label: 'OTP அனுப்பு',
                      onPressed: _isLoading ? null : _sendOtp,
                      isPrimary: false,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('உதவி தேவைவா?', style: TextStyle(color: Colors.black54)),
                  const SizedBox(width: 4),
                  TextButton(onPressed: () {}, child: const Text('தொடர்பிற்கு')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
