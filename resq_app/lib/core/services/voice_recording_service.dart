import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../constants/app_constants.dart';
import '../utils/logger.dart';

class VoiceRecordingService {
  static const MethodChannel _channel = MethodChannel(AppConstants.channelVoiceRecorder);

  static Future<String?> startRecording() async {
    if (kIsWeb) return null;

    try {
      return await _channel.invokeMethod<String>('startRecording');
    } catch (e) {
      AppLogger.warning('Voice recording could not start: $e', 'VoiceRecordingService');
      return null;
    }
  }

  static Future<String?> stopRecording() async {
    if (kIsWeb) return null;

    try {
      return await _channel.invokeMethod<String>('stopRecording');
    } catch (e) {
      AppLogger.warning('Voice recording could not stop: $e', 'VoiceRecordingService');
      return null;
    }
  }

  static Future<String?> readRecordingBase64(String path) async {
    if (kIsWeb) return null;

    try {
      return await _channel.invokeMethod<String>('readRecordingBase64', {'path': path});
    } catch (e) {
      AppLogger.warning('Voice recording could not be encoded: $e', 'VoiceRecordingService');
      return null;
    }
  }

  static Future<bool> playBase64(String payload) async {
    if (kIsWeb) return false;

    try {
      final played = await _channel.invokeMethod<bool>('playBase64', {'payload': payload});
      return played == true;
    } catch (e) {
      AppLogger.warning('Voice message could not be played: $e', 'VoiceRecordingService');
      return false;
    }
  }
}
