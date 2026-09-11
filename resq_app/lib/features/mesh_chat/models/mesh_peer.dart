class MeshPeer {
  final String id;
  final String name;
  final String transport;
  final int signal;
  final DateTime lastSeen;
  final String? nodeId;
  final String? address;
  final String? ipAddress;
  final String connectionState;
  final bool connected;

  MeshPeer({
    required this.id,
    required this.name,
    required this.transport,
    this.signal = 0,
    DateTime? lastSeen,
    this.nodeId,
    this.address,
    this.ipAddress,
    this.connectionState = 'discovered',
    this.connected = false,
  }) : lastSeen = lastSeen ?? DateTime.now();

  factory MeshPeer.fromJson(Map<String, dynamic> json) {
    return MeshPeer(
      id: json['id']?.toString() ?? '',
      nodeId: json['nodeId']?.toString(),
      address: json['address']?.toString(),
      name: json['name']?.toString() ?? 'Nearby Device',
      transport: json['transport']?.toString() ?? 'Mesh',
      signal: json['signal'] is int
          ? json['signal'] as int
          : int.tryParse(json['signal']?.toString() ?? '0') ?? 0,
      ipAddress: json['ipAddress']?.toString() ?? json['ip']?.toString(),
      connectionState: json['connectionState']?.toString() ?? 'discovered',
      connected: json['connected'] == true,
      lastSeen:
          DateTime.tryParse(json['lastSeen']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (nodeId != null) 'nodeId': nodeId,
      if (address != null) 'address': address,
      'name': name,
      'transport': transport,
      'signal': signal,
      'lastSeen': lastSeen.toIso8601String(),
      'connectionState': connectionState,
      'connected': connected,
      if (ipAddress != null) 'ipAddress': ipAddress,
    };
  }
}
