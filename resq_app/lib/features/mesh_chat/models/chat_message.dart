import 'dart:convert';

import '../../../core/utils/mesh_packet.dart';

// ============================================================
// CHAT ATTACHMENT
// ============================================================

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

    if (!content.startsWith(prefix)) {
      return null;
    }

    try {
      final rawText = content.substring(prefix.length).trim();

      if (rawText.isEmpty) {
        return null;
      }

      final raw = jsonDecode(rawText);

      if (raw is! Map) {
        return null;
      }

      final data = Map<String, dynamic>.from(raw);

      final fileId = data['fileId']?.toString() ?? '';
      final fileName = data['fileName']?.toString() ?? '';

      if (fileId.isEmpty || fileName.isEmpty) {
        return null;
      }

      int fileSize = 0;

      final rawFileSize = data['fileSize'];

      if (rawFileSize is num) {
        fileSize = rawFileSize.toInt();
      } else if (rawFileSize != null) {
        fileSize = int.tryParse(rawFileSize.toString()) ?? 0;
      }

      return ChatAttachment(
        fileId: fileId,
        fileName: fileName,
        mimeType: data['mimeType']?.toString() ?? 'application/octet-stream',
        fileSize: fileSize,
        downloadPath: data['downloadPath']?.toString() ?? '',
        inlineBase64: data['inlineBase64']?.toString(),
      );
    } catch (_) {
      return null;
    }
  }
}

// ============================================================
// VOICE MESSAGE
// ============================================================

class ChatVoiceMessage {
  final String base64Audio;
  final int durationMs;
  final String mimeType;
  final String? messageId;
  final String? senderNodeId;
  final DateTime? sentAt;
  final String? fileName;

  const ChatVoiceMessage({
    required this.base64Audio,
    required this.durationMs,
    this.mimeType = 'audio/m4a',
    this.messageId,
    this.senderNodeId,
    this.sentAt,
    this.fileName,
  });

  Duration get duration {
    return Duration(milliseconds: durationMs);
  }

  String get formattedDuration {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');

    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');

    return '$minutes:$seconds';
  }

  // ----------------------------------------------------------
  // Extract JSON voice information
  // ----------------------------------------------------------

  static ChatVoiceMessage? _fromJsonString(String value) {
    try {
      final decoded = jsonDecode(value);

      if (decoded is! Map) {
        return null;
      }

      final data = Map<String, dynamic>.from(decoded);

      final audio =
          data['audio']?.toString() ??
          data['base64Audio']?.toString() ??
          data['data']?.toString() ??
          '';

      if (audio.isEmpty) {
        return null;
      }

      int durationMs = 0;

      final rawDuration = data['durationMs'];

      if (rawDuration is num) {
        durationMs = rawDuration.toInt();
      } else if (rawDuration != null) {
        durationMs = int.tryParse(rawDuration.toString()) ?? 0;
      }

      return ChatVoiceMessage(
        base64Audio: audio,
        durationMs: durationMs,
        mimeType: data['mimeType']?.toString() ?? 'audio/m4a',
        messageId: data['messageId']?.toString(),
        senderNodeId: data['senderNodeId']?.toString(),
        sentAt: DateTime.tryParse(data['timestamp']?.toString() ?? ''),
        fileName: data['fileName']?.toString(),
      );
    } catch (_) {
      return null;
    }
  }

  // ----------------------------------------------------------
  // Parse voice content
  // ----------------------------------------------------------

  static ChatVoiceMessage? fromContent(String content) {
    const prefix = 'VOICE_MESSAGE_BASE64:';

    if (!content.startsWith(prefix)) {
      return null;
    }

    try {
      final raw = content.substring(prefix.length).trim();

      if (raw.isEmpty) {
        return null;
      }

      // ------------------------------------------------------
      // FORMAT 1
      //
      // VOICE_MESSAGE_BASE64:
      // {"audio":"...","durationMs":5000}
      // ------------------------------------------------------

      final jsonVoice = _fromJsonString(raw);

      if (jsonVoice != null) {
        return jsonVoice;
      }

      // ------------------------------------------------------
      // FORMAT 2
      //
      // Base64 encoded JSON
      // ------------------------------------------------------

      try {
        final decodedBytes = base64Decode(raw);

        final decodedString = utf8.decode(decodedBytes, allowMalformed: true);

        final decodedJson = _fromJsonString(decodedString);

        if (decodedJson != null) {
          return decodedJson;
        }
      } catch (_) {
        // Continue below.
      }

      // ------------------------------------------------------
      // FORMAT 3
      //
      // Plain base64 audio
      // ------------------------------------------------------

      return ChatVoiceMessage(
        base64Audio: raw,
        durationMs: 0,
        mimeType: 'audio/m4a',
      );
    } catch (_) {
      return null;
    }
  }
}

// ============================================================
// CHAT MESSAGE
// ============================================================

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

  final ChatVoiceMessage? voiceMessage;

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
    this.voiceMessage,
  });

  factory ChatMessage.fromMeshPacket(MeshPacket packet, String currentUserId) {
    final attachment = ChatAttachment.fromContent(packet.content);

    final voiceMessage = ChatVoiceMessage.fromContent(packet.content);

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
      attachment: attachment,
      voiceMessage: voiceMessage,
    );
  }

  bool get isVoice {
    return voiceMessage != null;
  }

  bool get isFile {
    return attachment != null;
  }

  bool get isText {
    return !isVoice && !isFile;
  }
}
