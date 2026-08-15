import 'dart:async';
import 'dart:math';
import '../../../core/utils/mesh_packet.dart';
import '../../../core/utils/logger.dart';
import 'mesh_router.dart';

class SimulatedNode {
  final String id;
  final String name;
  final double distanceMeters;
  bool isOnline;

  SimulatedNode({
    required this.id,
    required this.name,
    required this.distanceMeters,
    this.isOnline = true,
  });
}

class WebSimulationService {
  final MeshRouter meshRouter;
  Timer? _simulationHeartbeatTimer;
  final List<SimulatedNode> activeSimulatedNodes = [];

  WebSimulationService({required this.meshRouter}) {
    _initializeSimulatedCluster();
  }

  void _initializeSimulatedCluster() {
    activeSimulatedNodes.addAll([
      SimulatedNode(id: 'NODE-ALPHA-101', name: 'Rescue Team Bravo', distanceMeters: 120),
      SimulatedNode(id: 'NODE-BETA-204', name: 'Shelter Coordinator', distanceMeters: 340),
      SimulatedNode(id: 'NODE-GAMMA-309', name: 'Victim Relay #1', distanceMeters: 450),
      SimulatedNode(id: 'NODE-DELTA-512', name: 'Safe Haven Scout', distanceMeters: 780),
    ]);
  }

  void startWebMeshSimulation() {
    AppLogger.info('Starting Web Mesh Network Simulator...', 'WebSimulationService');
    _simulationHeartbeatTimer?.cancel();

    // Periodically simulate receiving a message or relaying a packet from virtual nearby mesh nodes
    _simulationHeartbeatTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (activeSimulatedNodes.isEmpty) return;

      final random = Random();
      final node = activeSimulatedNodes[random.nextInt(activeSimulatedNodes.length)];

      final simulatedPackets = [
        'Safe Zone Alpha reporting normal occupancy level.',
        'Emergency response team heading to Sector 4.',
        'Mesh connection stable. 4 active peers in range.',
        'Water supplies available at Central Shelter.',
      ];

      final selectedText = simulatedPackets[random.nextInt(simulatedPackets.length)];

      final packet = MeshPacket(
        packetId: 'SIM-${DateTime.now().millisecondsSinceEpoch}-${random.nextInt(999)}',
        senderId: node.id,
        senderName: node.name,
        receiverId: 'BROADCAST',
        content: selectedText,
        packetType: MeshPacketType.chat,
        ttl: 5,
        hopCount: 1,
        relayedBy: [node.id],
      );

      meshRouter.processIncomingPacket(packet);
    });
  }

  void stopSimulation() {
    _simulationHeartbeatTimer?.cancel();
  }

  Future<void> simulateIncomingPacket(MeshPacket packet) {
    return meshRouter.processIncomingPacket(packet);
  }
}
