import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'api_client.dart';

class DiseaseAnalysisResult {
  final String label;
  final String solution;

  const DiseaseAnalysisResult({required this.label, required this.solution});
}

class DiseaseScanService {
  final Dio _dio;

  DiseaseScanService({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  /// படத்தை base64-ah encode panni backend-ku anuppி, AI vision model
  /// (NVIDIA Build) mூலம் நோய் + தீர்வு பெறும். Backend-லேயே DB-ல save
  /// aagi, saved record return aagும் — appuram vera saveScan() call
  /// pண்ண தேவை இல்லை.
  Future<Map<String, dynamic>> analyze(File image, {int? farmId}) async {
    final bytes = await image.readAsBytes();
    final base64Image = base64Encode(bytes);

    final ext = image.path.split('.').last.toLowerCase();
    final mime = (ext == 'png') ? 'image/png' : 'image/jpeg';

    final response = await _dio.post(
      '/disease-scans/analyze',
      data: {
        'image_base64': base64Image,
        'mime': mime,
        if (farmId != null) 'farm_id': farmId,
      },
      options: Options(sendTimeout: const Duration(seconds: 60), receiveTimeout: const Duration(seconds: 60)),
    );
    return response.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getScans({int? farmId}) async {
    final response = await _dio.get('/disease-scans', queryParameters: {
      if (farmId != null) 'farm_id': farmId,
    });
    return List<Map<String, dynamic>>.from(response.data as List);
  }
}
