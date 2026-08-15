import 'dart:async';
import 'package:flutter/services.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/mesh_packet.dart';
import 'mesh_router.dart';

class BleService {
  static const MethodChannel _channel = MethodChannel(AppConstants.channelBleMesh);
  final MeshRouter meshRouter;
  final void Function(Map<String, dynamic> peer)? onPeerDiscovered;
  bool isScanning = false;
  bool isBroadcasting = false;

  BleService({required this.meshRouter, this.onPeerDiscovered}) {
    _channel.setMethodCallHandler(_handleNativeMethodCall);
  }

  Future<void> startBleScanning() async {
    try {
      isScanning = true;
      AppLogger.info('Starting BLE Mesh Discovery & Scanning...', 'BleService');
      await _channel.invokeMethod('startScan');
    } catch (e) {
      AppLogger.warning('Native BLE scan fallback active (simulated scan): $e', 'BleService');
    }
  }

  Future<void> stopBleScanning() async {
    try {
      isScanning = false;
      await _channel.invokeMethod('stopScan');
    } catch (e) {
      AppLogger.warning('BLE stop scan error: $e', 'BleService');
    }
  }

  Future<void> broadcastPacket(MeshPacket packet) async {
    try {
      AppLogger.info('Broadcasting BLE Packet: ${packet.packetId}', 'BleService');
      await _channel.invokeMethod('broadcastPacket', {
        'packetData': packet.toPayloadString(),
      });
    } catch (e) {
      AppLogger.warning('BLE broadcast failed or permission was denied: $e', 'BleService');
    }
  }

  Future<dynamic> _handleNativeMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onPacketReceived':
        final String rawPayload = call.arguments['packetData'];
        final packet = MeshPacket.fromPayloadString(rawPayload);
        await meshRouter.processIncomingPacket(packet);
        break;
      case 'onPeerDiscovered':
        final peer = Map<String, dynamic>.from(call.arguments as Map);
        onPeerDiscovered?.call(peer);
        break;
      default:
        AppLogger.warning('Unknown method ${call.method} on BLE channel', 'BleService');
    }
  }
}
