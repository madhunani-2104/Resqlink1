class ApiEndpoints {
  // ============================================================
  // BACKEND
  // ============================================================

  // PC IP:
  // 192.168.0.128
  //
  // Backend:
  // http://192.168.0.128:5000
  //
  // API:
  // http://192.168.0.128:5000/api
  //
  // IMPORTANT:
  // Phone and PC must be connected to the same Wi-Fi.
  //
  // Backend should listen on:
  // 0.0.0.0:5000
  //
  // NOT only:
  // localhost:5000

  static const String baseUrl = 'http://192.168.0.128:5000/api';

  static const String webBaseUrl = 'http://192.168.0.128:5000/api';

  // ============================================================
  // AUTH
  // ============================================================

  static const String login = '/auth/login';

  static const String register = '/auth/register';

  static const String rescueLogin = '/auth/rescue-login';

  static const String rescueRegister = '/auth/rescue-register';

  static const String forgotPassword = '/auth/forgot-password';

  static const String resetPassword = '/auth/reset-password';

  static const String me = '/auth/me';

  // ============================================================
  // USER
  // ============================================================

  static const String updateProfile = '/user/profile';

  static const String updateLocation = '/user/location';

  static const String myScore = '/user/score';

  static const String leaderboard = '/user/leaderboard';

  // ============================================================
  // SOS
  // ============================================================

  static const String sos = '/sos';

  static const String activeSos = '/sos/active';

  static String acknowledgeSos(String id) {
    return '/sos/$id/acknowledge';
  }

  static String resolveSos(String id) {
    return '/sos/$id/resolve';
  }

  static String cancelSos(String id) {
    return '/sos/$id/cancel';
  }

  // ============================================================
  // MESH
  // ============================================================

  static const String meshMessage = '/mesh/message';

  static const String meshMessages = '/mesh/messages';

  static const String syncBatch = '/mesh/sync-batch';

  static const String uploadMeshFile = '/mesh/files';

  static String downloadMeshFile(String fileId) {
    return '/mesh/files/$fileId';
  }

  // ============================================================
  // MAP
  // ============================================================

  static const String mapLayers = '/map/layers';

  static const String safeZone = '/map/safe-zone';

  static const String shelter = '/map/shelter';

  // ============================================================
  // ADMIN
  // ============================================================

  static const String adminStats = '/admin/stats';

  static const String adminUsers = '/admin/users';
}
