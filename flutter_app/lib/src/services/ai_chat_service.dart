import 'package:dio/dio.dart';
import 'api_client.dart';

class AiChatService {
  final Dio _dio;

  AiChatService({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  /// Sends a message; returns the assistant reply text.
  Future<String> sendMessage(String message) async {
    final response = await _dio.post('/ai/chat', data: {'message': message});
    final data = response.data as Map<String, dynamic>;
    return data['reply'] as String;
  }

  /// Returns list of {'role': 'user'|'assistant', 'message': String}
  Future<List<Map<String, dynamic>>> getHistory() async {
    final response = await _dio.get('/ai/chat/history');
    final data = response.data as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(data['messages'] as List);
  }

  Future<void> clearHistory() async {
    await _dio.delete('/ai/chat/history');
  }
}
