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
  StreamSubscription<Map<String, dynamic>>? _dispatchSubscription;

  Timer? _rescueRefreshTimer;

  bool get isSosActive => _isSosActive;

  SosModel? get activeSos => _activeSos;

  List<SosModel> get activeSosList => _activeSosList;

  bool get isLoading => _isLoading;

  List<Map<String, dynamic>> _responders = [];

  List<Map<String, dynamic>> get responders => List.unmodifiable(_responders);

  Future<void> fetchDispatchQueue() async {
    try {
      final response = await _dioClient.instance.get(
        ApiEndpoints.adminDispatch,
      );
      if (response.data['success'] == true) {
        _activeSosList = (response.data['data'] as List)
            .map((item) => SosModel.fromJson(Map<String, dynamic>.from(item)))
            .toList();
        notifyListeners();
      }
    } catch (e) {
      AppLogger.warning('Failed to load dispatch queue: $e', 'SosProvider');
    }
  }

  Future<void> fetchResponders() async {
    try {
      final response = await _dioClient.instance.get(
        ApiEndpoints.adminResponders,
      );
      if (response.data['success'] == true) {
        _responders = (response.data['data'] as List)
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        notifyListeners();
      }
    } catch (e) {
      AppLogger.warning('Failed to load responders: $e', 'SosProvider');
    }
  }

  Future<bool> assignResponder(String alertId, String responderId) async {
    try {
      final response = await _dioClient.instance.put(
        ApiEndpoints.assignDispatch(alertId),
        data: {'responderId': responderId},
      );
      if (response.data['success'] == true) {
        final alert = SosModel.fromJson(
          Map<String, dynamic>.from(response.data['data']),
        );
        _replaceAlert(alert);
        await fetchResponders();
        return true;
      }
    } catch (e) {
      AppLogger.warning('Failed to assign responder: $e', 'SosProvider');
    }
    return false;
  }

  Future<bool> updateDispatchStatus(String alertId, String status) async {
    try {
      final response = await _dioClient.instance.put(
        ApiEndpoints.dispatchStatus(alertId),
        data: {'status': status},
      );
      if (response.data['success'] == true) {
        _replaceAlert(
          SosModel.fromJson(Map<String, dynamic>.from(response.data['data'])),
        );
        return true;
      }
    } catch (e) {
      AppLogger.warning('Failed to update dispatch status: $e', 'SosProvider');
    }
    return false;
  }

  Future<bool> setResponderAvailability(String status) async {
    try {
      final response = await _dioClient.instance.put(
        ApiEndpoints.responderAvailability,
        data: {'availabilityStatus': status},
      );
      return response.data['success'] == true;
    } catch (e) {
      AppLogger.warning(
        'Failed to update responder availability: $e',
        'SosProvider',
      );
      return false;
    }
  }

  void _replaceAlert(SosModel alert) {
    final index = _activeSosList.indexWhere(
      (item) => item.sosId == alert.sosId,
    );
    if (index >= 0) {
      _activeSosList[index] = alert;
    } else {
      _activeSosList.insert(0, alert);
    }
    notifyListeners();
  }

  // ==============================================================
  // RESCUE / ADMIN SOCKET
  // ==============================================================

  void connectRescueAlertStream({required String role}) {
    if (role != 'rescue_team' && role != 'admin') {
      return;
    }

    _socketService.connect(role: role);

    _newAlertSubscription ??= _socketService.onNewAlert.listen((data) {
      try {
        final alert = SosModel.fromJson(data);

        _activeSosList.removeWhere((item) => item.sosId == alert.sosId);

        _activeSosList.insert(0, alert);

        notifyListeners();
      } catch (e) {
        AppLogger.error(
          'Failed to process new SOS alert',
          e,
          null,
          'SosProvider',
        );
      }
    });

    _statusSubscription ??= _socketService.onStatusUpdated.listen((data) {
      try {
        final alert = SosModel.fromJson(data);

        final index = _activeSosList.indexWhere(
          (item) => item.sosId == alert.sosId,
        );

        if (index >= 0) {
          _activeSosList[index] = alert;
        } else {
          _activeSosList.insert(0, alert);
        }

        notifyListeners();
      } catch (e) {
        AppLogger.error(
          'Failed to process SOS status update',
          e,
          null,
          'SosProvider',
        );
      }
    });

    _dispatchSubscription ??= _socketService.onDispatchUpdated.listen((data) {
      try {
        _replaceAlert(SosModel.fromJson(data));
      } catch (e) {
        AppLogger.warning(
          'Failed to process dispatch update: $e',
          'SosProvider',
        );
      }
    });

    _rescueRefreshTimer ??= Timer.periodic(const Duration(seconds: 15), (_) {
      fetchActiveSosAlerts();
    });
  }

  // ==============================================================
  // USER EMERGENCY SOCKET
  // ==============================================================

  void connectUserEmergencyAlertStream({required String userId}) {
    if (userId.isEmpty) {
      return;
    }

    _socketService.connect(role: 'user');

    _emergencySubscription ??= _socketService.onEmergencyAlert.listen((data) {
      try {
        final alert = SosModel.fromJson(data);

        _activeSosList.removeWhere((item) => item.sosId == alert.sosId);

        _activeSosList.insert(0, alert);

        notifyListeners();
      } catch (e) {
        AppLogger.error(
          'Failed to process emergency alert',
          e,
          null,
          'SosProvider',
        );
      }
    });
  }

  // ==============================================================
  // TRIGGER SOS
  // ==============================================================

  Future<SosModel?> triggerSos({
    required String userId,
    required String userName,
    required String userPhone,
    List<EmergencyContact> emergencyContacts = const [],
    Future<void> Function(MeshPacket packet)? broadcastMeshPacket,
    String notes = '',
    String severity = 'CRITICAL',
  }) async {
    // Prevent double tapping.
    if (_isLoading) {
      return null;
    }

    _isLoading = true;
    notifyListeners();

    try {
      // ----------------------------------------------------------
      // GET GPS LOCATION
      // ----------------------------------------------------------

      Position? pos;

      try {
        pos = await LocationService.getCurrentPosition();

        // IMPORTANT:
        // pos is nullable, so DO NOT use:
        //
        // pos.latitude
        // pos.longitude
        //
        // unless pos != null.

        if (pos != null) {
          debugPrint('SOS GPS: ${pos.latitude}, ${pos.longitude}');

          AppLogger.info(
            'GPS location obtained: '
                '${pos.latitude}, ${pos.longitude}',
            'SosProvider',
          );
        }
      } catch (e) {
        AppLogger.warning('Could not obtain GPS location: $e', 'SosProvider');
      }

      // ----------------------------------------------------------
      // SAFE GPS VALUES
      // ----------------------------------------------------------

      final double lat = pos?.latitude ?? 0.0;
      final double lng = pos?.longitude ?? 0.0;
      final double alt = pos?.altitude ?? 0.0;
      final double accuracy = pos?.accuracy ?? 0.0;

      final bool locationAvailable = pos != null;

      debugPrint('SOS location available: $locationAvailable');

      debugPrint('SOS coordinates: $lat, $lng');

      // ----------------------------------------------------------
      // GENERATE SOS ID
      // ----------------------------------------------------------

      final String sosId = 'SOS-${DateTime.now().millisecondsSinceEpoch}';

      // ----------------------------------------------------------
      // RISK PREDICTION
      // ----------------------------------------------------------

      final riskPrediction = RiskPredictor.predict(
        severity: severity,
        notes: notes,
        latitude: lat,
        longitude: lng,
        accuracy: accuracy,
      );

      // ----------------------------------------------------------
      // CREATE SOS MODEL
      // ----------------------------------------------------------

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

      notifyListeners();

      // ----------------------------------------------------------
      // SAVE LOCALLY
      // ----------------------------------------------------------

      try {
        await DBHelper.instance.insertSosAlert(sos.toJson());

        AppLogger.info('SOS saved to local database.', 'SosProvider');
      } catch (e) {
        AppLogger.warning('Failed to save SOS locally: $e', 'SosProvider');
      }

      // ----------------------------------------------------------
      // BUILD MESH PACKET
      // ----------------------------------------------------------

      final String locationText;

      if (locationAvailable) {
        locationText = 'Location: ($lat, $lng)';
      } else {
        locationText = 'Location unavailable - GPS permission/location service not available';
      }

      final String baseContent =
          'EMERGENCY SOS BEACON: '
          'Victim $userName needs immediate assistance.\n'
          '$locationText';

      final String packetContent = notes.trim().isEmpty
          ? baseContent
          : '$baseContent\n$notes';

      final meshPacket = MeshPacket(
        packetId: 'PKT-$sosId',
        senderId: userId,
        senderName: userName,
        content: packetContent,
        packetType: MeshPacketType.sosBeacon,
        latitude: lat,
        longitude: lng,
        riskLevel: riskPrediction.riskLevel,
        riskScore: riskPrediction.riskScore,
        riskReason: riskPrediction.reason,
      );

      // ----------------------------------------------------------
      // ADD TO SYNC QUEUE
      // ----------------------------------------------------------

      try {
        await DBHelper.instance.addToSyncQueue(
          'SOS_ALERT',
          meshPacket.toPayloadString(),
        );

        AppLogger.info('SOS added to sync queue.', 'SosProvider');
      } catch (e) {
        AppLogger.warning('Failed to add SOS to sync queue: $e', 'SosProvider');
      }

      // ----------------------------------------------------------
      // MESH BROADCAST
      // ----------------------------------------------------------

      if (broadcastMeshPacket != null) {
        try {
          await broadcastMeshPacket(meshPacket);

          AppLogger.info(
            'SOS broadcast successfully through mesh.',
            'SosProvider',
          );
        } catch (e) {
          AppLogger.warning('SOS mesh broadcast failed: $e', 'SosProvider');
        }
      }

      // ----------------------------------------------------------
      // EMERGENCY CONTACTS
      // ----------------------------------------------------------

      try {
        await EmergencyContactNotificationService.notifyContacts(
          contacts: emergencyContacts,
          senderName: userName,
          latitude: lat,
          longitude: lng,
          sosId: sosId,
        );

        AppLogger.info('Emergency contacts notified.', 'SosProvider');
      } catch (e) {
        AppLogger.warning(
          'Emergency contact notification failed: $e',
          'SosProvider',
        );
      }

      // ----------------------------------------------------------
      // CLOUD BACKEND
      // ----------------------------------------------------------

      await _postSosToBackend(sos);

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

  // ==============================================================
  // POST SOS TO BACKEND
  // ==============================================================

  Future<void> _postSosToBackend(SosModel sos) async {
    try {
      final response = await _dioClient.instance.post(
        ApiEndpoints.sos,
        data: sos.toJson(),
      );

      debugPrint('SOS backend response: ${response.data}');

      AppLogger.info(
        'SOS successfully sent to central cloud server.',
        'SosProvider',
      );
    } catch (err) {
      debugPrint('SOS backend upload failed: $err');

      AppLogger.warning(
        'SOS saved offline and broadcast through mesh.',
        'SosProvider',
      );
    }
  }

  // ==============================================================
  // CANCEL SOS
  // ==============================================================

  Future<void> cancelSos() async {
    if (_activeSos == null) {
      return;
    }

    _isLoading = true;

    notifyListeners();

    try {
      await _dioClient.instance.put(
        '${ApiEndpoints.sos}/${_activeSos!.sosId}/cancel',
      );

      AppLogger.info('SOS cancelled on backend.', 'SosProvider');
    } catch (e) {
      AppLogger.warning('SOS cancel request failed: $e', 'SosProvider');
    }

    _isSosActive = false;
    _activeSos = null;

    _isLoading = false;

    notifyListeners();
  }

  // ==============================================================
  // FETCH ACTIVE SOS
  // ==============================================================

  Future<void> fetchActiveSosAlerts() async {
    try {
      final response = await _dioClient.instance.get(ApiEndpoints.activeSos);

      debugPrint('Active SOS response: ${response.data}');

      if (response.data['success'] == true) {
        final List list = response.data['data'] ?? [];

        _activeSosList = list.map((item) => SosModel.fromJson(item)).toList();

        notifyListeners();

        return;
      }
    } catch (e) {
      AppLogger.warning(
        'Failed to fetch active SOS from backend: $e',
        'SosProvider',
      );
    }

    // ----------------------------------------------------------
    // FALLBACK TO LOCAL DATABASE
    // ----------------------------------------------------------

    try {
      final dbAlerts = await DBHelper.instance.getSosAlerts();

      _activeSosList = dbAlerts.map((item) => SosModel.fromJson(item)).toList();

      notifyListeners();
    } catch (dbError) {
      AppLogger.warning(
        'Could not load local SOS alerts: $dbError',
        'SosProvider',
      );
    }
  }

  // ==============================================================
  // MARK RESPONDING
  // ==============================================================

  Future<bool> markResponding(String alertId) async {
    return _updateAlertStatus(ApiEndpoints.acknowledgeSos(alertId));
  }

  // ==============================================================
  // MARK RESOLVED
  // ==============================================================

  Future<bool> markResolved(String alertId) async {
    return _updateAlertStatus(ApiEndpoints.resolveSos(alertId));
  }

  // ==============================================================
  // UPDATE STATUS
  // ==============================================================

  Future<bool> _updateAlertStatus(String endpoint) async {
    try {
      final response = await _dioClient.instance.put(endpoint);

      if (response.data['success'] == true) {
        final alert = SosModel.fromJson(response.data['data']);

        final index = _activeSosList.indexWhere(
          (item) => item.sosId == alert.sosId,
        );

        if (index >= 0) {
          _activeSosList[index] = alert;
        } else {
          _activeSosList.insert(0, alert);
        }

        notifyListeners();

        return true;
      }
    } catch (e) {
      AppLogger.error('Failed to update SOS status', e, null, 'SosProvider');
    }

    return false;
  }

  // ==============================================================
  // DISPOSE
  // ==============================================================

  @override
  void dispose() {
    _newAlertSubscription?.cancel();
    _statusSubscription?.cancel();
    _emergencySubscription?.cancel();
    _dispatchSubscription?.cancel();
    _rescueRefreshTimer?.cancel();

    _socketService.dispose();

    super.dispose();
  }
}
