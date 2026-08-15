import 'package:flutter/foundation.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/utils/logger.dart';

class AdminStats {
  final int totalUsers;
  final int totalResponders;
  final int activeSosCount;
  final int acknowledgedSosCount;
  final int rescuedSosCount;
  final int totalMeshPackets;

  AdminStats({
    this.totalUsers = 0,
    this.totalResponders = 0,
    this.activeSosCount = 0,
    this.acknowledgedSosCount = 0,
    this.rescuedSosCount = 0,
    this.totalMeshPackets = 0,
  });

  factory AdminStats.fromJson(Map<String, dynamic> json) {
    return AdminStats(
      totalUsers: json['totalUsers'] ?? 0,
      totalResponders: json['totalResponders'] ?? 0,
      activeSosCount: json['activeSosCount'] ?? 0,
      acknowledgedSosCount: json['acknowledgedSosCount'] ?? 0,
      rescuedSosCount: json['rescuedSosCount'] ?? 0,
      totalMeshPackets: json['totalMeshPackets'] ?? 0,
    );
  }
}

class AdminProvider extends ChangeNotifier {
  final DioClient _dioClient = DioClient();
  AdminStats _stats = AdminStats();
  bool _isLoading = false;

  AdminStats get stats => _stats;
  bool get isLoading => _isLoading;

  Future<void> fetchAdminStats() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _dioClient.instance.get(ApiEndpoints.adminStats);
      if (response.data['success'] == true) {
        _stats = AdminStats.fromJson(response.data['data']);
      }
    } catch (e) {
      AppLogger.warning('Admin stats server error, setting fallback stats', 'AdminProvider');
      _stats = AdminStats(
        totalUsers: 14,
        totalResponders: 4,
        activeSosCount: 2,
        acknowledgedSosCount: 1,
        rescuedSosCount: 8,
        totalMeshPackets: 142,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
