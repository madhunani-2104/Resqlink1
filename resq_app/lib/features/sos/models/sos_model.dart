class SosModel {
  final String id;
  final String sosId;
  final String userId;
  final String userName;
  final String userPhone;
  final double latitude;
  final double longitude;
  final double altitude;
  final double accuracy;
  final int batteryLevel;
  final String status; // 'ACTIVE', 'ACKNOWLEDGED', 'RESCUED', 'CANCELLED'
  final String severity; // 'LOW', 'MEDIUM', 'HIGH', 'CRITICAL'
  final String? riskLevel; // 'LOW', 'MEDIUM', 'HIGH'
  final double? riskScore;
  final String riskReason;
  final DateTime? riskPredictedAt;
  final String notes;
  final bool isMeshRelayed;
  final int relayHops;
  final DateTime createdAt;

  SosModel({
    this.id = '',
    required this.sosId,
    required this.userId,
    required this.userName,
    required this.userPhone,
    required this.latitude,
    required this.longitude,
    this.altitude = 0.0,
    this.accuracy = 0.0,
    this.batteryLevel = 100,
    this.status = 'ACTIVE',
    this.severity = 'CRITICAL',
    this.riskLevel,
    this.riskScore,
    this.riskReason = '',
    this.riskPredictedAt,
    this.notes = '',
    this.isMeshRelayed = false,
    this.relayHops = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory SosModel.fromJson(Map<String, dynamic> json) {
    return SosModel(
      id: json['_id'] ?? json['id'] ?? '',
      sosId: json['sosId'] ?? '',
      userId: json['userId'] is Map ? json['userId']['_id'] : (json['userId'] ?? ''),
      userName: json['userName'] ?? 'Victim',
      userPhone: json['userPhone'] ?? '',
      latitude: json['location'] != null
          ? (json['location']['latitude'] as num).toDouble()
          : (json['latitude'] != null ? (json['latitude'] as num).toDouble() : 0.0),
      longitude: json['location'] != null
          ? (json['location']['longitude'] as num).toDouble()
          : (json['longitude'] != null ? (json['longitude'] as num).toDouble() : 0.0),
      altitude: json['location'] != null
          ? (json['location']['altitude'] as num? ?? 0.0).toDouble()
          : (json['altitude'] as num? ?? 0.0).toDouble(),
      accuracy: json['location'] != null
          ? (json['location']['accuracy'] as num? ?? 0.0).toDouble()
          : (json['accuracy'] as num? ?? 0.0).toDouble(),
      batteryLevel: json['batteryLevel'] ?? 100,
      status: json['status'] ?? 'ACTIVE',
      severity: json['severity'] ?? 'CRITICAL',
      riskLevel: json['riskLevel']?.toString(),
      riskScore: (json['riskScore'] as num?)?.toDouble(),
      riskReason: json['riskReason'] ?? '',
      riskPredictedAt: json['riskPredictedAt'] != null ? DateTime.tryParse(json['riskPredictedAt'].toString()) : null,
      notes: json['notes'] ?? '',
      isMeshRelayed: json['isMeshRelayed'] == 1 || json['isMeshRelayed'] == true,
      relayHops: json['relayHops'] ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'sosId': sosId,
      'userId': userId,
      'userName': userName,
      'userPhone': userPhone,
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'accuracy': accuracy,
      'batteryLevel': batteryLevel,
      'status': status,
      'severity': severity,
      'riskLevel': riskLevel,
      'riskScore': riskScore,
      'riskReason': riskReason,
      'riskPredictedAt': riskPredictedAt?.toIso8601String(),
      'notes': notes,
      'isMeshRelayed': isMeshRelayed ? 1 : 0,
      'relayHops': relayHops,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
