import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/utils/logger.dart';

class MeshSocketService {
  WebSocket? _socket;

  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onMessage => _messageController.stream;

  Future<void> connect() async {
    if (_socket?.readyState == WebSocket.open) {
      return;
    }

    try {
      final socketUrl = ApiEndpoints.baseUrl
          .replaceFirst('/api', '')
          .replaceFirst('http://', 'ws://')
          .replaceFirst('https://', 'wss://');

      _socket = await WebSocket.connect(
        '$socketUrl/socket.io/?EIO=4&transport=websocket',
      );

      _socket!.listen(
        _handleMessage,
        onError: (error) {
          AppLogger.warning('Mesh socket error: $error', 'MeshSocketService');
        },
        onDone: () {
          AppLogger.info('Mesh socket disconnected', 'MeshSocketService');
        },
        cancelOnError: false,
      );
    } catch (e) {
      AppLogger.warning(
        'Unable to connect mesh socket: $e',
        'MeshSocketService',
      );
    }
  }

  void _handleMessage(dynamic rawMessage) {
    final message = rawMessage.toString();

    // Socket.IO ping
    if (message == '2') {
      _socket?.add('3');
      return;
    }

    // Engine.IO open
    if (message.startsWith('0')) {
      _socket?.add('40');
      return;
    }

    // Only Socket.IO event packets
    if (!message.startsWith('42')) {
      return;
    }

    try {
      final payload = jsonDecode(message.substring(2));

      if (payload is! List || payload.length < 2 || payload[1] is! Map) {
        return;
      }

      final event = payload[0].toString();

      if (event != 'mesh_message_received') {
        return;
      }

      final data = Map<String, dynamic>.from(payload[1] as Map);

      _messageController.add(data);
    } catch (e) {
      AppLogger.warning('Invalid mesh socket payload: $e', 'MeshSocketService');
    }
  }

  void disconnect() {
    _socket?.close();
    _socket = null;
  }

  void dispose() {
    disconnect();

    if (!_messageController.isClosed) {
      _messageController.close();
    }
  }
}
