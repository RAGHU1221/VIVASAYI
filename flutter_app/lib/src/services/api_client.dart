import 'package:dio/dio.dart';
import 'auth_notifier.dart';

class ApiClient {
  ApiClient._() {
    const apiBaseUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://vivasayi.onrender.com',
    );

    _dio = Dio(BaseOptions(
      baseUrl: apiBaseUrl,
      // Render free tier cold start ~50s aagum — adhanala 60s timeout
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
      sendTimeout: const Duration(seconds: 60),
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = AuthNotifier.instance.token;
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        // 401 mattum dhan token clear — server confirm panna reject.
        // Timeout / connection error na token thoda koodadhu
        // (Render thoongittu irukkalam).
        if (error.response?.statusCode == 401) {
          await AuthNotifier.instance.clearToken();
        }
        handler.next(error);
      },
    ));
  }

  static final ApiClient instance = ApiClient._();
  late final Dio _dio;

  Dio get dio => _dio;

  /// Network error ah (retry pannalam) vs server rejection ah nu check panna.
  /// Auth check catch block la idha use pannunga.
  static bool isNetworkError(DioException e) {
    return e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.unknown;
  }

  /// Render cold-start wake-up ping — main() la await illama call pannunga.
  void warmUp() {
    _dio
        .get('/api/ping')
        .catchError((_) => Response(requestOptions: RequestOptions(path: '/api/ping')));
  }
}
