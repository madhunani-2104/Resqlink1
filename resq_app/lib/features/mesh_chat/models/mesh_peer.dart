class MeshPeer {
  final String id;
  final String name;
  final String transport;
  final int signal;
  final DateTime lastSeen;
  final String? ipAddress;

  MeshPeer({
    required this.id,
    required this.name,
    required this.transport,
    this.signal = 0,
    DateTime? lastSeen,
    this.ipAddress,
  }) : lastSeen = lastSeen ?? DateTime.now();

  factory MeshPeer.fromJson(
    Map<String, dynamic> json,
  ) {
    return MeshPeer(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Nearby Device',
      transport: json['transport']?.toString() ?? 'Mesh',
      signal: json['signal'] is int
          ? json['signal'] as int
          : int.tryParse(
                json['signal']?.toString() ?? '0',
              ) ??
              0,
      ipAddress: json['ipAddress']?.toString() ?? json['ip']?.toString(),
      lastSeen: DateTime.tryParse(
            json['lastSeen']?.toString() ?? '',
          ) ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'transport': transport,
      'signal': signal,
      'lastSeen': lastSeen.toIso8601String(),
      if (ipAddress != null) 'ipAddress': ipAddress,
    };
  }
}
