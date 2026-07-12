import 'dart:io';

import 'package:dio/dio.dart';
import 'api_client.dart';

class DiseaseScanResult {
  final bool modelBundled;
  final String? predictedLabel;
  final double? confidence;

  const DiseaseScanResult({
    required this.modelBundled,
    this.predictedLabel,
    this.confidence,
  });
}

class DiseaseScanService {
  final Dio _dio;

  DiseaseScanService({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  /// Runs on-device inference against the bundled TFLite model, if present.
  ///
  /// No model is bundled with this repo yet (see flutter_app/docs/disease-scanner.md) —
  /// this returns a stub result so the capture -> review -> save flow can be exercised
  /// end-to-end before a real model is dropped into assets/models/.
  Future<DiseaseScanResult> predict(File image) async {
    // TODO: once a .tflite model is added to assets/models/, load it via
    // package:tflite_flutter and run real inference here instead of the stub below.
    return const DiseaseScanResult(modelBundled: false);
  }

  Future<Map<String, dynamic>> saveScan({
    required String imagePath,
    String? predictedLabel,
    double? confidence,
    String? modelVersion,
    int? farmId,
  }) async {
    final response = await _dio.post('/disease-scans', data: {
      'image_path': imagePath,
      'predicted_label': predictedLabel,
      'confidence': confidence,
      'model_version': modelVersion,
      'farm_id': farmId,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getScans({int? farmId}) async {
    final response = await _dio.get('/disease-scans', queryParameters: {
      if (farmId != null) 'farm_id': farmId,
    });
    return List<Map<String, dynamic>>.from(response.data as List);
  }
}
