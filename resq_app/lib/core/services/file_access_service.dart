import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../constants/app_constants.dart';
import '../utils/logger.dart';

class PickedFileInfo {
  final String path;
  final String name;
  final String mimeType;
  final int size;

  const PickedFileInfo({
    required this.path,
    required this.name,
    required this.mimeType,
    required this.size,
  });
}

class FileAccessService {
  static const MethodChannel _channel = MethodChannel(AppConstants.channelFileAccess);

  static Future<PickedFileInfo?> pickFile() async {
    if (kIsWeb) return null;
    try {
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>('pickFile');
      if (raw == null) return null;
      final data = Map<String, dynamic>.from(raw);
      final path = data['path']?.toString() ?? '';
      final name = data['name']?.toString() ?? '';
      if (path.isEmpty || name.isEmpty) return null;
      return PickedFileInfo(
        path: path,
        name: name,
        mimeType: data['mimeType']?.toString() ?? 'application/octet-stream',
        size: (data['size'] as num?)?.toInt() ?? 0,
      );
    } catch (e) {
      AppLogger.warning('File selection failed: $e', 'FileAccessService');
      return null;
    }
  }

  static Future<bool> openFile(String path, String mimeType) async {
    if (kIsWeb) return false;
    try {
      final result = await _channel.invokeMethod<bool>('openFile', {
        'path': path,
        'mimeType': mimeType,
      });
      return result == true;
    } catch (e) {
      AppLogger.warning('File open failed: $e', 'FileAccessService');
      return false;
    }
  }
}
