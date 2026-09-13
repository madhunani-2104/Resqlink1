class SafeZoneModel {
  final String id;
  final String name;
  final String description;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final String zoneType;
  final String status;
  final String contactPhone;

  SafeZoneModel({
    required this.id,
    required this.name,
    this.description = '',
    required this.latitude,
    required this.longitude,
    this.radiusMeters = 500,
    this.zoneType = 'SAFE_HAVEN',
    this.status = 'OPEN',
    this.contactPhone = '',
  });

  factory SafeZoneModel.fromJson(Map<String, dynamic> json) {
    return SafeZoneModel(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      latitude: _coordinateFromJson(json['latitude']),
      longitude: _coordinateFromJson(json['longitude']),
      radiusMeters: (json['radiusMeters'] as num? ?? 500).toDouble(),
      zoneType: json['zoneType'] ?? 'SAFE_HAVEN',
      status: json['status'] ?? 'OPEN',
      contactPhone: json['contactPhone'] ?? '',
    );
  }
}

class ShelterModel {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String phone;
  final int capacity;
  final int currentOccupants;
  final List<String> amenities;
  final String status;

  ShelterModel({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.phone = '',
    required this.capacity,
    this.currentOccupants = 0,
    List<String>? amenities,
    this.status = 'OPERATIONAL',
  }) : amenities = amenities ?? ['Food', 'Water', 'Medical'];

  factory ShelterModel.fromJson(Map<String, dynamic> json) {
    return ShelterModel(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      latitude: _coordinateFromJson(json['latitude']),
      longitude: _coordinateFromJson(json['longitude']),
      phone: json['phone'] ?? '',
      capacity: json['capacity'] ?? 100,
      currentOccupants: json['currentOccupants'] ?? 0,
      amenities: List<String>.from(json['amenities'] ?? []),
      status: json['status'] ?? 'OPERATIONAL',
    );
  }
}

double _coordinateFromJson(dynamic value) {
  return value is num ? value.toDouble() : 0;
}
