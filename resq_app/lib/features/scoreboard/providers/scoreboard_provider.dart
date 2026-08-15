import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/utils/logger.dart';

class LeaderboardEntry {
  final int rank;
  final String userId;
  final String name;
  final String role;
  final int helpPoints;
  final int rescuesCompleted;

  const LeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.name,
    required this.role,
    required this.helpPoints,
    required this.rescuesCompleted,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      userId: json['userId']?.toString() ?? '',
      name: json['name']?.toString() ?? 'ResQ User',
      role: json['role']?.toString() ?? 'user',
      helpPoints: (json['helpPoints'] as num?)?.toInt() ?? 0,
      rescuesCompleted: (json['rescuesCompleted'] as num?)?.toInt() ?? 0,
    );
  }
}

class ScoreboardProvider extends ChangeNotifier {
  final DioClient _dioClient = DioClient();

  bool _isLoading = false;
  String? _errorMessage;
  int _helpPoints = 0;
  int _rescuesCompleted = 0;
  List<LeaderboardEntry> _leaderboard = [];

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get helpPoints => _helpPoints;
  int get rescuesCompleted => _rescuesCompleted;
  List<LeaderboardEntry> get leaderboard => List.unmodifiable(_leaderboard);

  Future<void> loadScoreboard() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final responses = await Future.wait([
        _dioClient.instance.get(ApiEndpoints.myScore),
        _dioClient.instance.get(ApiEndpoints.leaderboard),
      ]);

      final scoreResponse = responses[0];
      final leaderboardResponse = responses[1];

      if (scoreResponse.data['success'] != true) {
        throw Exception(scoreResponse.data['message'] ?? 'Unable to load your score.');
      }
      if (leaderboardResponse.data['success'] != true) {
        throw Exception(leaderboardResponse.data['message'] ?? 'Unable to load leaderboard.');
      }

      final scoreData = Map<String, dynamic>.from(scoreResponse.data['data'] as Map);
      final leaderboardData = leaderboardResponse.data['data'];

      _helpPoints = (scoreData['helpPoints'] as num?)?.toInt() ?? 0;
      _rescuesCompleted = (scoreData['rescuesCompleted'] as num?)?.toInt() ?? 0;
      _leaderboard = leaderboardData is List
          ? leaderboardData
              .whereType<Map>()
              .map((entry) => LeaderboardEntry.fromJson(Map<String, dynamic>.from(entry)))
              .toList()
          : [];
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        _errorMessage = 'Your session has expired. Please sign in again.';
      } else {
        _errorMessage = 'Unable to load the scoreboard. Please check your connection.';
      }
      AppLogger.error('Failed to load scoreboard', e, e.stackTrace, 'ScoreboardProvider');
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      AppLogger.error('Failed to load scoreboard', e, null, 'ScoreboardProvider');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
