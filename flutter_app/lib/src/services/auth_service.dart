import 'package:dio/dio.dart';
import 'api_client.dart';

class AuthService {
  final Dio _dio;

  AuthService({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  Future<Map<String, dynamic>> login(String phone, String password) async {
    final response = await _dio.post('/auth/login', data: {
      'phone': phone,
      'password': password,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> signup(String name, String phone, String password) async {
    final response = await _dio.post('/auth/signup', data: {
      'name': name,
      'phone': phone,
      'password': password,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getProfile() async {
    final response = await _dio.get('/profile');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getFarms() async {
    final response = await _dio.get('/profile/farms');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getFarm(int id) async {
    final response = await _dio.get('/farms/$id');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getStats() async {
    final response = await _dio.get('/profile/stats');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createFarm(Map<String, dynamic> farmData) async {
    final response = await _dio.post('/farms', data: farmData);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateFarm(int id, Map<String, dynamic> farmData) async {
    final response = await _dio.put('/farms/$id', data: farmData);
    return response.data as Map<String, dynamic>;
  }

  Future<void> deleteFarm(int id) async {
    await _dio.delete('/farms/$id');
  }

  Future<Map<String, dynamic>> pinLogin(String phone, String pin) async {
    final response = await _dio.post('/auth/pin/login', data: {
      'phone': phone,
      'pin': pin,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> setPin(String pin) async {
    final response = await _dio.post('/profile/pin', data: {'pin': pin});
    return response.data as Map<String, dynamic>;
  }

  Future<bool> verifyPin(String pin) async {
    try {
      await _dio.post('/profile/pin/verify', data: {'pin': pin});
      return true;
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        return false;
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getSessions() async {
    final response = await _dio.get('/profile/sessions');
    return List<Map<String, dynamic>>.from(response.data as List);
  }

  Future<void> revokeSession(int id) async {
    await _dio.delete('/profile/sessions/$id');
  }

  Future<List<Map<String, dynamic>>> getSecurityLogs() async {
    final response = await _dio.get('/profile/security-logs');
    return List<Map<String, dynamic>>.from(response.data as List);
  }
}
