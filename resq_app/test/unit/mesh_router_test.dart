import 'package:flutter_test/flutter_test.dart';
import 'package:resq_app/core/utils/mesh_packet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MeshRouter Unit Tests', () {
    test('MeshPacket creation & JSON serialization', () {
      final packet = MeshPacket(
        packetId: 'PKT-1001',
        senderId: 'NODE-A',
        senderName: 'Alice',
        content: 'Emergency Test Message',
        ttl: 5,
      );

      final json = packet.toJson();

      expect(json['packetId'], 'PKT-1001');
      expect(json['senderName'], 'Alice');
      expect(json['ttl'], 5);

      final reconstructed = MeshPacket.fromJson(json);

      expect(reconstructed.packetId, 'PKT-1001');
      expect(reconstructed.content, 'Emergency Test Message');
    });

    test('Relay packet copy decrements TTL and increments hop count', () {
      final packet = MeshPacket(
        packetId: 'PKT-2002',
        senderId: 'NODE-B',
        senderName: 'Bob',
        content: 'Relay packet test',
        ttl: 5,
        hopCount: 1,
      );

      final relayed = packet.copyWithRelay('NODE-TEST-01');

      expect(relayed.ttl, 4);
      expect(relayed.hopCount, 2);
      expect(relayed.relayedBy, contains('NODE-TEST-01'));
    });
  });
}
