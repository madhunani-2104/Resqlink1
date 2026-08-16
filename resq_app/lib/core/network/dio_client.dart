import 'package:dio/dio.dart';

import '../constants/api_endpoints.dart';
import '../services/preference_service.dart';

class DioClient {
  static final DioClient _instance = DioClient._internal();

  factory DioClient() {
    return _instance;
  }

  late final Dio _dio;

  DioClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiEndpoints.baseUrl,

        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 60),

        headers: <String, dynamic>{
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },

        responseType: ResponseType.json,

        validateStatus: (status) {
          return status != null && status >= 200 && status < 500;
        },
      ),
    );

    // ============================================================
    // AUTHENTICATION INTERCEPTOR
    // ============================================================

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            final token = await PreferenceService.getAuthToken();

            if (token != null && token.trim().isNotEmpty) {
              options.headers['Authorization'] = 'Bearer ${token.trim()}';
            }
          } catch (_) {
            // Continue request even if token lookup fails.
          }

          handler.next(options);
        },
      ),
    );

    // ============================================================
    // LOGGING
    // ============================================================

    _dio.interceptors.add(
      LogInterceptor(
        request: true,
        requestHeader: true,
        requestBody: true,
        responseHeader: true,
        responseBody: true,
        error: true,
      ),
    );
  }

  // ============================================================
  // INSTANCE
  // ============================================================

  Dio get instance => _dio;

  // ============================================================
  // GET
  // ============================================================

  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException {
      rethrow;
    }
  }

  // ============================================================
  // POST
  // ============================================================

  Future<Response<dynamic>> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException {
      rethrow;
    }
  }

  // ============================================================
  // PUT
  // ============================================================

  Future<Response<dynamic>> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException {
      rethrow;
    }
  }

  // ============================================================
  // DELETE
  // ============================================================

  Future<Response<dynamic>> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException {
      rethrow;
    }
  }

  // ============================================================
  // PATCH
  // ============================================================

  Future<Response<dynamic>> patch(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.patch(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException {
      rethrow;
    }
  }

  // ============================================================
  // DOWNLOAD
  // ============================================================

  Future<Response<dynamic>> download(
    String urlPath,
    String savePath, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      return await _dio.download(
        urlPath,
        savePath,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      );
    } on DioException {
      rethrow;
    }
  }

  // ============================================================
  // ERROR MESSAGE
  // ============================================================

  String getErrorMessage(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        return 'Connection timed out. Please check that the backend server is running and your phone is connected to the same network.';

      case DioExceptionType.sendTimeout:
        return 'Request sending timed out. Please check your network connection.';

      case DioExceptionType.receiveTimeout:
        return 'Server response timed out. Please check that the backend server is responding.';

      case DioExceptionType.badCertificate:
        return 'The server certificate could not be verified.';

      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;

        final responseData = error.response?.data;

        if (responseData is Map) {
          final message = responseData['message'];

          if (message != null && message.toString().trim().isNotEmpty) {
            return message.toString();
          }
        }

        if (statusCode != null) {
          return 'Server returned HTTP $statusCode.';
        }

        return 'The server returned an invalid response.';

      case DioExceptionType.cancel:
        return 'The request was cancelled.';

      case DioExceptionType.connectionError:
        return 'Could not connect to the server. Make sure the backend is running and the phone can reach the server.';

      case DioExceptionType.unknown:
        return error.message ?? 'An unexpected network error occurred.';

      case DioExceptionType.transformTimeout:
        return 'The server response took too long to process.';
    }
  }
}
