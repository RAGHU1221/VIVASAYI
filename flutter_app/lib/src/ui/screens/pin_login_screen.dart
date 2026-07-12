import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_notifier.dart';
import '../../services/auth_service.dart';
import '../../services/locale_notifier.dart';
import '../../services/translations.dart';
import '../components/primary_button.dart';

class PinLoginScreen extends StatefulWidget {
  const PinLoginScreen({super.key});

  @override
  State<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends State<PinLoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  final AuthService _authService = AuthService();
  final _authNotifier = AuthNotifier.instance;
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_phoneController.text.trim().isEmpty || _pinController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Phone and PIN are required.');
      return;
    }

    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    try {
      final data = await _authService.pinLogin(
        _phoneController.text.trim(),
        _pinController.text.trim(),
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

  @override
  Widget build(BuildContext context) {
    final locale = LocaleNotifier.instance.locale?.languageCode ?? 'en';
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(title: Text(Translations.t(locale, 'pin.login_title'))),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'தொலைபேசி எண்',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  prefixIcon: const Icon(Icons.phone),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: Translations.t(locale, 'pin.enter_pin'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  prefixIcon: const Icon(Icons.pin),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 12),
              PrimaryButton(
                label: _isLoading ? 'தயவுசெய்து காத்திருங்கள்...' : 'உள் நுழைய',
                onPressed: _isLoading ? null : _login,
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: _isLoading ? null : () => context.go('/forgot-pin'),
                  child: Text(Translations.t(locale, 'pin.forgot')),
                ),
              ),
              Center(
                child: TextButton(
                  onPressed: _isLoading ? null : () => context.go('/login'),
                  child: const Text('OTP / கடவுச்சொல் மூலம் உள்நுழைய'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
