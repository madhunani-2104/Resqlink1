import 'dart:convert';

class FileChunk {
  final String transferId;
  final String fileName;
  final String mimeType;
  final int fileSize;
  final int index;
  final int total;
  final String data;

  const FileChunk({
    required this.transferId,
    required this.fileName,
    required this.mimeType,
    required this.fileSize,
    required this.index,
    required this.total,
    required this.data,
  });

  String get packetId => 'FILE-CHUNK-$transferId-$index';

  String toContent() =>
      'FILE_CHUNK:${jsonEncode({'transferId': transferId, 'fileName': fileName, 'mimeType': mimeType, 'fileSize': fileSize, 'index': index, 'total': total, 'data': data})}';

  static FileChunk? fromContent(String content) {
    const prefix = 'FILE_CHUNK:';
    if (!content.startsWith(prefix)) return null;

    try {
      final raw = jsonDecode(content.substring(prefix.length));
      if (raw is! Map) return null;
      final data = Map<String, dynamic>.from(raw);
      final transferId = data['transferId']?.toString() ?? '';
      final fileName = data['fileName']?.toString() ?? '';
      final chunkData = data['data']?.toString() ?? '';
      final index = int.tryParse(data['index']?.toString() ?? '') ?? -1;
      final total = int.tryParse(data['total']?.toString() ?? '') ?? 0;
      final fileSize = int.tryParse(data['fileSize']?.toString() ?? '') ?? 0;

      if (transferId.isEmpty ||
          fileName.isEmpty ||
          chunkData.isEmpty ||
          index < 0 ||
          total <= 0 ||
          index >= total ||
          fileSize < 0) {
        return null;
      }

      base64Decode(chunkData);
      return FileChunk(
        transferId: transferId,
        fileName: fileName,
        mimeType: data['mimeType']?.toString() ?? 'application/octet-stream',
        fileSize: fileSize,
        index: index,
        total: total,
        data: chunkData,
      );
    } catch (_) {
      return null;
    }
  }
}

class FileChunkAssembler {
  final FileChunk firstChunk;
  final Map<int, String> _chunks = {};

  FileChunkAssembler(this.firstChunk) {
    add(firstChunk);
  }

  bool add(FileChunk chunk) {
    if (chunk.transferId != firstChunk.transferId ||
        chunk.total != firstChunk.total ||
        chunk.fileSize != firstChunk.fileSize) {
      return false;
    }
    _chunks[chunk.index] = chunk.data;
    return true;
  }

  int get receivedCount => _chunks.length;
  int get total => firstChunk.total;
  bool get isComplete => _chunks.length == total;

  String? assembleBase64() {
    if (!isComplete) return null;
    final bytes = <int>[];
    for (var index = 0; index < total; index++) {
      final chunk = _chunks[index];
      if (chunk == null) return null;
      bytes.addAll(base64Decode(chunk));
    }
    if (bytes.length != firstChunk.fileSize) return null;
    return base64Encode(bytes);
  }
}
