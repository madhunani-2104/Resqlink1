import 'dart:async';

class MeshSocketService {
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onMessage => _messageController.stream;

  Future<void> connect() async {}

  void disconnect() {}

  void dispose() {
    _messageController.close();
  }
}
