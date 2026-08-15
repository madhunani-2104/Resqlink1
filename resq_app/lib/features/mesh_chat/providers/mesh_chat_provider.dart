import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/chat_message.dart';
import '../models/mesh_peer.dart';
import '../services/mesh_router.dart';
import '../services/ble_service.dart';
import '../services/wifi_direct_service.dart';
import '../services/web_simulation_service.dart';
import '../../../core/utils/mesh_packet.dart';
import '../../../core/database/db_helper.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_endpoints.dart';
import '../services/mesh_socket_service.dart';
import '../../../core/services/file_transfer_service.dart';
import 'dart:convert';

class MeshChatProvider extends ChangeNotifier {
  late final MeshRouter _meshRouter;
  late final BleService _bleService;
  late final WifiDirectService _wifiDirectService;
  late final WebSimulationService _webSimService;
  late final MeshSocketService _socketService;
  final DioClient _dioClient = DioClient();
  final FileTransferService _fileTransferService = FileTransferService();

  final String currentUserId;
  final List<ChatMessage> _messages = [];
  final Map<String, MeshPeer> _peersById = {};
  final Map<String, String> _deliveryStatusByPacketId = {};
  StreamSubscription<MeshPacket>? _packetSubscription;
  StreamSubscription<Map<String, dynamic>>? _socketMessageSubscription;
  bool _isMeshActive = false;
  int _simulatedPeersCount = 3;

  List<ChatMessage> get messages => _messages;
  List<MeshPeer> get peers => _peersById.values.toList()
    ..sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
  bool get isMeshActive => _isMeshActive;
  int get activePeersCount => kIsWeb ? _simulatedPeersCount : _peersById.length;
  Map<String, String> get deliveryStatusByPacketId => Map.unmodifiable(_deliveryStatusByPacketId);

  MeshChatProvider(this.currentUserId) {
    _meshRouter = MeshRouter(localNodeId: currentUserId);
    _bleService = BleService(meshRouter: _meshRouter, onPeerDiscovered: _upsertPeer);
    _wifiDirectService = WifiDirectService(meshRouter: _meshRouter, onPeerDiscovered: _upsertPeer);
    _webSimService = WebSimulationService(meshRouter: _meshRouter);
    _socketService = MeshSocketService();

    _listenToPackets(currentUserId);
    _listenToSocketMessages(currentUserId);
    _loadServerMessages(currentUserId);
    _socketService.connect();
    _loadHistoricalMessages(currentUserId);
    startMeshNetworking();
  }

  void _listenToPackets(String userId) {
    _packetSubscription = _meshRouter.onPacketReceived.listen((packet) async {
      if (packet.packetType == MeshPacketType.sosBeacon) {
        NotificationService.showEmergencySosAlert(
          victimName: packet.senderName,
          locationText: '${packet.latitude ?? 0}, ${packet.longitude ?? 0}',
          sosId: packet.packetId,
        );
      }
      if (packet.packetType == MeshPacketType.ack) {
        _deliveryStatusByPacketId[packet.receiverId] = 'Delivered';
        notifyListeners();
        return;
      }

      _addMessageIfRelevant(packet, userId);
      if (packet.senderId != currentUserId) {
        await _sendAcknowledgement(packet);
      }
      await _relayPendingPackets();
    });
  }

  void _listenToSocketMessages(String userId) {
    _socketMessageSubscription = _socketService.onMessage.listen((raw) {
      try {
        final packet = MeshPacket.fromJson(raw);
        _addMessageIfRelevant(packet, userId);
      } catch (e) {
        // Ignore malformed socket messages without breaking the chat stream.
      }
    });
  }

  bool _isRelevantToUser(MeshPacket packet, String userId) {
    if (packet.packetType != MeshPacketType.chat) return false;
    if (packet.receiverId == 'BROADCAST' || packet.receiverId == 'RESPONDERS_OPS') {
      return true;
    }
    return packet.senderId == userId || packet.receiverId == userId;
  }

  void _addMessageIfRelevant(MeshPacket packet, String userId) {
    if (!_isRelevantToUser(packet, userId)) return;
    if (_messages.any((message) => message.packetId == packet.packetId)) return;

    _messages.add(ChatMessage.fromMeshPacket(packet, userId));
    _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    notifyListeners();
  }

  void _upsertPeer(Map<String, dynamic> rawPeer) {
    final peer = MeshPeer.fromJson(rawPeer);
    if (peer.id.isEmpty) return;
    _peersById[peer.id] = peer;
    notifyListeners();
  }

  Future<void> _relayPendingPackets() async {
    if (kIsWeb) return;

    final pendingPackets = _meshRouter.getPendingRelayPackets();
    for (final packet in pendingPackets) {
      await Future.wait([
        _bleService.broadcastPacket(packet),
        _wifiDirectService.sendPacketP2P(packet),
      ]);
    }
  }

  Future<void> _loadHistoricalMessages(String userId) async {
    try {
      final dbRows = await DBHelper.instance.getMessages();
      for (var row in dbRows) {
        final packet = MeshPacket.fromJson(row);
        _addMessageIfRelevant(packet, userId);
      }
      _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    } catch (_) {
      // Offline DB load silently ignored
    }
  }

  Future<void> _loadServerMessages(String userId) async {
    try {
      final response = await _dioClient.instance.get(
        ApiEndpoints.meshMessages,
        queryParameters: {'limit': 200},
      );
      final data = response.data['data'];
      if (data is! List) return;

      for (final row in data) {
        if (row is Map<String, dynamic>) {
          _addMessageIfRelevant(MeshPacket.fromJson(row), userId);
        } else if (row is Map) {
          _addMessageIfRelevant(
            MeshPacket.fromJson(Map<String, dynamic>.from(row)),
            userId,
          );
        }
      }
      _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      notifyListeners();
    } catch (e) {
      // Offline mode continues to use the local SQLite history.
    }
  }

  void startMeshNetworking() {
    _isMeshActive = true;
    if (kIsWeb) {
      _webSimService.startWebMeshSimulation();
    } else {
      _bleService.startBleScanning();
      _wifiDirectService.discoverPeers();
    }
    notifyListeners();
  }

  Future<void> sendMessage({
    required String senderId,
    required String senderName,
    required String text,
    String receiverId = 'BROADCAST',
  }) async {
    final packet = MeshPacket(
      packetId: 'PKT-${DateTime.now().millisecondsSinceEpoch}',
      senderId: senderId,
      senderName: senderName,
      receiverId: receiverId,
      content: text,
      packetType: MeshPacketType.chat,
      ttl: 7,
    );

    // Process locally first so the sender sees the message immediately.
    await _meshRouter.processIncomingPacket(packet);
    _deliveryStatusByPacketId[packet.packetId] = 'Sent to mesh';

    // Persist/deliver through the existing backend when internet is available.
    // Mesh/BLE/Wi-Fi Direct remains the offline transport.
    try {
      await _dioClient.instance.post(ApiEndpoints.meshMessage, data: packet.toJson());
      _deliveryStatusByPacketId[packet.packetId] = 'Delivered';
      notifyListeners();
    } catch (_) {
      // Offline mesh delivery is still valid when the backend is unavailable.
    }

    if (!kIsWeb) {
      await _bleService.broadcastPacket(packet);
      await _wifiDirectService.sendPacketP2P(packet);
    }
  }

  Future<bool> sendFile({
    required String senderId,
    required String senderName,
    required String path,
    required String receiverId,
    required String fileName,
    required String mimeType,
    required int fileSize,
  }) async {
    final inlineBase64 = await _fileTransferService.readInlineBase64(path);
    final uploaded = await _fileTransferService.upload(
      path: path,
      receiverId: receiverId,
    );

    if (uploaded == null && inlineBase64 == null) return false;

    final fileId = uploaded?.fileId ?? 'LOCAL-${DateTime.now().millisecondsSinceEpoch}.bin';
    final metadata = jsonEncode({
      'fileId': fileId,
      'fileName': uploaded?.name ?? fileName,
      'mimeType': uploaded?.mimeType ?? mimeType,
      'fileSize': uploaded?.size ?? fileSize,
      'downloadPath': uploaded?.downloadPath ?? '',
      'inlineBase64': inlineBase64,
    });

    final packet = MeshPacket(
      packetId: 'FILE-${DateTime.now().millisecondsSinceEpoch}',
      senderId: senderId,
      senderName: senderName,
      receiverId: receiverId,
      content: 'FILE_ATTACHMENT:$metadata',
      packetType: MeshPacketType.chat,
      ttl: 7,
    );

    await _meshRouter.processIncomingPacket(packet);
    _deliveryStatusByPacketId[packet.packetId] = uploaded == null ? 'Sent to mesh (offline)' : 'Sent to mesh';
    notifyListeners();

    if (uploaded != null) {
      try {
        await _dioClient.instance.post(ApiEndpoints.meshMessage, data: packet.toJson());
        _deliveryStatusByPacketId[packet.packetId] = 'Delivered';
        notifyListeners();
      } catch (_) {
        // Mesh delivery remains available if the API request is temporarily unavailable.
      }
    }

    if (!kIsWeb) {
      // Existing Wi-Fi Direct transports the full attachment envelope for small offline files.
      await _wifiDirectService.sendPacketP2P(packet);
      // BLE transports the same envelope; small inline files are intentionally capped by readInlineBase64.
      await _bleService.broadcastPacket(packet);
    }
    return true;
  }

  Future<String?> downloadFile(String fileId, String fileName, {String? inlineBase64}) async {
    if (inlineBase64 != null && inlineBase64.isNotEmpty) {
      final local = await _fileTransferService.writeInlineBase64(inlineBase64, fileName);
      if (local != null) return local;
    }
    return _fileTransferService.download(fileId: fileId, fileName: fileName);
  }

  Future<void> broadcastEmergencySos(MeshPacket packet) async {
    await _meshRouter.processIncomingPacket(packet);
    _deliveryStatusByPacketId[packet.packetId] = 'Sent to mesh';

    if (!kIsWeb) {
      await Future.wait([
        _bleService.broadcastPacket(packet),
        _wifiDirectService.sendPacketP2P(packet),
      ]);
    } else {
      _webSimService.simulateIncomingPacket(packet);
    }
  }

  Future<void> _sendAcknowledgement(MeshPacket receivedPacket) async {
    if (receivedPacket.packetType == MeshPacketType.ack || kIsWeb) return;

    final ackPacket = MeshPacket(
      packetId: 'ACK-${receivedPacket.packetId}-${DateTime.now().millisecondsSinceEpoch}',
      senderId: currentUserId,
      senderName: 'ResQ Node',
      receiverId: receivedPacket.packetId,
      content: 'ACK:${receivedPacket.packetId}',
      packetType: MeshPacketType.ack,
      ttl: 3,
    );

    await Future.wait([
      _bleService.broadcastPacket(ackPacket),
      _wifiDirectService.sendPacketP2P(ackPacket),
    ]);
  }

  @override
  void dispose() {
    _packetSubscription?.cancel();
    _socketMessageSubscription?.cancel();
    _socketService.dispose();
    _meshRouter.dispose();
    _webSimService.stopSimulation();
    super.dispose();
  }
}
