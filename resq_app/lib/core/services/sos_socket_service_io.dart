import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../constants/api_endpoints.dart';
import 'preference_service.dart';
import '../utils/logger.dart';

class SosSocketService {
  WebSocket? _socket;
  String? _authToken;

  final StreamController<Map<String, dynamic>> _newAlertController =
      StreamController<Map<String, dynamic>>.broadcast();

  final StreamController<Map<String, dynamic>> _statusController =
      StreamController<Map<String, dynamic>>.broadcast();

  final StreamController<Map<String, dynamic>> _emergencyController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onNewAlert => _newAlertController.stream;

  Stream<Map<String, dynamic>> get onStatusUpdated => _statusController.stream;

  Stream<Map<String, dynamic>> get onEmergencyAlert =>
      _emergencyController.stream;

  Future<void> connect({required String role}) async {
    if (_socket?.readyState == WebSocket.open) {
      return;
    }

    try {
      final socketUrl = ApiEndpoints.baseUrl
          .replaceFirst('/api', '')
          .replaceFirst('http://', 'ws://')
          .replaceFirst('https://', 'wss://');

      _authToken = await PreferenceService.getAuthToken();

      _socket = await WebSocket.connect(
        '$socketUrl/socket.io/?EIO=4&transport=websocket',
      );

      _socket!.listen(
        (message) {
          _handleSocketMessage(message.toString(), role);
        },
        onError: (error) {
          AppLogger.warning('SOS socket error: $error', 'SosSocketService');
        },
        onDone: () {
          AppLogger.info('SOS socket disconnected', 'SosSocketService');
        },
        cancelOnError: false,
      );
    } catch (e) {
      AppLogger.warning('Unable to connect SOS socket: $e', 'SosSocketService');
    }
  }

  void _handleSocketMessage(String message, String role) {
    // Engine.IO ping
    if (message == '2') {
      _socket?.add('3');
      return;
    }

    // Engine.IO open
    if (message.startsWith('0')) {
      _socket?.add('40');
      return;
    }

    // Socket.IO connected
    if (message.startsWith('40')) {
      if (role == 'rescue_team') {
        _emit('join_rescue_team');
      } else if (role == 'admin') {
        _emit('join_admin');
      } else if (role == 'user') {
        _emit('join_user');
      }

      return;
    }

    // Ignore non-event packets.
    if (!message.startsWith('42')) {
      return;
    }

    try {
      final payload = jsonDecode(message.substring(2));

      if (payload is! List || payload.length < 2 || payload[1] is! Map) {
        return;
      }

      final event = payload[0].toString();

      final data = Map<String, dynamic>.from(payload[1] as Map);

      switch (event) {
        case 'new_sos_alert':
          _newAlertController.add(data);
          break;

        case 'sos_emergency_alert':
          _emergencyController.add(data);
          break;

        case 'sos_status_updated':
          _statusController.add(data);
          break;
      }
    } catch (e) {
      AppLogger.warning('Invalid SOS socket payload: $e', 'SosSocketService');
    }
  }

  void _emit(String event) {
    final payload = jsonEncode([event, _authToken]);

    _socket?.add('42$payload');
  }

  void disconnect() {
    _socket?.close();
    _socket = null;
  }

  void dispose() {
    disconnect();

    if (!_newAlertController.isClosed) {
      _newAlertController.close();
    }

    if (!_statusController.isClosed) {
      _statusController.close();
    }

    if (!_emergencyController.isClosed) {
      _emergencyController.close();
    }
  }
}
