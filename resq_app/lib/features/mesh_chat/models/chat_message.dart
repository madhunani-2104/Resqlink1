import 'dart:convert';
import '../../../core/utils/mesh_packet.dart';

class ChatAttachment {
  final String fileId;
  final String fileName;
  final String mimeType;
  final int fileSize;
  final String downloadPath;
  final String? inlineBase64;

  const ChatAttachment({
    required this.fileId,
    required this.fileName,
    required this.mimeType,
    required this.fileSize,
    required this.downloadPath,
    this.inlineBase64,
  });

  static ChatAttachment? fromContent(String content) {
    const prefix = 'FILE_ATTACHMENT:';
    if (!content.startsWith(prefix)) return null;
    try {
      final raw = jsonDecode(content.substring(prefix.length));
      if (raw is! Map) return null;
      final data = Map<String, dynamic>.from(raw);
      final fileId = data['fileId']?.toString() ?? '';
      final fileName = data['fileName']?.toString() ?? '';
      if (fileId.isEmpty || fileName.isEmpty) return null;
      return ChatAttachment(
        fileId: fileId,
        fileName: fileName,
        mimeType: data['mimeType']?.toString() ?? 'application/octet-stream',
        fileSize: (data['fileSize'] as num?)?.toInt() ?? 0,
        downloadPath: data['downloadPath']?.toString() ?? '',
        inlineBase64: data['inlineBase64']?.toString(),
      );
    } catch (_) {
      return null;
    }
  }
}

class ChatMessage {
  final String packetId;
  final String senderId;
  final String senderName;
  final String receiverId;
  final String content;
  final MeshPacketType packetType;
  final int hopCount;
  final DateTime timestamp;
  final bool isMe;
  final ChatAttachment? attachment;

  ChatMessage({
    required this.packetId,
    required this.senderId,
    required this.senderName,
    required this.receiverId,
    required this.content,
    required this.packetType,
    required this.hopCount,
    required this.timestamp,
    required this.isMe,
    this.attachment,
  });

  factory ChatMessage.fromMeshPacket(MeshPacket packet, String currentUserId) {
    return ChatMessage(
      packetId: packet.packetId,
      senderId: packet.senderId,
      senderName: packet.senderName,
      receiverId: packet.receiverId,
      content: packet.content,
      packetType: packet.packetType,
      hopCount: packet.hopCount,
      timestamp: packet.timestampSent,
      isMe: packet.senderId == currentUserId,
      attachment: ChatAttachment.fromContent(packet.content),
    );
  }
}
