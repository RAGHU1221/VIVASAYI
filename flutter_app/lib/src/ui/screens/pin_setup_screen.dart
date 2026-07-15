import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_notifier.dart';
import '../../services/auth_service.dart';
import '../../services/locale_notifier.dart';
import '../../services/translations.dart';
import '../components/primary_button.dart';

class PinSetupScreen extends StatefulWidget {
  /// True when reached from the forgot-PIN flow (a fresh OTP-issued token is
  /// already set) rather than from Settings on an already-unlocked app.
  final bool fromForgotPin;

  const PinSetupScreen({super.key, this.fromForgotPin = false});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  final AuthService _authService = AuthService();
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _savePin() async {
    final locale = LocaleNotifier.instance.locale?.languageCode ?? 'en';
    final pin = _pinController.text.trim();
    final confirm = _confirmController.text.trim();

    if (!RegExp(r'^\d{4,6}$').hasMatch(pin)) {
      setState(() => _errorMessage = Translations.t(locale, 'pin.enter_pin'));
      return;
    }

    if (pin != confirm) {
      setState(() => _errorMessage = Translations.t(locale, 'pin.mismatch'));
      return;
    }

    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    try {
      await _authService.setPin(pin);
      await AuthNotifier.instance.setPinEnabled(true);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Translations.t(locale, 'pin.set_success'))),
      );

      if (widget.fromForgotPin) {
        context.go('/dashboard');
      } else {
        context.go('/settings');
      }
    } on DioException catch (error) {
      final message = error.response?.data is Map<String, dynamic>
          ? error.response?.data['error']?.toString() ?? 'Unable to save PIN.'
          : 'Unable to save PIN.';
      if (!mounted) return;
      setState(() => _errorMessage = message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Unable to save PIN.');
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
      appBar: AppBar(title: Text(Translations.t(locale, 'pin.setup_title'))),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              TextField(
                controller: _confirmController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: Translations.t(locale, 'pin.confirm_pin'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  prefixIcon: const Icon(Icons.pin_outlined),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 12),
              PrimaryButton(
                label: _isLoading ? 'தயவுசெய்து காத்திருங்கள்...' : 'சேமி',
                onPressed: _isLoading ? null : _savePin,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
