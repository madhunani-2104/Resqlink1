import 'dart:convert';

enum MeshPacketType {
  chat,
  sosBeacon,
  locationUpdate,
  ack,
  nodeHeartbeat,
}

class MeshPacket {
  final String packetId;
  final String senderId;
  final String senderName;
  final String receiverId; // 'BROADCAST' or specific Node ID
  final String content;
  final MeshPacketType packetType;
  final int ttl;
  final int hopCount;
  final List<String> relayedBy;
  final double? latitude;
  final double? longitude;
  final String? riskLevel;
  final double? riskScore;
  final String? riskReason;
  final DateTime timestampSent;

  MeshPacket({
    required this.packetId,
    required this.senderId,
    required this.senderName,
    this.receiverId = 'BROADCAST',
    required this.content,
    this.packetType = MeshPacketType.chat,
    this.ttl = 7,
    this.hopCount = 0,
    List<String>? relayedBy,
    this.latitude,
    this.longitude,
    this.riskLevel,
    this.riskScore,
    this.riskReason,
    DateTime? timestampSent,
  })  : relayedBy = relayedBy ?? [],
        timestampSent = timestampSent ?? DateTime.now();

  /// Create packet from JSON Map
  factory MeshPacket.fromJson(Map<String, dynamic> json) {
    return MeshPacket(
      packetId: json['packetId'] ?? '',
      senderId: json['senderId'] ?? '',
      senderName: json['senderName'] ?? 'Unknown Node',
      receiverId: json['receiverId'] ?? 'BROADCAST',
      content: json['content'] ?? '',
      packetType: _parseType(json['packetType']),
      ttl: json['ttl'] ?? 7,
      hopCount: json['hopCount'] ?? 0,
      relayedBy: List<String>.from(json['relayedBy'] ?? []),
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
      riskLevel: json['riskLevel']?.toString(),
      riskScore: (json['riskScore'] as num?)?.toDouble(),
      riskReason: json['riskReason']?.toString(),
      timestampSent: json['timestampSent'] != null
          ? DateTime.parse(json['timestampSent'])
          : DateTime.now(),
    );
  }

  /// Serialize to JSON Map
  Map<String, dynamic> toJson() {
    return {
      'packetId': packetId,
      'senderId': senderId,
      'senderName': senderName,
      'receiverId': receiverId,
      'content': content,
      'packetType': packetType.name,
      'ttl': ttl,
      'hopCount': hopCount,
      'relayedBy': relayedBy,
      'latitude': latitude,
      'longitude': longitude,
      'riskLevel': riskLevel,
      'riskScore': riskScore,
      'riskReason': riskReason,
      'timestampSent': timestampSent.toIso8601String(),
    };
  }

  /// Serialize packet payload to String for BLE/Wi-Fi Direct transmission
  String toPayloadString() => jsonEncode(toJson());

  /// Deserialize packet payload from raw String payload
  static MeshPacket fromPayloadString(String payload) {
    return MeshPacket.fromJson(jsonDecode(payload));
  }

  /// Returns a new packet instance with decremented TTL and incremented hopCount
  MeshPacket copyWithRelay(String currentRelayNodeId) {
    List<String> newRelays = List.from(relayedBy);
    if (!newRelays.contains(currentRelayNodeId)) {
      newRelays.add(currentRelayNodeId);
    }

    return MeshPacket(
      packetId: packetId,
      senderId: senderId,
      senderName: senderName,
      receiverId: receiverId,
      content: content,
      packetType: packetType,
      ttl: ttl - 1,
      hopCount: hopCount + 1,
      relayedBy: newRelays,
      latitude: latitude,
      longitude: longitude,
      riskLevel: riskLevel,
      riskScore: riskScore,
      riskReason: riskReason,
      timestampSent: timestampSent,
    );
  }

  static MeshPacketType _parseType(dynamic typeStr) {
    if (typeStr == null) return MeshPacketType.chat;
    final str = typeStr.toString().toLowerCase();
    if (str.contains('sos')) return MeshPacketType.sosBeacon;
    if (str.contains('location')) return MeshPacketType.locationUpdate;
    if (str.contains('ack')) return MeshPacketType.ack;
    if (str.contains('heartbeat')) return MeshPacketType.nodeHeartbeat;
    return MeshPacketType.chat;
  }
}
