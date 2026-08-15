import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../constants/api_endpoints.dart';
import '../services/preference_service.dart';
import '../utils/logger.dart';

class DioClient {
  late final Dio _dio;

  DioClient() {
    final String base = kIsWeb ? ApiEndpoints.webBaseUrl : ApiEndpoints.baseUrl;

    _dio = Dio(
      BaseOptions(
        baseUrl: base,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await PreferenceService.getAuthToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          AppLogger.debug('HTTP Req: ${options.method} ${options.path}', 'DioClient');
          return handler.next(options);
        },
        onResponse: (response, handler) {
          AppLogger.debug('HTTP Res [${response.statusCode}]: ${response.requestOptions.path}', 'DioClient');
          return handler.next(response);
        },
        onError: (DioException e, handler) {
          AppLogger.error('HTTP Error: ${e.message} at ${e.requestOptions.path}', e, e.stackTrace, 'DioClient');
          return handler.next(e);
        },
      ),
    );
  }

  Dio get instance => _dio;
}
