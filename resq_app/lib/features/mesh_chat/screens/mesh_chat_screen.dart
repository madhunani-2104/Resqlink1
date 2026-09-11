import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/mesh_chat_provider.dart';
import 'chat_room_screen.dart';

import '../../../core/constants/app_colors.dart';

import '../../calling/call_service.dart';

class MeshChatScreen extends StatelessWidget {
  const MeshChatScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<MeshChatProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Mesh Channels'),
        actions: [
          IconButton(
            tooltip: 'Rescan nearby devices',
            icon: const Icon(Icons.sync_rounded),
            onPressed: () {
              chatProvider.startMeshNetworking();

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Scanning for nearby mesh devices...'),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ====================================================
          // NETWORK STATUS
          // ====================================================

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            color: AppColors.darkCard,
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: chatProvider.isMeshActive
                        ? AppColors.meshConnected
                        : Colors.orange,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chatProvider.isMeshActive
                            ? 'Mesh Network Active'
                            : 'Mesh Network Searching',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        chatProvider.discoveryState,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white60,
                        ),
                      ),
                      if (chatProvider.meshError != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          chatProvider.meshError!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.orangeAccent,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  chatProvider.isScanning
                      ? '...'
                      : '${chatProvider.activePeersCount}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildChannelCard(
                  context,
                  title: 'Emergency Broadcast Channel',
                  subtitle: 'Public multi-hop broadcast for all nearby victims and rescue teams',
                  icon: Icons.cell_tower,
                  badgeText: '${chatProvider.messages.length} msgs',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ChatRoomScreen(
                          channelName: 'Emergency Broadcast Channel',
                          receiverId: 'BROADCAST',
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildChannelCard(
                  context,
                  title: 'Rescue Team Ops',
                  subtitle: 'Tactical channel for rescue teams, coordinators, and medics',
                  icon: Icons.shield_outlined,
                  badgeText: 'Secure',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ChatRoomScreen(
                          channelName: 'Rescue Team Ops',
                          receiverId: 'RESPONDERS_OPS',
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                const Text(
                  'Nearby Devices',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (chatProvider.peers.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.devices_other, color: Colors.white54),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'No nearby mesh devices discovered yet.\nKeep Bluetooth, Wi-Fi and location enabled.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white60,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...chatProvider.peers.map(
                    (peer) => Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary.withOpacity(0.15),
                          child: Icon(
                            peer.transport == 'BLE'
                                ? Icons.bluetooth
                                : Icons.wifi,
                            color: peer.transport == 'BLE'
                                ? AppColors.bleActive
                                : AppColors.wifiDirectActive,
                          ),
                        ),
                        title: Text(
                          peer.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${peer.transport} • ${peer.nodeId ?? peer.id}'
                          '${peer.ipAddress != null ? '\nIP: ${peer.ipAddress}' : ''}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              peer.connected
                                  ? Icons.link_rounded
                                  : Icons.link_off_rounded,
                              size: 16,
                              color: peer.connected
                                  ? AppColors.meshConnected
                                  : Colors.white54,
                            ),
                            const SizedBox(width: 6),
                            if (peer.signal != 0)
                              Text(
                                '${peer.signal}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white60,
                                ),
                              ),
                            IconButton(
                              tooltip: 'Audio call',
                              icon: const Icon(Icons.call_rounded, size: 19),
                              onPressed: () =>
                                  context.read<CallProvider>().startCall(
                                    recipientId: peer.id,
                                    recipientName: peer.name,
                                    type: CallType.audio,
                                  ),
                            ),
                            IconButton(
                              tooltip: 'Video call',
                              icon: const Icon(
                                Icons.videocam_rounded,
                                size: 19,
                              ),
                              onPressed: () =>
                                  context.read<CallProvider>().startCall(
                                    recipientId: peer.id,
                                    recipientName: peer.name,
                                    type: CallType.video,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required String badgeText,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withOpacity(0.15),
          child: Icon(icon, color: AppColors.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: Colors.white70),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.secondary.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            badgeText,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.secondary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
