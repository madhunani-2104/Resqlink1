import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/utils/logger.dart';
import '../models/rescue_activity_model.dart';

class RescueActivityProvider extends ChangeNotifier {
  final DioClient _dioClient = DioClient();

  bool _isLoading = false;
  String? _errorMessage;
  List<RescueActivityModel> _activities = [];

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<RescueActivityModel> get activities => List.unmodifiable(_activities);

  Future<void> loadActivities() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _dioClient.instance.get(
        ApiEndpoints.rescueActivities,
      );
      final responseData = response.data;
      if (responseData is! Map<String, dynamic> ||
          responseData['success'] != true ||
          responseData['data'] is! List) {
        throw Exception('Unable to load rescue activity records.');
      }

      _activities = (responseData['data'] as List)
          .whereType<Map>()
          .map(
            (activity) => RescueActivityModel.fromJson(
              Map<String, dynamic>.from(activity),
            ),
          )
          .toList();
    } on DioException catch (e) {
      _errorMessage = e.response?.statusCode == 401
          ? 'Your session has expired. Please sign in again.'
          : 'Unable to load rescue activity records. Please check your connection.';
      AppLogger.error(
        'Failed to load rescue activity records',
        e,
        e.stackTrace,
        'RescueActivityProvider',
      );
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      AppLogger.error(
        'Failed to load rescue activity records',
        e,
        null,
        'RescueActivityProvider',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
