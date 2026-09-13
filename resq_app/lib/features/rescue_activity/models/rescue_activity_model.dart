class RescueActivityModel {
  final String id;
  final String rescuerName;
  final String rescuerRole;
  final String emergencyType;
  final String identifiedBy;
  final String actionsTaken;
  final String outcome;
  final String victimName;
  final double latitude;
  final double longitude;
  final String address;
  final String severity;
  final String? riskLevel;
  final double? riskScore;
  final DateTime completedAt;
  final String? feedback;
  final int points;

  const RescueActivityModel({
    required this.id,
    required this.rescuerName,
    required this.rescuerRole,
    required this.emergencyType,
    required this.identifiedBy,
    required this.actionsTaken,
    required this.outcome,
    required this.victimName,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.severity,
    required this.riskLevel,
    required this.riskScore,
    required this.completedAt,
    required this.feedback,
    required this.points,
  });

  factory RescueActivityModel.fromJson(Map<String, dynamic> json) {
    final rescuer = json['rescuer'] is Map
        ? Map<String, dynamic>.from(json['rescuer'] as Map)
        : <String, dynamic>{};
    final victim = json['victim'] is Map
        ? Map<String, dynamic>.from(json['victim'] as Map)
        : <String, dynamic>{};
    final location = json['location'] is Map
        ? Map<String, dynamic>.from(json['location'] as Map)
        : <String, dynamic>{};
    final hazard = json['hazard'] is Map
        ? Map<String, dynamic>.from(json['hazard'] as Map)
        : <String, dynamic>{};

    return RescueActivityModel(
      id: json['id']?.toString() ?? '',
      rescuerName: rescuer['name']?.toString() ?? 'Unknown rescuer',
      rescuerRole: rescuer['role']?.toString() ?? '',
      emergencyType: json['emergencyType']?.toString() ?? '',
      identifiedBy: json['identifiedBy']?.toString() ?? '',
      actionsTaken: json['actionsTaken']?.toString() ?? '',
      outcome: json['outcome']?.toString() ?? '',
      victimName: victim['name']?.toString() ?? 'Unknown victim',
      latitude: (location['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (location['longitude'] as num?)?.toDouble() ?? 0,
      address: location['address']?.toString() ?? '',
      severity: hazard['severity']?.toString() ?? '',
      riskLevel: hazard['riskLevel']?.toString(),
      riskScore: (hazard['riskScore'] as num?)?.toDouble(),
      completedAt:
          DateTime.tryParse(json['completedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      feedback: json['feedback']?.toString(),
      points: (json['points'] as num?)?.toInt() ?? 0,
    );
  }
}
