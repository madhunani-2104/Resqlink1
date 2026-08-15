import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../network/dio_client.dart';
import '../constants/api_endpoints.dart';
import '../utils/logger.dart';

class FileUploadResult {
  final String fileId;
  final String name;
  final String mimeType;
  final int size;
  final String downloadPath;

  const FileUploadResult({
    required this.fileId,
    required this.name,
    required this.mimeType,
    required this.size,
    required this.downloadPath,
  });
}

class FileTransferService {
  final DioClient _dioClient = DioClient();

  Future<FileUploadResult?> upload({required String path, required String receiverId}) async {
    try {
      final file = File(path);
      if (!await file.exists()) return null;

      final response = await _dioClient.instance.post(
        ApiEndpoints.uploadMeshFile,
        data: FormData.fromMap({
          'receiverId': receiverId,
          'file': await MultipartFile.fromFile(path, filename: path.split(Platform.pathSeparator).last),
        }),
        options: Options(contentType: 'multipart/form-data'),
      );

      if (response.data is! Map || response.data['success'] != true) return null;
      final data = Map<String, dynamic>.from(response.data['data'] as Map);
      return FileUploadResult(
        fileId: data['fileId']?.toString() ?? '',
        name: data['name']?.toString() ?? path.split(Platform.pathSeparator).last,
        mimeType: data['mimeType']?.toString() ?? 'application/octet-stream',
        size: (data['size'] as num?)?.toInt() ?? await file.length(),
        downloadPath: data['downloadPath']?.toString() ?? '',
      );
    } catch (e) {
      AppLogger.warning('File upload failed: $e', 'FileTransferService');
      return null;
    }
  }

  Future<String?> readInlineBase64(String path, {int maxBytes = 65536}) async {
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      final size = await file.length();
      if (size > maxBytes) return null;
      return base64Encode(await file.readAsBytes());
    } catch (_) {
      return null;
    }
  }

  Future<String?> writeInlineBase64(String base64Data, String fileName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final safeName = fileName.replaceAll(RegExp(r'[\/:*?"<>|]'), '_');
      final output = File('${directory.path}/$safeName');
      await output.writeAsBytes(base64Decode(base64Data));
      return output.path;
    } catch (_) {
      return null;
    }
  }

  Future<String?> download({required String fileId, required String fileName}) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final safeName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final output = File('${directory.path}/$safeName');
      await _dioClient.instance.download(
        ApiEndpoints.downloadMeshFile(fileId),
        output.path,
      );
      return output.path;
    } catch (e) {
      AppLogger.warning('File download failed: $e', 'FileTransferService');
      return null;
    }
  }
}
