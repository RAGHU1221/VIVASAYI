import 'package:dio/dio.dart';
import 'api_client.dart';

class DiaryService {
  final Dio _dio;

  DiaryService({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  Future<List<Map<String, dynamic>>> getEntries({String? month}) async {
    final response = await _dio.get('/diary', queryParameters: {
      if (month != null) 'month': month,
    });
    final data = response.data as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(data['entries'] as List);
  }

  Future<void> createEntry(Map<String, dynamic> entry) async {
    await _dio.post('/diary', data: entry);
  }

  Future<void> updateEntry(int id, Map<String, dynamic> entry) async {
    await _dio.put('/diary/$id', data: entry);
  }

  Future<void> deleteEntry(int id) async {
    await _dio.delete('/diary/$id');
  }
}
