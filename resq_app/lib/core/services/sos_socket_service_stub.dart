import 'dart:async';

class SosSocketService {
  final _newAlertController = StreamController<Map<String, dynamic>>.broadcast();
  final _statusController = StreamController<Map<String, dynamic>>.broadcast();
  final _emergencyController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onNewAlert => _newAlertController.stream;
  Stream<Map<String, dynamic>> get onStatusUpdated => _statusController.stream;
  Stream<Map<String, dynamic>> get onEmergencyAlert => _emergencyController.stream;

  void connect({required String role}) {}

  void disconnect() {}

  void dispose() {
    _newAlertController.close();
    _statusController.close();
    _emergencyController.close();
  }
}
