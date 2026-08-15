import 'package:flutter/foundation.dart';
import '../../auth/models/user_model.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/services/preference_service.dart';
import '../../../core/utils/logger.dart';

class ProfileProvider extends ChangeNotifier {
  final DioClient _dioClient = DioClient();
  bool _isLoading = false;

  bool get isLoading => _isLoading;

  Future<bool> updateMedicalInfo(UserModel currentUser, MedicalInfo newMedicalInfo) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _dioClient.instance.put(
        ApiEndpoints.updateProfile,
        data: {
          'medicalInfo': newMedicalInfo.toJson(),
        },
      );

      if (response.data['success'] == true) {
        final updatedUser = UserModel.fromJson(response.data['data']);
        await PreferenceService.setUserData(updatedUser.toJson());
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      AppLogger.error('Failed to update medical info', e, null, 'ProfileProvider');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> updateEmergencyContacts(UserModel currentUser, List<EmergencyContact> contacts) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _dioClient.instance.put(
        ApiEndpoints.updateProfile,
        data: {
          'emergencyContacts': contacts.map((c) => c.toJson()).toList(),
        },
      );

      if (response.data['success'] == true) {
        final updatedUser = UserModel.fromJson(response.data['data']);
        await PreferenceService.setUserData(updatedUser.toJson());
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      AppLogger.error('Failed to update emergency contacts', e, null, 'ProfileProvider');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }
}
