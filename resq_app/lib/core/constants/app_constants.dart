class AppConstants {
  static const String appName = 'ResQ';
  static const String appTagline = 'Offline Mesh & Emergency SOS System';

  // Shared Preferences Keys
  static const String keyAuthToken = 'auth_token';
  static const String keyUserData = 'user_data';
  static const String keyIsDarkMode = 'is_dark_mode';
  static const String keyMeshEnabled = 'mesh_enabled';
  static const String keyWebSimulatedNodeCount = 'web_sim_node_count';

  // Mesh Default Parameters
  static const int defaultTTL = 7;
  static const int maxHopCount = 10;
  static const int meshBroadcastIntervalSec = 15;
  static const int syncCheckIntervalSec = 20;

  // Platform Channel Names
  static const String channelBleMesh = 'com.resq.app/ble_mesh';
  static const String channelWifiDirect = 'com.resq.app/wifi_direct';
  static const String channelEmergencyContacts = 'com.resq.app/emergency_contacts';
  static const String channelVoiceRecorder = 'com.resq.app/voice_recorder';
  static const String channelFileAccess = 'com.resq.app/file_access';
}
