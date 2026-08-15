import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'tables.dart';
import '../utils/logger.dart';

class DBHelper {
  static final DBHelper instance = DBHelper._init();
  static Database? _database;

  DBHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('resq_offline.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    // If Web or Desktop (Windows/Linux/Mac), use sqflite_common_ffi
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.linux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, filePath);
      return await openDatabase(
        path,
        version: 2,
        onCreate: _createDB,
        onUpgrade: _upgradeDB,
      );
    } else {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, filePath);
      return await openDatabase(
        path,
        version: 2,
        onCreate: _createDB,
        onUpgrade: _upgradeDB,
      );
    }
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE ${Tables.tableSosAlerts} ADD COLUMN riskLevel TEXT');
      await db.execute('ALTER TABLE ${Tables.tableSosAlerts} ADD COLUMN riskScore REAL');
      await db.execute('ALTER TABLE ${Tables.tableSosAlerts} ADD COLUMN riskReason TEXT');
      await db.execute('ALTER TABLE ${Tables.tableSosAlerts} ADD COLUMN riskPredictedAt TEXT');
    }
  }

  Future<void> _createDB(Database db, int version) async {
    AppLogger.info('Creating SQLite Database Tables...', 'DBHelper');
    await db.execute(Tables.createTableMessages);
    await db.execute(Tables.createTableSosAlerts);
    await db.execute(Tables.createTableSyncQueue);
    await db.execute(Tables.createTableSafeZones);
    await db.execute(Tables.createTableShelters);
  }

  // Insert or Replace Message
  Future<int> insertMessage(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert(
      Tables.tableMessages,
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Get all offline messages
  Future<List<Map<String, dynamic>>> getMessages() async {
    final db = await instance.database;
    return await db.query(Tables.tableMessages, orderBy: 'timestampSent ASC');
  }

  // Insert SOS Alert
  Future<int> insertSosAlert(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert(
      Tables.tableSosAlerts,
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Get SOS Alerts
  Future<List<Map<String, dynamic>>> getSosAlerts() async {
    final db = await instance.database;
    return await db.query(Tables.tableSosAlerts, orderBy: 'createdAt DESC');
  }

  // Add item to offline sync queue
  Future<int> addToSyncQueue(String dataType, String payload) async {
    final db = await instance.database;
    return await db.insert(Tables.tableSyncQueue, {
      'dataType': dataType,
      'payload': payload,
      'createdAt': DateTime.now().toIso8601String(),
      'retryCount': 0,
    });
  }

  // Get all pending sync queue items
  Future<List<Map<String, dynamic>>> getSyncQueue() async {
    final db = await instance.database;
    return await db.query(Tables.tableSyncQueue, orderBy: 'id ASC');
  }

  // Remove item from sync queue after successful sync
  Future<int> deleteSyncQueueItem(int id) async {
    final db = await instance.database;
    return await db.delete(Tables.tableSyncQueue, where: 'id = ?', whereArgs: [id]);
  }

  // Clear all database tables (Reset Data)
  Future<void> clearAllData() async {
    final db = await instance.database;
    await db.delete(Tables.tableMessages);
    await db.delete(Tables.tableSosAlerts);
    await db.delete(Tables.tableSyncQueue);
    await db.delete(Tables.tableSafeZones);
    await db.delete(Tables.tableShelters);
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
