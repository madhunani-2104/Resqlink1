import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:resq_app/features/mesh_chat/models/chat_message.dart';

void main() {
  test('parses structured voice metadata from a mesh payload', () {
    final payload = base64Encode(
      utf8.encode(
        jsonEncode({
          'version': 1,
          'mimeType': 'audio/mp4',
          'fileName': 'voice_123.m4a',
          'durationMs': 4200,
          'messageId': 'VOICE-123',
          'senderNodeId': 'node-a',
          'timestamp': '2026-09-11T10:00:00.000Z',
          'audio': base64Encode(<int>[1, 2, 3]),
        }),
      ),
    );

    final message = ChatVoiceMessage.fromContent(
      'VOICE_MESSAGE_BASE64:$payload',
    );

    expect(message, isNotNull);
    expect(message!.durationMs, 4200);
    expect(message.fileName, 'voice_123.m4a');
    expect(message.messageId, 'VOICE-123');
    expect(message.senderNodeId, 'node-a');
    expect(message.sentAt, DateTime.parse('2026-09-11T10:00:00.000Z'));
    expect(message.base64Audio, base64Encode(<int>[1, 2, 3]));
  });

  test('rejects an empty voice payload', () {
    expect(ChatVoiceMessage.fromContent('VOICE_MESSAGE_BASE64:'), isNull);
  });
}
