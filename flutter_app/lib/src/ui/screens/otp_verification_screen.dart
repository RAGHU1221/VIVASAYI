import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_notifier.dart';
import '../../services/auth_service.dart';
import '../components/primary_button.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String? initialPhone;

  const OtpVerificationScreen({super.key, this.initialPhone});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final AuthService _authService = AuthService();
  final _authNotifier = AuthNotifier.instance;
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialPhone != null) {
      _phoneController.text = widget.initialPhone!;
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    if (_phoneController.text.trim().isEmpty || _otpController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Phone and OTP code are required.');
      return;
    }

    setState(() {
      _errorMessage = null;
      _isLoading = true;
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
      } else {
        await _authNotifier.setToken(token);
        if (!mounted) return;
        context.go('/dashboard');
      }
    } on DioException catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'OTP verification failed.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'OTP verification failed.');
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _resendOtp() async {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    try {
      await _authService.requestOtp(_phoneController.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP resent successfully.')),
      );
    } on DioException catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Unable to resend OTP.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Unable to resend OTP.');
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: const Text('OTP உறுதிபடுத்துதல்'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('உங்கள் தொலைபேசிக்கு அனுப்பப்பட்ட OTP ஐ உள்ளிடவும்', style: TextStyle(fontSize: 18)),
              const SizedBox(height: 24),
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
                controller: _otpController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'OTP குறியீடு',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 20),
              PrimaryButton(
                label: _isLoading ? 'தயவுசெய்து காத்திருங்கள்...' : 'உறுதிசெய் & தொடரவும்',
                onPressed: _isLoading ? null : _verifyOtp,
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: _isLoading ? null : _resendOtp,
                  child: const Text('OTP மறுபடியும் அனுப்பு'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
