import 'dart:async';
import '../../../core/utils/mesh_packet.dart';
import '../../../core/utils/logger.dart';
import '../../../core/database/db_helper.dart';

class MeshRouter {
  final String localNodeId;
  final Set<String> _seenPacketIds = {};
  final List<MeshPacket> _storeAndForwardBuffer = [];
  final StreamController<MeshPacket> _receivedPacketController = StreamController<MeshPacket>.broadcast();

  Stream<MeshPacket> get onPacketReceived => _receivedPacketController.stream;

  MeshRouter({required this.localNodeId});

  /// Process incoming packet received via BLE, Wi-Fi Direct, or Web P2P Simulator
  Future<bool> processIncomingPacket(MeshPacket packet) async {
    // 1. Deduplication Check
    if (_seenPacketIds.contains(packet.packetId)) {
      AppLogger.debug('Duplicate packet ignored: ${packet.packetId}', 'MeshRouter');
      return false;
    }
    _seenPacketIds.add(packet.packetId);

    // Keep seen set capped at 1000 items
    if (_seenPacketIds.length > 1000) {
      _seenPacketIds.remove(_seenPacketIds.first);
    }

    AppLogger.info('Received mesh packet #${packet.packetId} from ${packet.senderName} (Hop: ${packet.hopCount}, TTL: ${packet.ttl})', 'MeshRouter');

    // 2. Persist Packet in Local Database (Safe catch)
    try {
      await DBHelper.instance.insertMessage(packet.toJson());
      await DBHelper.instance.addToSyncQueue(
        packet.packetType == MeshPacketType.sosBeacon ? 'SOS_ALERT' : 'MESH_MESSAGE',
        packet.toPayloadString(),
      );
    } catch (e) {
      AppLogger.debug('Database persistence skipped or offline: $e', 'MeshRouter');
    }

    // Always Notify UI listeners
    _receivedPacketController.add(packet);

    // 3. Multi-Hop Forwarding Criteria Check
    if (packet.ttl <= 1 || packet.senderId == localNodeId) {
      AppLogger.debug('Packet relay skipped for ${packet.packetId}', 'MeshRouter');
      return true;
    }

    // Prepare packet for next hop relay
    final relayedPacket = packet.copyWithRelay(localNodeId);
    _storeAndForwardBuffer.add(relayedPacket);

    return true;
  }

  /// Get pending packets ready for forwarding/relaying
  List<MeshPacket> getPendingRelayPackets() {
    final list = List<MeshPacket>.from(_storeAndForwardBuffer);
    _storeAndForwardBuffer.clear();
    return list;
  }

  void dispose() {
    _receivedPacketController.close();
  }
}
