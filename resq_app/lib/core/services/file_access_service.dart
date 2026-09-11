import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';

import 'dart:typed_data';

import '../constants/app_constants.dart';
import '../utils/logger.dart';

class PickedFileInfo {
  final String path;
  final String name;
  final String mimeType;
  final int size;
  final Uint8List? bytes;

  const PickedFileInfo({
    required this.path,
    required this.name,
    required this.mimeType,
    required this.size,
    this.bytes,
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
    try {
      final file = await FilePicker.pickFile(type: FileType.any);

      if (file == null) {
        return null;
      }

      final name = _safeFileName(file.name);
      final path = file.path?.trim() ?? '';
      final bytes = kIsWeb ? await file.readAsBytes() : null;

      if (name.isEmpty || (path.isEmpty && (bytes == null || bytes.isEmpty))) {
        AppLogger.warning(
          'File picker returned an invalid file.',
          'FileAccessService',
        );
        return null;
      }

      final extension = file.extension?.toLowerCase();
      final mimeType = _mimeTypeFor(extension);
      final size = bytes?.length ?? await file.length();

      return PickedFileInfo(
        path: path,
        name: name,
        mimeType: mimeType,
        size: size,
        bytes: bytes,
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

  static String _safeFileName(String value) {
    final leaf = value.replaceAll('\\', '/').split('/').last.trim();
    return leaf.replaceAll(RegExp(r'[^A-Za-z0-9._ -]'), '_');
  }

  static String _mimeTypeFor(String? extension) {
    const known = <String, String>{
      'pdf': 'application/pdf',
      'txt': 'text/plain',
      'csv': 'text/csv',
      'json': 'application/json',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'mp3': 'audio/mpeg',
      'm4a': 'audio/mp4',
      'wav': 'audio/wav',
      'mp4': 'video/mp4',
      'zip': 'application/zip',
    };
    return known[extension] ?? 'application/octet-stream';
  }
}
