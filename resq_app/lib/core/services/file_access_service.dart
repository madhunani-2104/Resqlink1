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
  static const MethodChannel _channel = MethodChannel(
    AppConstants.channelFileAccess,
  );

  // ============================================================
  // PICK FILE
  // ============================================================

  static Future<PickedFileInfo?> pickFile() async {
    if (kIsWeb) {
      return null;
    }

    try {
      final raw = await _channel.invokeMethod<dynamic>('pickFile');

      if (raw == null) {
        return null;
      }

      if (raw is! Map) {
        AppLogger.warning('Invalid file picker response.', 'FileAccessService');
        return null;
      }

      final data = Map<String, dynamic>.from(raw);

      final path = data['path']?.toString().trim() ?? '';
      final name = data['name']?.toString().trim() ?? '';

      if (path.isEmpty || name.isEmpty) {
        AppLogger.warning(
          'File picker returned an invalid file.',
          'FileAccessService',
        );
        return null;
      }

      final mimeType =
          data['mimeType']?.toString().trim() ?? 'application/octet-stream';

      final dynamic rawSize = data['size'];

      int size = 0;

      if (rawSize is num) {
        size = rawSize.toInt();
      } else if (rawSize != null) {
        size = int.tryParse(rawSize.toString()) ?? 0;
      }

      return PickedFileInfo(
        path: path,
        name: name,
        mimeType: mimeType.isEmpty ? 'application/octet-stream' : mimeType,
        size: size,
      );
    } on PlatformException catch (e) {
      AppLogger.warning(
        'File selection failed: ${e.message}',
        'FileAccessService',
      );

      return null;
    } catch (e) {
      AppLogger.warning('File selection failed: $e', 'FileAccessService');

      return null;
    }
  }

  // ============================================================
  // OPEN FILE
  // ============================================================

  static Future<bool> openFile(String path, String mimeType) async {
    if (kIsWeb) {
      return false;
    }

    if (path.trim().isEmpty) {
      return false;
    }

    try {
      final result = await _channel.invokeMethod<dynamic>(
        'openFile',
        <String, dynamic>{
          'path': path,
          'mimeType': mimeType.isEmpty ? 'application/octet-stream' : mimeType,
        },
      );

      return result == true;
    } on PlatformException catch (e) {
      AppLogger.warning('File open failed: ${e.message}', 'FileAccessService');

      return false;
    } catch (e) {
      AppLogger.warning('File open failed: $e', 'FileAccessService');

      return false;
    }
  }
}
