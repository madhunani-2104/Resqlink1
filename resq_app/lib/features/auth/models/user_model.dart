class EmergencyContact {
  final String name;
  final String phone;
  final String relationship;

  EmergencyContact({
    required this.name,
    required this.phone,
    this.relationship = 'Family',
  });

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      relationship: json['relationship'] ?? 'Family',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phone': phone,
      'relationship': relationship,
    };
  }
}

class MedicalInfo {
  final String bloodGroup;
  final List<String> allergies;
  final List<String> chronicConditions;
  final List<String> medications;
  final String notes;

  MedicalInfo({
    this.bloodGroup = 'Unknown',
    List<String>? allergies,
    List<String>? chronicConditions,
    List<String>? medications,
    this.notes = '',
  })  : allergies = allergies ?? [],
        chronicConditions = chronicConditions ?? [],
        medications = medications ?? [];

  factory MedicalInfo.fromJson(Map<String, dynamic> json) {
    return MedicalInfo(
      bloodGroup: json['bloodGroup'] ?? 'Unknown',
      allergies: List<String>.from(json['allergies'] ?? []),
      chronicConditions: List<String>.from(json['chronicConditions'] ?? []),
      medications: List<String>.from(json['medications'] ?? []),
      notes: json['notes'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bloodGroup': bloodGroup,
      'allergies': allergies,
      'chronicConditions': chronicConditions,
      'medications': medications,
      'notes': notes,
    };
  }
}

class UserModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String meshId;
  final String avatar;
  final List<EmergencyContact> emergencyContacts;
  final MedicalInfo medicalInfo;
  final String? token;
  final int helpPoints;
  final int rescuesCompleted;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.role = 'user',
    required this.meshId,
    this.avatar = '',
    List<EmergencyContact>? emergencyContacts,
    MedicalInfo? medicalInfo,
    this.token,
    this.helpPoints = 0,
    this.rescuesCompleted = 0,
  })  : emergencyContacts = emergencyContacts ?? [],
        medicalInfo = medicalInfo ?? MedicalInfo();

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      role: json['role'] ?? 'user',
      meshId: json['meshId'] ?? 'NODE-001',
      avatar: json['avatar'] ?? '',
      emergencyContacts: json['emergencyContacts'] != null
          ? (json['emergencyContacts'] as List)
              .map((c) => EmergencyContact.fromJson(c))
              .toList()
          : [],
      medicalInfo: json['medicalInfo'] != null
          ? MedicalInfo.fromJson(json['medicalInfo'])
          : MedicalInfo(),
      token: json['token'],
      helpPoints: (json['helpPoints'] as num?)?.toInt() ?? 0,
      rescuesCompleted: (json['rescuesCompleted'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'meshId': meshId,
      'avatar': avatar,
      'emergencyContacts': emergencyContacts.map((c) => c.toJson()).toList(),
      'medicalInfo': medicalInfo.toJson(),
      'token': token,
      'helpPoints': helpPoints,
      'rescuesCompleted': rescuesCompleted,
    };
  }
}
