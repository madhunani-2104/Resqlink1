class Tables {
  static const String tableMessages = 'mesh_messages';
  static const String tableSosAlerts = 'sos_alerts';
  static const String tableSyncQueue = 'sync_queue';
  static const String tableSafeZones = 'safe_zones';
  static const String tableShelters = 'shelters';

  static const String createTableMessages = '''
    CREATE TABLE $tableMessages (
      packetId TEXT PRIMARY KEY,
      senderId TEXT NOT NULL,
      senderName TEXT NOT NULL,
      receiverId TEXT NOT NULL,
      content TEXT NOT NULL,
      packetType TEXT NOT NULL,
      ttl INTEGER NOT NULL,
      hopCount INTEGER NOT NULL,
      relayedBy TEXT,
      latitude REAL,
      longitude REAL,
      timestampSent TEXT NOT NULL,
      isSynced INTEGER DEFAULT 0
    )
  ''';

  static const String createTableSosAlerts = '''
    CREATE TABLE $tableSosAlerts (
      sosId TEXT PRIMARY KEY,
      userId TEXT NOT NULL,
      userName TEXT NOT NULL,
      userPhone TEXT NOT NULL,
      latitude REAL NOT NULL,
      longitude REAL NOT NULL,
      batteryLevel INTEGER DEFAULT 100,
      severity TEXT NOT NULL,
      riskLevel TEXT,
      riskScore REAL,
      riskReason TEXT,
      riskPredictedAt TEXT,
      status TEXT NOT NULL,
      notes TEXT,
      isMeshRelayed INTEGER DEFAULT 0,
      relayHops INTEGER DEFAULT 0,
      createdAt TEXT NOT NULL,
      isSynced INTEGER DEFAULT 0
    )
  ''';

  static const String createTableSyncQueue = '''
    CREATE TABLE $tableSyncQueue (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      dataType TEXT NOT NULL,
      payload TEXT NOT NULL,
      createdAt TEXT NOT NULL,
      retryCount INTEGER DEFAULT 0
    )
  ''';

  static const String createTableSafeZones = '''
    CREATE TABLE $tableSafeZones (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      description TEXT,
      latitude REAL NOT NULL,
      longitude REAL NOT NULL,
      radiusMeters REAL DEFAULT 500,
      zoneType TEXT DEFAULT 'SAFE_HAVEN',
      status TEXT DEFAULT 'OPEN',
      contactPhone TEXT,
      capacity INTEGER DEFAULT 200
    )
  ''';

  static const String createTableShelters = '''
    CREATE TABLE $tableShelters (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      address TEXT NOT NULL,
      latitude REAL NOT NULL,
      longitude REAL NOT NULL,
      phone TEXT,
      capacity INTEGER NOT NULL,
      currentOccupants INTEGER DEFAULT 0,
      amenities TEXT,
      status TEXT DEFAULT 'OPERATIONAL'
    )
  ''';
}
