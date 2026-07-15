import 'package:dio/dio.dart';
import 'api_client.dart';

class FinanceService {
  final Dio _dio;

  FinanceService({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  Future<List<Map<String, dynamic>>> getTransactions({String? type, String? month}) async {
    final response = await _dio.get('/finance/transactions', queryParameters: {
      if (type != null) 'type': type,
      if (month != null) 'month': month,
    });
    final data = response.data as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(data['transactions'] as List);
  }

  Future<void> createTransaction(Map<String, dynamic> txn) async {
    await _dio.post('/finance/transactions', data: txn);
  }

  Future<void> updateTransaction(int id, Map<String, dynamic> txn) async {
    await _dio.put('/finance/transactions/$id', data: txn);
  }

  Future<void> deleteTransaction(int id) async {
    await _dio.delete('/finance/transactions/$id');
  }

  /// {'month': 'YYYY-MM', 'income': double, 'expense': double,
  ///  'profit': double, 'trend': [...]}
  Future<Map<String, dynamic>> getSummary() async {
    final response = await _dio.get('/finance/summary');
    return response.data as Map<String, dynamic>;
  }
}
