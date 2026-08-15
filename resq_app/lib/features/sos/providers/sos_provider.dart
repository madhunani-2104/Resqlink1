import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/sos_model.dart';
import '../../auth/models/user_model.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/emergency_contact_notification_service.dart';
import '../../../core/services/sos_socket_service.dart';
import '../../../core/database/db_helper.dart';
import '../../../core/utils/mesh_packet.dart';
import '../../../core/utils/risk_predictor.dart';
import '../../../core/utils/logger.dart';

class SosProvider extends ChangeNotifier {
  final DioClient _dioClient = DioClient();
  bool _isSosActive = false;
  SosModel? _activeSos;
  List<SosModel> _activeSosList = [];
  bool _isLoading = false;
  final SosSocketService _socketService = SosSocketService();
  StreamSubscription<Map<String, dynamic>>? _newAlertSubscription;
  StreamSubscription<Map<String, dynamic>>? _statusSubscription;
  StreamSubscription<Map<String, dynamic>>? _emergencySubscription;
  Timer? _rescueRefreshTimer;

  bool get isSosActive => _isSosActive;
  SosModel? get activeSos => _activeSos;
  List<SosModel> get activeSosList => _activeSosList;
  bool get isLoading => _isLoading;

  void connectRescueAlertStream({required String role}) {
    if (role != 'rescue_team' && role != 'admin') return;
    _socketService.connect(role: role);
    _newAlertSubscription ??= _socketService.onNewAlert.listen((data) {
      final alert = SosModel.fromJson(data);
      _activeSosList.removeWhere((item) => item.sosId == alert.sosId);
      _activeSosList.insert(0, alert);
      notifyListeners();
    });
    _statusSubscription ??= _socketService.onStatusUpdated.listen((data) {
      final alert = SosModel.fromJson(data);
      final index = _activeSosList.indexWhere((item) => item.sosId == alert.sosId);
      if (index >= 0) {
        _activeSosList[index] = alert;
      } else {
        _activeSosList.insert(0, alert);
      }
      notifyListeners();
    });
    _rescueRefreshTimer ??= Timer.periodic(
      const Duration(seconds: 15),
      (_) => fetchActiveSosAlerts(),
    );
  }

  void connectUserEmergencyAlertStream({required String userId}) {
    if (userId.isEmpty) return;
    _socketService.connect(role: 'user');
    _emergencySubscription ??= _socketService.onEmergencyAlert.listen((data) {
      final alert = SosModel.fromJson(data);
      _activeSosList.removeWhere((item) => item.sosId == alert.sosId);
      _activeSosList.insert(0, alert);
      notifyListeners();
    });
  }

  /// Trigger One-Tap Emergency SOS Signal
  Future<SosModel?> triggerSos({
    required String userId,
    required String userName,
    required String userPhone,
    List<EmergencyContact> emergencyContacts = const [],
    Future<void> Function(MeshPacket packet)? broadcastMeshPacket,
    String notes = '',
    String severity = 'CRITICAL',
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final Position? pos = await LocationService.getCurrentPosition();
      if (pos == null) {
        AppLogger.warning(
          'SOS was not sent because a current GPS position could not be obtained.',
          'SosProvider',
        );
        _isLoading = false;
        notifyListeners();
        return null;
      }

      final double lat = pos.latitude;
      final double lng = pos.longitude;
      final double alt = pos.altitude;
      final double accuracy = pos.accuracy;

      final String sosId = 'SOS-${DateTime.now().millisecondsSinceEpoch}';
      final riskPrediction = RiskPredictor.predict(
        severity: severity,
        notes: notes,
        latitude: lat,
        longitude: lng,
        accuracy: accuracy,
      );

      final sos = SosModel(
        sosId: sosId,
        userId: userId,
        userName: userName,
        userPhone: userPhone,
        latitude: lat,
        longitude: lng,
        altitude: alt,
        accuracy: accuracy,
        batteryLevel: 95,
        status: 'ACTIVE',
        severity: severity,
        riskLevel: riskPrediction.riskLevel,
        riskScore: riskPrediction.riskScore,
        riskReason: riskPrediction.reason,
        notes: notes,
        isMeshRelayed: true,
      );

      _activeSos = sos;
      _isSosActive = true;

      // 1. Save locally to SQLite
      await DBHelper.instance.insertSosAlert(sos.toJson());

      // 2. Queue for Mesh Packet Broadcast & Sync Queue
      final meshPacket = MeshPacket(
        packetId: 'PKT-$sosId',
        senderId: userId,
        senderName: userName,
        content: notes.isEmpty
            ? 'EMERGENCY SOS BEACON: Victim $userName needs immediate assistance at ($lat, $lng)'
            : 'EMERGENCY SOS BEACON: Victim $userName needs immediate assistance at ($lat, $lng)\n$notes',
        packetType: MeshPacketType.sosBeacon,
        latitude: lat,
        longitude: lng,
        riskLevel: riskPrediction.riskLevel,
        riskScore: riskPrediction.riskScore,
        riskReason: riskPrediction.reason,
      );
      await DBHelper.instance.addToSyncQueue('SOS_ALERT', meshPacket.toPayloadString());

      await Future.wait([
        if (broadcastMeshPacket != null)
          broadcastMeshPacket(meshPacket).catchError((error) {
            AppLogger.warning('SOS mesh broadcast failed: $error', 'SosProvider');
          }),
        EmergencyContactNotificationService.notifyContacts(
          contacts: emergencyContacts,
          senderName: userName,
          latitude: lat,
          longitude: lng,
          sosId: sosId,
        ),
        _postSosToBackend(sos),
      ]);

      _isLoading = false;
      notifyListeners();
      return sos;
    } catch (e) {
      AppLogger.error('Failed to trigger SOS alert', e, null, 'SosProvider');
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<void> _postSosToBackend(SosModel sos) async {
    try {
      await _dioClient.instance.post(
        ApiEndpoints.sos,
        data: sos.toJson(),
      );
      AppLogger.info('SOS Alert successfully sent to central cloud server', 'SosProvider');
    } catch (err) {
      AppLogger.warning('SOS Alert saved offline. Broadcasted via Mesh network.', 'SosProvider');
    }
  }

  /// Cancel active SOS alert
  Future<void> cancelSos() async {
    if (_activeSos == null) return;
    
    _isLoading = true;
    notifyListeners();

    try {
      await _dioClient.instance.put(
        '${ApiEndpoints.sos}/${_activeSos!.sosId}/cancel',
      );
    } catch (e) {
      AppLogger.warning('SOS cancel posted offline queue', 'SosProvider');
    }

    _isSosActive = false;
    _activeSos = null;
    _isLoading = false;
    notifyListeners();
  }

  /// Fetch list of active victim SOS alerts for Responders
  Future<void> fetchActiveSosAlerts() async {
    try {
      final response = await _dioClient.instance.get(ApiEndpoints.activeSos);
      if (response.data['success'] == true) {
        final List list = response.data['data'];
        _activeSosList = list.map((item) => SosModel.fromJson(item)).toList();
        notifyListeners();
      }
    } catch (e) {
      // Fallback load from local database
      final dbAlerts = await DBHelper.instance.getSosAlerts();
      _activeSosList = dbAlerts.map((item) => SosModel.fromJson(item)).toList();
      notifyListeners();
    }
  }

  Future<bool> markResponding(String alertId) async {
    return _updateAlertStatus(ApiEndpoints.acknowledgeSos(alertId));
  }

  Future<bool> markResolved(String alertId) async {
    return _updateAlertStatus(ApiEndpoints.resolveSos(alertId));
  }

  Future<bool> _updateAlertStatus(String endpoint) async {
    try {
      final response = await _dioClient.instance.put(endpoint);
      if (response.data['success'] == true) {
        final alert = SosModel.fromJson(response.data['data']);
        final index = _activeSosList.indexWhere((item) => item.sosId == alert.sosId);
        if (index >= 0) {
          _activeSosList[index] = alert;
        }
        notifyListeners();
        return true;
      }
    } catch (e) {
      AppLogger.error('Failed to update SOS status', e, null, 'SosProvider');
    }
    return false;
  }

  @override
  void dispose() {
    _newAlertSubscription?.cancel();
    _statusSubscription?.cancel();
    _emergencySubscription?.cancel();
    _rescueRefreshTimer?.cancel();
    _socketService.dispose();
    super.dispose();
  }
}
