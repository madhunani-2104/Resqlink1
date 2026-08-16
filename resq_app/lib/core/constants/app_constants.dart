class AppConstants {
  AppConstants._();

  // ============================================================
  // APPLICATION
  // ============================================================

  static const String appName = 'ResQ';

  // ============================================================
  // METHOD CHANNELS
  // ============================================================

  static const String channelEmergencyContacts = 'resq_app/emergency_contacts';

  static const String channelFileAccess = 'resq_app/file_access';

  static const String channelBleMesh = 'resq_app/ble_mesh';

  static const String channelWifiDirect = 'resq_app/wifi_direct';

  // ============================================================
  // SHARED PREFERENCES KEYS
  // ============================================================

  static const String keyAuthToken = 'auth_token';

  static const String keyUserData = 'user_data';

  static const String keyIsDarkMode = 'is_dark_mode';

  // ============================================================
  // NETWORK
  // ============================================================

  static const String apiBaseUrl = 'http://192.168.0.128:5000/api';

  static const String webBaseUrl = 'http://192.168.0.128:5000/api';

  // ============================================================
  // TIMEOUTS
  // ============================================================

  static const Duration connectTimeout = Duration(seconds: 15);

  static const Duration receiveTimeout = Duration(seconds: 30);

  static const Duration sendTimeout = Duration(seconds: 30);
}
