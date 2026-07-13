import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_notifier.dart';
import '../../services/auth_service.dart';
import '../../services/locale_notifier.dart';
import '../../services/translations.dart';
import '../components/primary_button.dart';

class ForgotPinScreen extends StatefulWidget {
  const ForgotPinScreen({super.key});

  @override
  State<ForgotPinScreen> createState() => _ForgotPinScreenState();
}

class _ForgotPinScreenState extends State<ForgotPinScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _verifyAndContinue() async {
    if (_phoneController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Phone and password are required.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _authService.login(
        _phoneController.text.trim(),
        _passwordController.text.trim(),
      );
      final token = data['token'] as String?;
      if (token == null) {
        if (!mounted) return;
        setState(() => _errorMessage = 'Login failed.');
        return;
      }

      await AuthNotifier.instance.setToken(token);
      if (!mounted) return;
      context.go('/pin-setup', extra: {'fromForgotPin': true});
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
      appBar: AppBar(title: Text(Translations.t(locale, 'forgot_pin.title'))),
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
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'கடவுச்சொல்',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  prefixIcon: const Icon(Icons.lock),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 20),
              PrimaryButton(
                label: _isLoading
                    ? 'தயவுசெய்து காத்திருங்கள்...'
                    : Translations.t(locale, 'forgot_pin.verify_password'),
                onPressed: _isLoading ? null : _verifyAndContinue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
