import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_client.dart';

class AuthNotifier extends ChangeNotifier {
  AuthNotifier._();

  static final AuthNotifier instance = AuthNotifier._();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const _tokenKey = 'jwt_token';
  static const _pinEnabledKey = 'pin_enabled';

  /// Unga backend validate endpoint — path different na maathunga
  static const _validatePath = '/auth/validate';

  String? _token;
  bool _initialized = false;
  bool _pinEnabled = false;

  /// Resets to false on every cold start; set true after a successful
  /// PIN/biometric check on the app-lock screen.
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

    // Token irundha background la validate — await pannala,
    // adhanala app open aaga wait aagadhu (Render cold start block pannadhu)
    if (isAuthenticated) {
      _validateInBackground();
    }
  }

  /// Server kitta token valid ah nu check.
  /// 401/403 → logout. Network error / timeout / 5xx → session KEEP
  /// (Render free tier thoongittu irukkalam — user ah logout panna koodadhu).
  Future<void> _validateInBackground() async {
    try {
      final res = await ApiClient.instance.dio.get(_validatePath);
      if (res.statusCode == 401 || res.statusCode == 403) {
        debugPrint('AUTH: token rejected (${res.statusCode}) — logging out');
        await clearToken();
      }
      // 200 → valid, onnum panna vendam
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        debugPrint('AUTH: token rejected — logging out');
        await clearToken();
      } else {
        // Timeout / connection error / server sleeping —
        // logout PANNADHA. Token vachu app continue aagattum.
        debugPrint('AUTH: validate skipped (network: ${e.type}) — keeping session');
      }
    } catch (e) {
      debugPrint('AUTH: validate error ($e) — keeping session');
    }
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
