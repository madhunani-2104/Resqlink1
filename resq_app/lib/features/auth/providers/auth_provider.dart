import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

import '../models/user_model.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/services/preference_service.dart';
import '../../../core/utils/logger.dart';

enum AuthStatus {
  unauthenticated,
  authenticating,
  authenticated,
  error,
}

class AuthProvider extends ChangeNotifier {
  final DioClient _dioClient = DioClient();

  AuthStatus _status = AuthStatus.unauthenticated;
  UserModel? _user;
  String? _errorMessage;

  AuthStatus get status => _status;
  UserModel? get user => _user;
  String? get errorMessage => _errorMessage;

  bool get isAuthenticated =>
      _status == AuthStatus.authenticated && _user != null;

  AuthProvider() {
    checkSavedAuth();
  }

  Future<void> checkSavedAuth() async {
    try {
      final token = await PreferenceService.getAuthToken();
      final userData = await PreferenceService.getUserData();

      if (token != null && userData != null) {
        _user = UserModel.fromJson(userData);
        _status = AuthStatus.authenticated;
        notifyListeners();
      }
    } catch (e) {
      AppLogger.error(
        'Failed to load saved user session',
        e,
        null,
        'AuthProvider',
      );
    }
  }

  Future<bool> login(String email, String password) async {
    _status = AuthStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _dioClient.instance.post(
        ApiEndpoints.login,
        data: {
          'email': email,
          'password': password,
        },
      );

      if (response.data['success'] == true) {
        _user = UserModel.fromJson(response.data['data']);

        await PreferenceService.setAuthToken(
          _user!.token ?? '',
        );

        await PreferenceService.setUserData(
          _user!.toJson(),
        );

        _status = AuthStatus.authenticated;
        notifyListeners();

        return true;
      }

      _errorMessage = response.data['message']?.toString() ?? 'Login failed';

      _status = AuthStatus.error;
      notifyListeners();

      return false;
    } catch (e) {
      _errorMessage = _parseError(e);

      _status = AuthStatus.error;
      notifyListeners();

      return false;
    }
  }

  Future<bool> rescueLogin(
    String email,
    String password,
  ) async {
    _status = AuthStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _dioClient.instance.post(
        ApiEndpoints.rescueLogin,
        data: {
          'email': email,
          'password': password,
        },
      );

      if (response.data['success'] == true) {
        _user = UserModel.fromJson(response.data['data']);

        await PreferenceService.setAuthToken(
          _user!.token ?? '',
        );

        await PreferenceService.setUserData(
          _user!.toJson(),
        );

        _status = AuthStatus.authenticated;
        notifyListeners();

        return true;
      }

      _errorMessage =
          response.data['message']?.toString() ?? 'Rescue team login failed';

      _status = AuthStatus.error;
      notifyListeners();

      return false;
    } catch (e) {
      _errorMessage = _parseError(e);

      _status = AuthStatus.error;
      notifyListeners();

      return false;
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    _status = AuthStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _dioClient.instance.post(
        ApiEndpoints.register,
        data: {
          'name': name,
          'email': email,
          'phone': phone,
          'password': password,
          // 'role' intentionally NOT sent — backend always assigns 'user' for public registration
        },
      );

      if (response.data['success'] == true) {
        _user = UserModel.fromJson(response.data['data']);

        await PreferenceService.setAuthToken(
          _user!.token ?? '',
        );

        await PreferenceService.setUserData(
          _user!.toJson(),
        );

        _status = AuthStatus.authenticated;
        notifyListeners();

        return true;
      }

      _errorMessage =
          response.data['message']?.toString() ?? 'Registration failed';

      _status = AuthStatus.error;
      notifyListeners();

      return false;
    } catch (e) {
      _errorMessage = _parseError(e);

      _status = AuthStatus.error;
      notifyListeners();

      return false;
    }
  }

  Future<bool> rescueRegister({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String accessCode,
  }) async {
    _status = AuthStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _dioClient.instance.post(
        ApiEndpoints.rescueRegister,
        data: {
          'name': name,
          'email': email,
          'phone': phone,
          'password': password,
          'accessCode': accessCode,
        },
      );

      if (response.data['success'] == true) {
        _user = UserModel.fromJson(response.data['data']);

        await PreferenceService.setAuthToken(
          _user!.token ?? '',
        );

        await PreferenceService.setUserData(
          _user!.toJson(),
        );

        _status = AuthStatus.authenticated;
        notifyListeners();

        return true;
      }

      _errorMessage = response.data['message']?.toString() ??
          'Rescue team registration failed';

      _status = AuthStatus.error;
      notifyListeners();

      return false;
    } catch (e) {
      _errorMessage = _parseError(e);

      _status = AuthStatus.error;
      notifyListeners();

      return false;
    }
  }

  Future<bool> forgotPassword(String email) async {
    try {
      final response = await _dioClient.instance.post(
        ApiEndpoints.forgotPassword,
        data: {
          'email': email,
        },
      );

      return response.data['success'] == true;
    } catch (e) {
      _errorMessage = _parseError(e);
      notifyListeners();

      return false;
    }
  }

  Future<bool> resetPassword(String email, String resetCode, String newPassword) async {
    _status = AuthStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _dioClient.instance.post(
        ApiEndpoints.resetPassword,
        data: {
          'email': email,
          'resetCode': resetCode,
          'newPassword': newPassword,
        },
      );

      if (response.data['success'] == true) {
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return true;
      }

      _errorMessage = response.data['message']?.toString() ?? 'Password reset failed';
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = _parseError(e);
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await PreferenceService.clearAll();

    _user = null;
    _status = AuthStatus.unauthenticated;

    notifyListeners();
  }

  String _parseError(dynamic e) {
    if (e is DioException) {
      // Log the exact Dio error.
      AppLogger.error(
        'Dio Error Type: ${e.type}',
        e,
        e.stackTrace,
        'AuthProvider',
      );

      AppLogger.error(
        'Dio Error Message: ${e.message}',
        e,
        e.stackTrace,
        'AuthProvider',
      );

      AppLogger.error(
        'Request URL: ${e.requestOptions.uri}',
        e,
        e.stackTrace,
        'AuthProvider',
      );

      // Server actually responded.
      if (e.response != null) {
        final statusCode = e.response?.statusCode;
        final responseData = e.response?.data;

        AppLogger.error(
          'Response Status: $statusCode',
          e,
          e.stackTrace,
          'AuthProvider',
        );

        AppLogger.error(
          'Response Data: $responseData',
          e,
          e.stackTrace,
          'AuthProvider',
        );

        if (responseData is Map && responseData['message'] != null) {
          return responseData['message'].toString();
        }

        return 'Server returned HTTP $statusCode';
      }

      // No response from server.
      return 'Connection error: '
          '${e.message ?? e.type.name}';
    }

    return 'Unexpected error: ${e.toString()}';
  }
}
