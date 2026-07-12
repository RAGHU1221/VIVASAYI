import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthNotifier extends ChangeNotifier {
  AuthNotifier._();

  static final AuthNotifier instance = AuthNotifier._();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const _tokenKey = 'jwt_token';
  static const _pinEnabledKey = 'pin_enabled';

  String? _token;
  bool _initialized = false;
  bool _pinEnabled = false;

  /// Resets to false on every cold start; set true after a successful
  /// PIN/biometric check on the app-lock screen. Gates UI access to
  /// protected routes when [pinEnabled] is true, without requiring a
  /// fresh server login (the JWT in [_token] remains valid).
  bool appUnlocked = false;

  bool get initialized => _initialized;
  bool get isAuthenticated => _token?.isNotEmpty == true;
  String? get token => _token;
  bool get pinEnabled => _pinEnabled;

  Future<void> loadToken() async {
    _token = await _storage.read(key: _tokenKey);
    _pinEnabled = (await _storage.read(key: _pinEnabledKey)) == 'true';
    _initialized = true;
    notifyListeners();
  }

  Future<void> setToken(String token) async {
    _token = token;
    await _storage.write(key: _tokenKey, value: token);
    notifyListeners();
  }

  Future<void> clearToken() async {
    _token = null;
    appUnlocked = false;
    await _storage.delete(key: _tokenKey);
    notifyListeners();
  }

  Future<void> setPinEnabled(bool enabled) async {
    _pinEnabled = enabled;
    await _storage.write(key: _pinEnabledKey, value: enabled.toString());
    if (enabled) {
      appUnlocked = false;
    }
    notifyListeners();
  }

  void markUnlocked() {
    appUnlocked = true;
    notifyListeners();
  }
}
