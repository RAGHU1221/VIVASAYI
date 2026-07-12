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
  final TextEditingController _otpController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _otpRequested = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    if (_phoneController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Phone number is required.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.requestOtp(_phoneController.text.trim());
      if (!mounted) return;
      setState(() => _otpRequested = true);
    } on DioException catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Unable to request OTP.');
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOtpAndContinue() async {
    if (_otpController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'OTP code is required.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _authService.verifyOtp(
        _phoneController.text.trim(),
        _otpController.text.trim(),
      );
      final token = data['token'] as String?;
      if (token == null) {
        if (!mounted) return;
        setState(() => _errorMessage = 'OTP verification failed.');
        return;
      }

      await AuthNotifier.instance.setToken(token);
      if (!mounted) return;
      context.go('/pin-setup', extra: {'fromForgotPin': true});
    } on DioException catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'OTP verification failed.');
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
                enabled: !_otpRequested,
                decoration: InputDecoration(
                  labelText: 'தொலைபேசி எண்',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  prefixIcon: const Icon(Icons.phone),
                ),
              ),
              if (_otpRequested) ...[
                const SizedBox(height: 20),
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'OTP குறியீடு',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 20),
              PrimaryButton(
                label: _isLoading
                    ? 'தயவுசெய்து காத்திருங்கள்...'
                    : Translations.t(locale, _otpRequested ? 'forgot_pin.verify_otp' : 'forgot_pin.request_otp'),
                onPressed: _isLoading ? null : (_otpRequested ? _verifyOtpAndContinue : _requestOtp),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
