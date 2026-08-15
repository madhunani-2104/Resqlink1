import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../features/auth/models/user_model.dart';
import '../constants/app_constants.dart';
import '../utils/logger.dart';

class EmergencyContactNotificationService {
  static const MethodChannel _channel = MethodChannel(AppConstants.channelEmergencyContacts);

  static Future<List<EmergencyContact>> getDeviceContacts() async {
    if (kIsWeb) return [];

    try {
      final result = await _channel.invokeMethod<List<dynamic>>('getDeviceContacts');
      return (result ?? [])
          .whereType<Map>()
          .map((item) => EmergencyContact.fromJson(Map<String, dynamic>.from(item)))
          .where((contact) => contact.phone.isNotEmpty)
          .toList();
    } catch (e) {
      AppLogger.warning('Unable to read device contacts: $e', 'EmergencyContactNotificationService');
      return [];
    }
  }

  static Future<void> notifyContacts({
    required List<EmergencyContact> contacts,
    required String senderName,
    required double latitude,
    required double longitude,
    required String sosId,
  }) async {
    if (contacts.isEmpty) return;

    final message =
        'ResQ SOS: $senderName needs help. Last known location: $latitude, $longitude. Alert ID: $sosId';

    if (kIsWeb) {
      AppLogger.info('Emergency contact notification simulated: $message', 'EmergencyContactNotificationService');
      return;
    }

    try {
      await _channel.invokeMethod('sendEmergencySms', {
        'contacts': contacts.map((contact) => contact.toJson()).toList(),
        'message': message,
      });
    } catch (e) {
      AppLogger.warning('Unable to send emergency SMS notifications: $e', 'EmergencyContactNotificationService');
    }
  }
}
