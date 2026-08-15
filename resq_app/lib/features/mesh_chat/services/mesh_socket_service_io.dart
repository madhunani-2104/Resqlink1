import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/utils/logger.dart';

class MeshSocketService {
  WebSocket? _socket;
  final _messageController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onMessage => _messageController.stream;

  Future<void> connect() async {
    if (_socket?.readyState == WebSocket.open) return;

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
        onError: (error) =>
            AppLogger.warning('Mesh socket error: $error', 'MeshSocketService'),
        onDone: () =>
            AppLogger.info('Mesh socket disconnected', 'MeshSocketService'),
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

    if (message == '2') {
      _socket?.add('3');
      return;
    }

    if (message.startsWith('0')) {
      _socket?.add('40');
      return;
    }

    if (!message.startsWith('42')) return;

    try {
      final payload = jsonDecode(message.substring(2));
      if (payload is! List || payload.length < 2 || payload[1] is! Map) {
        return;
      }

      if (payload[0].toString() != 'mesh_message_received') return;
      _messageController.add(Map<String, dynamic>.from(payload[1] as Map));
    } catch (e) {
      AppLogger.warning(
        'Invalid mesh socket payload: $e',
        'MeshSocketService',
      );
    }
  }

  void disconnect() {
    _socket?.close();
    _socket = null;
  }

  void dispose() {
    disconnect();
    _messageController.close();
  }
}
