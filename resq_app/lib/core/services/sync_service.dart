import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';

import '../constants/api_endpoints.dart';
import '../database/db_helper.dart';
import '../network/dio_client.dart';
import '../utils/logger.dart';

class SyncService {
  final DioClient _dioClient = DioClient();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  Timer? _syncTimer;

  bool _isSyncing = false;
  bool _isStarted = false;

  void startSyncListener() {
    if (_isStarted) {
      return;
    }

    _isStarted = true;

    AppLogger.info(
      'Initializing Automatic Offline Sync Listener...',
      'SyncService',
    );

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        final bool isConnected = results.any(
          (ConnectivityResult result) => result != ConnectivityResult.none,
        );

        if (isConnected) {
          AppLogger.info(
            'Network Connection Restored! Triggering Auto Sync...',
            'SyncService',
          );

          unawaited(syncPendingData());
        }
      },
    );

    _syncTimer = Timer.periodic(
      const Duration(seconds: 30),
      (Timer timer) {
        unawaited(syncPendingData());
      },
    );
  }

  Future<void> syncPendingData() async {
    if (_isSyncing) {
      return;
    }

    _isSyncing = true;

    try {
      final List<Map<String, dynamic>> queueItems =
          await DBHelper.instance.getSyncQueue();

      if (queueItems.isEmpty) {
        return;
      }

      AppLogger.info(
        'Processing ${queueItems.length} items from offline sync queue...',
        'SyncService',
      );

      final List<Map<String, dynamic>> itemsToSend = <Map<String, dynamic>>[];

      for (final Map<String, dynamic> item in queueItems) {
        final dynamic payload = item['payload'];

        itemsToSend.add(
          <String, dynamic>{
            'id': item['id'],
            'dataType': item['dataType'],
            'payload': payload is String ? jsonDecode(payload) : payload,
          },
        );
      }

      final Response<dynamic> response =
          await _dioClient.instance.post<dynamic>(
        ApiEndpoints.syncBatch,
        data: <String, dynamic>{
          'items': itemsToSend,
          'deviceId': 'FLUTTER_CLIENT_DEVICE',
        },
      );

      final dynamic responseData = response.data;

      final bool syncSuccessful = response.statusCode == 200 &&
          responseData is Map &&
          responseData['success'] == true;

      if (syncSuccessful) {
        AppLogger.info(
          'Sync Successful! Clearing processed items...',
          'SyncService',
        );

        for (final Map<String, dynamic> item in queueItems) {
          final dynamic id = item['id'];

          if (id is int) {
            await DBHelper.instance.deleteSyncQueueItem(id);
          }
        }
      }
    } catch (e, stackTrace) {
      AppLogger.warning(
        'Sync attempt deferred: ${e.toString()}',
        'SyncService',
      );

      AppLogger.error(
        'Offline sync error',
        e,
        stackTrace,
        'SyncService',
      );
    } finally {
      _isSyncing = false;
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;

    _syncTimer?.cancel();
    _syncTimer = null;

    _isStarted = false;
  }
}
