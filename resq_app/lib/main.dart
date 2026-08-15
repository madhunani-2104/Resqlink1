import 'package:flutter/material.dart';
import 'app.dart';
import 'core/services/sync_service.dart';
import 'core/services/notification_service.dart';
import 'core/utils/logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  AppLogger.info('Starting ResQ Emergency Mesh Application...', 'Main');
  
  // Initialize Notification Service
  await NotificationService.initialize();

  // Start background auto-sync worker
  final syncService = SyncService();
  syncService.startSyncListener();

  runApp(const ResQApp());
}
