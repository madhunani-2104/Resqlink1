import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/chat_message.dart';
import '../models/mesh_peer.dart';

import '../services/mesh_router.dart';
import '../services/ble_service.dart';
import '../services/wifi_direct_service.dart';
import '../services/web_simulation_service.dart';
import '../services/mesh_socket_service.dart';

import '../../../core/utils/mesh_packet.dart';
import '../../../core/database/db_helper.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/services/file_transfer_service.dart';
import '../../../core/services/file_chunk_transfer.dart';

class MeshChatProvider extends ChangeNotifier {
  // ============================================================
  // SERVICES
  // ============================================================

  late final MeshRouter _meshRouter;

  late final BleService _bleService;

  late final WifiDirectService _wifiDirectService;

  late final WebSimulationService _webSimService;

  late final MeshSocketService _socketService;

  final DioClient _dioClient = DioClient();

  final FileTransferService _fileTransferService = FileTransferService();

  // ============================================================
  // USER
  // ============================================================

  final String currentUserId;

  // ============================================================
  // DATA
  // ============================================================

  final List<ChatMessage> _messages = [];

  final Map<String, MeshPeer> _peersById = {};

  final Map<String, String> _deliveryStatusByPacketId = {};

  final Map<String, FileChunkAssembler> _fileAssemblers = {};

  final Map<String, double> _fileTransferProgress = {};

  final Map<String, String> _localFilePaths = {};

  // ============================================================
  // SUBSCRIPTIONS
  // ============================================================

  StreamSubscription<MeshPacket>? _packetSubscription;

  StreamSubscription<Map<String, dynamic>>? _socketMessageSubscription;

  // ============================================================
  // STATE
  // ============================================================

  bool _isMeshActive = false;

  int _simulatedPeersCount = 3;

  // ============================================================
  // GETTERS
  // ============================================================

  List<ChatMessage> get messages {
    return List.unmodifiable(_messages);
  }

  List<MeshPeer> get peers {
    final result = _peersById.values.toList();

    result.sort((a, b) => b.lastSeen.compareTo(a.lastSeen));

    return result;
  }

  bool get isMeshActive {
    return _isMeshActive;
  }

  int get activePeersCount {
    if (kIsWeb) {
      return _simulatedPeersCount;
    }

    return _peersById.length;
  }

  Map<String, String> get deliveryStatusByPacketId {
    return Map.unmodifiable(_deliveryStatusByPacketId);
  }

  double fileTransferProgress(String transferId) {
    return _fileTransferProgress[transferId] ?? 1;
  }

  // ============================================================
  // CONSTRUCTOR
  // ============================================================

  MeshChatProvider(this.currentUserId) {
    _meshRouter = MeshRouter(localNodeId: currentUserId);

    _bleService = BleService(
      meshRouter: _meshRouter,
      onPeerDiscovered: _upsertPeer,
    );

    _wifiDirectService = WifiDirectService(
      meshRouter: _meshRouter,
      onPeerDiscovered: _upsertPeer,
    );

    _webSimService = WebSimulationService(meshRouter: _meshRouter);

    _socketService = MeshSocketService();

    _listenToPackets(currentUserId);

    _listenToSocketMessages(currentUserId);

    _loadServerMessages(currentUserId);

    _socketService.connect();

    _loadHistoricalMessages(currentUserId);

    startMeshNetworking();
  }

  // ============================================================
  // PACKET LISTENER
  // ============================================================

  void _listenToPackets(String userId) {
    _packetSubscription = _meshRouter.onPacketReceived.listen((packet) async {
      // ------------------------------------------------------
      // SOS
      // ------------------------------------------------------

      if (packet.packetType == MeshPacketType.sosBeacon) {
        NotificationService.showEmergencySosAlert(
          victimName: packet.senderName,
          locationText:
              '${packet.latitude ?? 0}, '
              '${packet.longitude ?? 0}',
          sosId: packet.packetId,
        );
      }

      // ------------------------------------------------------
      // ACK
      // ------------------------------------------------------

      if (packet.packetType == MeshPacketType.ack) {
        final originalPacketId = packet.receiverId;

        _deliveryStatusByPacketId[originalPacketId] = 'Delivered';

        notifyListeners();

        return;
      }

      // ------------------------------------------------------
      // CHAT
      // ------------------------------------------------------

      final fileChunk = FileChunk.fromContent(packet.content);
      if (fileChunk != null) {
        if (packet.senderId != currentUserId) {
          await _consumeFileChunk(fileChunk, packet);
        }
        await _relayPendingPackets();
        return;
      }

      _addMessageIfRelevant(packet, userId);

      // ------------------------------------------------------
      // ACKNOWLEDGE
      // ------------------------------------------------------

      if (packet.senderId != currentUserId) {
        await _sendAcknowledgement(packet);
      }

      // ------------------------------------------------------
      // RELAY
      // ------------------------------------------------------

      await _relayPendingPackets();
    });
  }

  Future<void> _consumeFileChunk(FileChunk chunk, MeshPacket packet) async {
    final assembler = _fileAssemblers.putIfAbsent(
      chunk.transferId,
      () => FileChunkAssembler(chunk),
    );

    if (!assembler.add(chunk)) return;

    _fileTransferProgress[chunk.transferId] =
        assembler.receivedCount / assembler.total;
    notifyListeners();

    if (!assembler.isComplete) return;

    final inlineBase64 = assembler.assembleBase64();
    _fileAssemblers.remove(chunk.transferId);
    if (inlineBase64 == null) {
      _fileTransferProgress.remove(chunk.transferId);
      notifyListeners();
      return;
    }

    final completedPacket = MeshPacket(
      packetId: 'FILE-COMPLETE-${chunk.transferId}',
      senderId: packet.senderId,
      senderName: packet.senderName,
      receiverId: packet.receiverId,
      content:
          'FILE_ATTACHMENT:${jsonEncode({'fileId': chunk.transferId, 'fileName': chunk.fileName, 'mimeType': chunk.mimeType, 'fileSize': chunk.fileSize, 'downloadPath': '', 'inlineBase64': inlineBase64, 'transferId': chunk.transferId, 'transferState': 'complete'})}',
      packetType: MeshPacketType.chat,
      ttl: 1,
      hopCount: packet.hopCount,
      relayedBy: packet.relayedBy,
      timestampSent: packet.timestampSent,
    );

    _fileTransferProgress[chunk.transferId] = 1;
    await _meshRouter.processIncomingPacket(completedPacket);
  }

  // ============================================================
  // SOCKET LISTENER
  // ============================================================

  void _listenToSocketMessages(String userId) {
    _socketMessageSubscription = _socketService.onMessage.listen((raw) {
      try {
        final packet = MeshPacket.fromJson(raw);

        _addMessageIfRelevant(packet, userId);
      } catch (_) {
        // Ignore malformed socket packets.
      }
    });
  }

  // ============================================================
  // CHECK RELEVANT MESSAGE
  // ============================================================

  bool _isRelevantToUser(MeshPacket packet, String userId) {
    if (packet.packetType != MeshPacketType.chat) {
      return false;
    }

    // ----------------------------------------------------------
    // Broadcast
    // ----------------------------------------------------------

    if (packet.receiverId == 'BROADCAST' ||
        packet.receiverId == 'RESPONDERS_OPS') {
      return true;
    }

    // ----------------------------------------------------------
    // Direct message
    // ----------------------------------------------------------

    return packet.senderId == userId || packet.receiverId == userId;
  }

  // ============================================================
  // ADD MESSAGE
  // ============================================================

  void _addMessageIfRelevant(MeshPacket packet, String userId) {
    if (!_isRelevantToUser(packet, userId)) {
      return;
    }

    // ----------------------------------------------------------
    // Prevent duplicates
    // ----------------------------------------------------------

    final alreadyExists = _messages.any(
      (message) => message.packetId == packet.packetId,
    );

    if (alreadyExists) {
      return;
    }

    final message = ChatMessage.fromMeshPacket(packet, userId);

    _messages.add(message);

    _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    notifyListeners();
  }

  // ============================================================
  // UPDATE PEER
  // ============================================================

  void _upsertPeer(Map<String, dynamic> rawPeer) {
    try {
      final peer = MeshPeer.fromJson(rawPeer);

      if (peer.id.isEmpty) {
        return;
      }

      _peersById[peer.id] = peer;

      notifyListeners();
    } catch (_) {
      // Ignore invalid peer data.
    }
  }

  // ============================================================
  // RELAY
  // ============================================================

  Future<void> _relayPendingPackets() async {
    if (kIsWeb) {
      return;
    }

    final pendingPackets = _meshRouter.getPendingRelayPackets();

    for (final packet in pendingPackets) {
      try {
        await Future.wait([
          _bleService.broadcastPacket(packet),
          _wifiDirectService.sendPacketP2P(packet),
        ]);
      } catch (_) {
        // Continue relaying other packets.
      }
    }
  }

  // ============================================================
  // LOAD LOCAL MESSAGES
  // ============================================================

  Future<void> _loadHistoricalMessages(String userId) async {
    try {
      final dbRows = await DBHelper.instance.getMessages();

      for (final row in dbRows) {
        try {
          final packet = MeshPacket.fromJson(row);

          _addMessageIfRelevant(packet, userId);
        } catch (_) {
          // Ignore invalid database packet.
        }
      }

      _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      notifyListeners();
    } catch (_) {
      // Offline database failure.
    }
  }

  // ============================================================
  // LOAD SERVER MESSAGES
  // ============================================================

  Future<void> _loadServerMessages(String userId) async {
    try {
      final response = await _dioClient.instance.get(
        ApiEndpoints.meshMessages,
        queryParameters: {'limit': 200},
      );

      final responseData = response.data;

      if (responseData is! Map) {
        return;
      }

      final data = responseData['data'];

      if (data is! List) {
        return;
      }

      for (final row in data) {
        try {
          if (row is Map<String, dynamic>) {
            _addMessageIfRelevant(MeshPacket.fromJson(row), userId);
          } else if (row is Map) {
            _addMessageIfRelevant(
              MeshPacket.fromJson(Map<String, dynamic>.from(row)),
              userId,
            );
          }
        } catch (_) {
          // Ignore invalid server message.
        }
      }

      _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      notifyListeners();
    } catch (_) {
      // Offline mode.
    }
  }

  // ============================================================
  // START MESH
  // ============================================================

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

  // ============================================================
  // SEND TEXT
  // ============================================================

  Future<void> sendMessage({
    required String senderId,
    required String senderName,
    required String text,
    String receiverId = 'BROADCAST',
  }) async {
    final cleanText = text.trim();

    if (cleanText.isEmpty) {
      return;
    }

    final packet = MeshPacket(
      packetId: 'PKT-${DateTime.now().millisecondsSinceEpoch}',
      senderId: senderId,
      senderName: senderName,
      receiverId: receiverId,
      content: cleanText,
      packetType: MeshPacketType.chat,
      ttl: 7,
    );

    // ----------------------------------------------------------
    // LOCAL
    // ----------------------------------------------------------

    await _meshRouter.processIncomingPacket(packet);

    _deliveryStatusByPacketId[packet.packetId] = 'Sent to mesh';

    notifyListeners();

    // ----------------------------------------------------------
    // SERVER
    // ----------------------------------------------------------

    try {
      await _dioClient.instance.post(
        ApiEndpoints.meshMessage,
        data: packet.toJson(),
      );

      _deliveryStatusByPacketId[packet.packetId] = 'Delivered';

      notifyListeners();
    } catch (_) {
      // Offline mode.
    }

    // ----------------------------------------------------------
    // MESH
    // ----------------------------------------------------------

    try {
      if (!kIsWeb) {
        await Future.wait([
          _bleService.broadcastPacket(packet),
          _wifiDirectService.sendPacketP2P(packet),
        ]);
      } else {
        _webSimService.simulateIncomingPacket(packet);
      }
    } catch (_) {
      // Mesh failure does not delete local message.
    }
  }

  // ============================================================
  // SEND VOICE MESSAGE
  // ============================================================

  Future<bool> sendVoiceMessage({
    required String senderId,
    required String senderName,
    required String voicePayload,
    required String receiverId,
  }) async {
    final cleanPayload = voicePayload.trim();

    if (cleanPayload.isEmpty) {
      return false;
    }

    final packet = MeshPacket(
      packetId: 'VOICE-${DateTime.now().millisecondsSinceEpoch}',
      senderId: senderId,
      senderName: senderName,
      receiverId: receiverId,
      content: 'VOICE_MESSAGE_BASE64:$cleanPayload',
      packetType: MeshPacketType.chat,
      ttl: 7,
    );

    // ----------------------------------------------------------
    // LOCAL
    // ----------------------------------------------------------

    await _meshRouter.processIncomingPacket(packet);

    _deliveryStatusByPacketId[packet.packetId] = 'Sent to mesh';

    notifyListeners();

    bool delivered = false;

    // ----------------------------------------------------------
    // SERVER
    // ----------------------------------------------------------

    try {
      await _dioClient.instance.post(
        ApiEndpoints.meshMessage,
        data: packet.toJson(),
      );

      _deliveryStatusByPacketId[packet.packetId] = 'Delivered';

      delivered = true;

      notifyListeners();
    } catch (_) {
      // Continue with offline mesh.
    }

    // ----------------------------------------------------------
    // MESH
    // ----------------------------------------------------------

    try {
      if (!kIsWeb) {
        await Future.wait([
          _bleService.broadcastPacket(packet),
          _wifiDirectService.sendPacketP2P(packet),
        ]);

        delivered = true;
      } else {
        _webSimService.simulateIncomingPacket(packet);

        delivered = true;
      }
    } catch (_) {
      // Mesh transmission failed.
    }

    return delivered;
  }

  // ============================================================
  // SEND FILE
  // ============================================================

  Future<bool> sendFile({
    required String senderId,
    required String senderName,
    required String path,
    required String receiverId,
    required String fileName,
    required String mimeType,
    required int fileSize,
    List<int>? bytes,
  }) async {
    try {
      // --------------------------------------------------------
      // Read local copy for offline transfer.
      // --------------------------------------------------------

      final fileBytes = bytes ?? await _fileTransferService.readBytes(path);
      final inlineBase64 = fileBytes == null
          ? await _fileTransferService.readInlineBase64(path)
          : fileBytes.length <= 65536
          ? base64Encode(fileBytes)
          : null;

      // --------------------------------------------------------
      // Upload to server.
      // --------------------------------------------------------

      final uploaded = await _fileTransferService.upload(
        path: path,
        receiverId: receiverId,
      );

      // --------------------------------------------------------
      // If neither server upload nor local inline
      // representation is available, fail.
      // --------------------------------------------------------

      if (uploaded == null && inlineBase64 == null && fileBytes == null) {
        return false;
      }

      final fileId =
          uploaded?.fileId ??
          'LOCAL-${DateTime.now().millisecondsSinceEpoch}.bin';

      if (path.trim().isNotEmpty) {
        _localFilePaths[fileId] = path;
      }

      final metadata = jsonEncode({
        'fileId': fileId,
        'fileName': uploaded?.name ?? fileName,
        'mimeType': uploaded?.mimeType ?? mimeType,
        'fileSize': uploaded?.size ?? fileSize,
        'downloadPath': uploaded?.downloadPath ?? '',
        'inlineBase64': inlineBase64,
        'transferId': fileId,
        'transferState': fileBytes == null ? 'available' : 'queued',
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

      // --------------------------------------------------------
      // LOCAL
      // --------------------------------------------------------

      await _meshRouter.processIncomingPacket(packet);

      _deliveryStatusByPacketId[packet.packetId] = uploaded == null
          ? 'Sent to mesh (offline)'
          : 'Sent to mesh';

      notifyListeners();

      // --------------------------------------------------------
      // SERVER MESSAGE
      // --------------------------------------------------------

      if (uploaded != null) {
        try {
          await _dioClient.instance.post(
            ApiEndpoints.meshMessage,
            data: packet.toJson(),
          );

          _deliveryStatusByPacketId[packet.packetId] = 'Delivered';

          notifyListeners();
        } catch (_) {
          // Mesh can still deliver the file.
        }
      }

      // --------------------------------------------------------
      // MESH
      // --------------------------------------------------------

      if (fileBytes == null) {
        if (!kIsWeb) {
          await Future.wait([
            _wifiDirectService.sendPacketP2P(packet),
            _bleService.broadcastPacket(packet),
          ]);
        } else {
          _webSimService.simulateIncomingPacket(packet);
        }
      }

      if (fileBytes != null && fileBytes.isNotEmpty) {
        const chunkSize = 64;
        final total = (fileBytes.length + chunkSize - 1) ~/ chunkSize;
        _fileTransferProgress[fileId] = 0;
        notifyListeners();

        for (var index = 0; index < total; index++) {
          final start = index * chunkSize;
          final end = (start + chunkSize).clamp(0, fileBytes.length);
          final chunk = FileChunk(
            transferId: fileId,
            fileName: uploaded?.name ?? fileName,
            mimeType: uploaded?.mimeType ?? mimeType,
            fileSize: fileBytes.length,
            index: index,
            total: total,
            data: base64Encode(fileBytes.sublist(start, end)),
          );
          final chunkPacket = MeshPacket(
            packetId: chunk.packetId,
            senderId: senderId,
            senderName: senderName,
            receiverId: receiverId,
            content: chunk.toContent(),
            packetType: MeshPacketType.chat,
            ttl: 7,
          );

          await _meshRouter.processIncomingPacket(chunkPacket);
          if (!kIsWeb) {
            await Future.wait([
              _wifiDirectService.sendPacketP2P(chunkPacket),
              _bleService.broadcastPacket(chunkPacket),
            ]);
          } else {
            _webSimService.simulateIncomingPacket(chunkPacket);
          }

          _fileTransferProgress[fileId] = (index + 1) / total;
          notifyListeners();
        }
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  // ============================================================
  // DOWNLOAD FILE
  // ============================================================

  Future<String?> downloadFile(
    String fileId,
    String fileName, {
    String? inlineBase64,
  }) async {
    final localPath = _localFilePaths[fileId];
    if (localPath != null && localPath.isNotEmpty) {
      return localPath;
    }

    // ----------------------------------------------------------
    // Try inline file first.
    // ----------------------------------------------------------

    if (inlineBase64 != null && inlineBase64.isNotEmpty) {
      final local = await _fileTransferService.writeInlineBase64(
        inlineBase64,
        fileName,
      );

      if (local != null) {
        return local;
      }
    }

    // ----------------------------------------------------------
    // Otherwise download from server.
    // ----------------------------------------------------------

    return _fileTransferService.download(fileId: fileId, fileName: fileName);
  }

  // ============================================================
  // BROADCAST SOS
  // ============================================================

  Future<void> broadcastEmergencySos(MeshPacket packet) async {
    await _meshRouter.processIncomingPacket(packet);

    _deliveryStatusByPacketId[packet.packetId] = 'Sent to mesh';

    notifyListeners();

    try {
      if (!kIsWeb) {
        await Future.wait([
          _bleService.broadcastPacket(packet),
          _wifiDirectService.sendPacketP2P(packet),
        ]);
      } else {
        _webSimService.simulateIncomingPacket(packet);
      }
    } catch (_) {
      // SOS remains locally recorded.
    }
  }

  // ============================================================
  // ACK
  // ============================================================

  Future<void> _sendAcknowledgement(MeshPacket receivedPacket) async {
    if (receivedPacket.packetType == MeshPacketType.ack || kIsWeb) {
      return;
    }

    final ackPacket = MeshPacket(
      packetId:
          'ACK-${receivedPacket.packetId}-'
          '${DateTime.now().millisecondsSinceEpoch}',
      senderId: currentUserId,
      senderName: 'ResQ Node',
      receiverId: receivedPacket.packetId,
      content: 'ACK:${receivedPacket.packetId}',
      packetType: MeshPacketType.ack,
      ttl: 3,
    );

    try {
      await Future.wait([
        _bleService.broadcastPacket(ackPacket),
        _wifiDirectService.sendPacketP2P(ackPacket),
      ]);
    } catch (_) {
      // ACK transmission failed.
    }
  }

  // ============================================================
  // DISPOSE
  // ============================================================

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
