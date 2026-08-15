import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import 'call_service.dart';

class CallOverlay extends StatelessWidget {
  const CallOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CallProvider>(
      builder: (context, call, child) {
        if (call.incomingCall != null) return _IncomingCallCard(call: call);
        if (call.hasActiveCall) return _ActiveCallOverlay(call: call);
        if (call.errorMessage != null) {
          return Positioned(
            left: 16,
            right: 16,
            bottom: 90,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(call.errorMessage!, textAlign: TextAlign.center),
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class _IncomingCallCard extends StatelessWidget {
  final CallProvider call;
  const _IncomingCallCard({required this.call});

  @override
  Widget build(BuildContext context) {
    final incoming = call.incomingCall!;
    final video = incoming.type == CallType.video;
    return Positioned(
      left: 18,
      right: 18,
      top: 70,
      child: Card(
        elevation: 8,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(video ? Icons.videocam_rounded : Icons.call_rounded, color: AppColors.primary, size: 32),
              const SizedBox(height: 8),
              Text(incoming.callerName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(video ? 'Incoming video call' : 'Incoming audio call'),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: call.rejectIncomingCall,
                    icon: const Icon(Icons.call_end),
                    label: const Text('Reject'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: call.acceptIncomingCall,
                    icon: Icon(video ? Icons.videocam : Icons.call),
                    label: const Text('Accept'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveCallOverlay extends StatelessWidget {
  final CallProvider call;
  const _ActiveCallOverlay({required this.call});

  @override
  Widget build(BuildContext context) {
    final video = call.isVideoCall;
    return Positioned.fill(
      child: Material(
        color: Colors.black.withOpacity(0.94),
        child: SafeArea(
          child: Stack(
            children: [
              if (video)
                Positioned.fill(
                  child: RTCVideoView(
                    call.remoteRenderer,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                )
              else
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(radius: 42, child: Text((call.peerName ?? 'R').substring(0, 1).toUpperCase())),
                      const SizedBox(height: 12),
                      Text(call.peerName ?? 'ResQ User', style: const TextStyle(color: Colors.white, fontSize: 18)),
                      const SizedBox(height: 6),
                      Text(call.status == CallStatus.connected ? 'Connected' : 'Connecting...', style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
              if (video && call.localStream != null)
                Positioned(
                  top: 16,
                  right: 16,
                  width: 110,
                  height: 150,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: RTCVideoView(call.localRenderer, mirror: true),
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 18,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FloatingActionButton(
                      heroTag: 'mute_call',
                      onPressed: call.toggleMute,
                      child: const Icon(Icons.mic_off_rounded),
                    ),
                    if (video) ...[
                      const SizedBox(width: 14),
                      FloatingActionButton(
                        heroTag: 'camera_call',
                        onPressed: call.toggleCamera,
                        child: const Icon(Icons.videocam_off_rounded),
                      ),
                    ],
                    const SizedBox(width: 14),
                    FloatingActionButton(
                      heroTag: 'end_call',
                      backgroundColor: Colors.red,
                      onPressed: call.endCall,
                      child: const Icon(Icons.call_end_rounded),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 12,
                left: 16,
                child: Text(call.peerName ?? 'ResQ User', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
