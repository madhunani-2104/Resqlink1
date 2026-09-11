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
  Future<FileUploadResult?> upload({
    required String path,
    required String receiverId,
  }) async => null;
  Future<String?> download({
    required String fileId,
    required String fileName,
  }) async => null;
  Future<String?> readInlineBase64(String path, {int maxBytes = 65536}) async =>
      null;
  Future<List<int>?> readBytes(String path, {int maxBytes = 5242880}) async =>
      null;
  Future<String?> writeInlineBase64(String base64Data, String fileName) async =>
      null;
}
