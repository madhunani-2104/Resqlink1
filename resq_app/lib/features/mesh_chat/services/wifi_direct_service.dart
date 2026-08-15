import 'dart:async';
import 'package:flutter/services.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/mesh_packet.dart';
import 'mesh_router.dart';

class WifiDirectService {
  static const MethodChannel _channel = MethodChannel(AppConstants.channelWifiDirect);
  final MeshRouter meshRouter;
  final void Function(Map<String, dynamic> peer)? onPeerDiscovered;
  bool isP2pConnected = false;

  WifiDirectService({required this.meshRouter, this.onPeerDiscovered}) {
    _channel.setMethodCallHandler(_handleNativeMethodCall);
  }

  Future<void> discoverPeers() async {
    try {
      AppLogger.info('Discovering Wi-Fi Direct (P2P) Emergency Peers...', 'WifiDirectService');
      await _channel.invokeMethod('discoverPeers');
    } catch (e) {
      AppLogger.warning('Native Wi-Fi Direct discovery fallback: $e', 'WifiDirectService');
    }
  }

  Future<void> sendPacketP2P(MeshPacket packet) async {
    try {
      AppLogger.info('Sending Wi-Fi Direct P2P Packet: ${packet.packetId}', 'WifiDirectService');
      await _channel.invokeMethod('sendPacket', {
        'packetData': packet.toPayloadString(),
      });
    } catch (e) {
      AppLogger.warning('Wi-Fi Direct P2P send failed or permission was denied: $e', 'WifiDirectService');
    }
  }

  Future<dynamic> _handleNativeMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onP2pPacketReceived':
        final String rawPayload = call.arguments['packetData'];
        final packet = MeshPacket.fromPayloadString(rawPayload);
        await meshRouter.processIncomingPacket(packet);
        break;
      case 'onPeerDiscovered':
        final peer = Map<String, dynamic>.from(call.arguments as Map);
        onPeerDiscovered?.call(peer);
        break;
      default:
        AppLogger.warning('Unknown method ${call.method} on Wi-Fi Direct channel', 'WifiDirectService');
    }
  }
}
