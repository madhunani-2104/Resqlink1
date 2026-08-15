import '../utils/logger.dart';

class NotificationService {
  static Future<void> initialize() async {
    AppLogger.info('Notification Service Initialized.', 'NotificationService');
  }

  static void showEmergencySosAlert({
    required String victimName,
    required String locationText,
    required String sosId,
  }) {
    AppLogger.info('🔔 EMERGENCY SOS ALERT: Victim $victimName at $locationText (ID: $sosId)', 'NotificationService');
  }

  static void showMeshMessageReceived({
    required String senderName,
    required String text,
  }) {
    AppLogger.info('💬 Mesh Message from $senderName: $text', 'NotificationService');
  }
}
