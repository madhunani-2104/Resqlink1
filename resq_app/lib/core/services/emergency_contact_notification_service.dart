import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../features/auth/models/user_model.dart';
import '../constants/app_constants.dart';
import '../utils/logger.dart';

class EmergencyContactNotificationService {
  static const MethodChannel _channel = MethodChannel(
    AppConstants.channelEmergencyContacts,
  );

  // ============================================================
  // GET DEVICE CONTACTS
  // ============================================================

  static Future<List<EmergencyContact>> getDeviceContacts() async {
    if (kIsWeb) {
      return <EmergencyContact>[];
    }

    try {
      final result = await _channel.invokeMethod<List<dynamic>>(
        'getDeviceContacts',
      );

      if (result == null || result.isEmpty) {
        return <EmergencyContact>[];
      }

      final contacts = <EmergencyContact>[];

      for (final item in result) {
        if (item is! Map) {
          continue;
        }

        try {
          final map = Map<String, dynamic>.from(item);

          final name = map['name']?.toString().trim() ?? '';

          final phone = map['phone']?.toString().trim() ?? '';

          final relationship =
              map['relationship']?.toString().trim() ?? 'Emergency Contact';

          if (phone.isEmpty) {
            continue;
          }

          contacts.add(
            EmergencyContact(
              name: name.isEmpty ? 'Unknown Contact' : name,
              phone: phone,
              relationship: relationship.isEmpty
                  ? 'Emergency Contact'
                  : relationship,
            ),
          );
        } catch (e) {
          AppLogger.warning(
            'Invalid contact received from Android: $e',
            'EmergencyContactNotificationService',
          );
        }
      }

      return contacts;
    } on PlatformException catch (e) {
      AppLogger.warning(
        'Android contact error: '
            '${e.code} - ${e.message}',
        'EmergencyContactNotificationService',
      );

      return <EmergencyContact>[];
    } catch (e) {
      AppLogger.warning(
        'Unable to read device contacts: $e',
        'EmergencyContactNotificationService',
      );

      return <EmergencyContact>[];
    }
  }

  // ============================================================
  // SEND EMERGENCY SMS
  // ============================================================

  static Future<bool> notifyContacts({
    required List<EmergencyContact> contacts,
    required String senderName,
    required double latitude,
    required double longitude,
    required String sosId,
  }) async {
    if (contacts.isEmpty) {
      AppLogger.warning(
        'No emergency contacts available.',
        'EmergencyContactNotificationService',
      );

      return false;
    }

    final message =
        'ResQ SOS: $senderName needs help. '
        'Last known location: '
        '$latitude, $longitude. '
        'Alert ID: $sosId';

    if (kIsWeb) {
      AppLogger.info(
        'Emergency SMS simulated: $message',
        'EmergencyContactNotificationService',
      );

      return true;
    }

    try {
      final contactData = contacts.map((contact) => contact.toJson()).toList();

      final result = await _channel.invokeMethod<bool>(
        'sendEmergencySms',
        <String, dynamic>{'contacts': contactData, 'message': message},
      );

      return result == true;
    } on PlatformException catch (e) {
      AppLogger.warning(
        'Emergency SMS failed: '
            '${e.code} - ${e.message}',
        'EmergencyContactNotificationService',
      );

      return false;
    } catch (e) {
      AppLogger.warning(
        'Unable to send emergency SMS: $e',
        'EmergencyContactNotificationService',
      );

      return false;
    }
  }
}
