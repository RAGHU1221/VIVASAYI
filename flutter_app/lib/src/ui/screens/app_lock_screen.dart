import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_notifier.dart';
import '../../services/auth_service.dart';
import '../../services/biometric_service.dart';
import '../../services/locale_notifier.dart';
import '../../services/translations.dart';
import '../components/primary_button.dart';

class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  final TextEditingController _pinController = TextEditingController();
  final AuthService _authService = AuthService();
  final BiometricService _biometricService = BiometricService();
  bool _biometricAvailable = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    final available = await _biometricService.isAvailable();
    if (!mounted) return;
    setState(() => _biometricAvailable = available);
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  void _unlock() {
    AuthNotifier.instance.markUnlocked();
    context.go('/dashboard');
  }

  Future<void> _verifyPin() async {
    final locale = LocaleNotifier.instance.locale?.languageCode ?? 'en';
    final pin = _pinController.text.trim();
    if (pin.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final ok = await _authService.verifyPin(pin);
      if (!mounted) return;
      if (ok) {
        _unlock();
      } else {
        setState(() => _errorMessage = Translations.t(locale, 'app_lock.incorrect'));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = Translations.t(locale, 'app_lock.incorrect'));
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _useBiometric() async {
    final ok = await _biometricService.authenticate();
    if (!mounted) return;
    if (ok) {
      _unlock();
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = LocaleNotifier.instance.locale?.languageCode ?? 'en';
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 56, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Text(Translations.t(locale, 'app_lock.title'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onSubmitted: (_) => _verifyPin(),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 12),
              PrimaryButton(
                label: _isLoading ? 'தயவுசெய்து காத்திருங்கள்...' : 'உறுதிசெய்',
                onPressed: _isLoading ? null : _verifyPin,
              ),
              if (_biometricAvailable) ...[
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _useBiometric,
                  icon: const Icon(Icons.fingerprint),
                  label: Text(Translations.t(locale, 'app_lock.use_biometric')),
                ),
              ],
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.go('/forgot-pin'),
                child: Text(Translations.t(locale, 'pin.forgot')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
