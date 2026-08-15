import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/voice_recording_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../mesh_chat/providers/mesh_chat_provider.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback? onNavigateToSos;
  final VoidCallback? onNavigateToChat;
  final VoidCallback? onNavigateToMap;
  final VoidCallback? onNavigateToAdmin;
  final VoidCallback? onNavigateToRescueTeam;

  const HomeScreen({
    Key? key,
    this.onNavigateToSos,
    this.onNavigateToChat,
    this.onNavigateToMap,
    this.onNavigateToAdmin,
    this.onNavigateToRescueTeam,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final meshProvider = Provider.of<MeshChatProvider>(context);
    final userName = authProvider.user?.name ?? 'Test';
    final nodeId = authProvider.user?.id.substring(0, 10).toUpperCase() ?? 'DEV-USER-1';
    final role = authProvider.user?.role ?? 'user';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final menuItems = <PopupMenuEntry<String>>[
      if (role == 'admin')
        const PopupMenuItem(
          value: 'admin',
          child: Row(
            children: [
              Icon(Icons.admin_panel_settings_outlined, color: AppColors.headerBlue),
              SizedBox(width: 10),
              Text('Admin Console'),
            ],
          ),
        ),
      if (role == 'rescue_team')
        const PopupMenuItem(
          value: 'rescue',
          child: Row(
            children: [
              Icon(Icons.shield_outlined, color: AppColors.primary),
              SizedBox(width: 10),
              Text('Rescue Team Portal'),
            ],
          ),
        ),
    ];

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: AppColors.headerBlue,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Home',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: menuItems.isEmpty
            ? null
            : [
                PopupMenuButton<String>(
                  icon: const Icon(Icons.settings_outlined, color: Colors.white),
                  onSelected: (value) {
                    if (value == 'admin' && onNavigateToAdmin != null) {
                      onNavigateToAdmin!();
                    } else if (value == 'rescue' && onNavigateToRescueTeam != null) {
                      onNavigateToRescueTeam!();
                    }
                  },
                  itemBuilder: (context) => menuItems,
                ),
              ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Greeting & Mesh Network Card Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Good day,',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              userName,
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text('👋', style: TextStyle(fontSize: 24)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Stay alert, stay safe.',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),

                // Mesh Network Status Card
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.meshConnected.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.sensors,
                          color: AppColors.meshConnected,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mesh Network',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                          Text(
                            meshProvider.isMeshActive ? 'Online' : 'Searching',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: meshProvider.isMeshActive
                                  ? AppColors.meshConnected
                                  : AppColors.meshSearching,
                            ),
                          ),
                          Text(
                            '${meshProvider.activePeersCount} Devices Nearby',
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Emergency SOS Banner Card
            GestureDetector(
              onTap: onNavigateToSos,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Emergency SOS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Tap to send alert to all devices',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: Colors.white,
                      size: 28,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Grid of 2 Status Cards (Nearby Devices & Node Status)
            Row(
              children: [
                // Nearby Devices Card
                Expanded(
                  child: _buildInfoCard(
                    context: context,
                    icon: Icons.devices_other,
                    iconColor: AppColors.headerBlue,
                    title: 'Nearby Devices',
                    value: '${meshProvider.activePeersCount}',
                    subtitle: 'devices in range',
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 14),
                // Node Status Card
                Expanded(
                  child: _buildInfoCard(
                    context: context,
                    icon: Icons.info_outline_rounded,
                    iconColor: AppColors.headerBlue,
                    title: 'Node Status',
                    value: nodeId,
                    subtitle: 'Node ID',
                    isDark: isDark,
                    valueFontSize: 16,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            _buildLocationCard(isDark),

            const SizedBox(height: 22),

            // Quick Actions Header
            Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 14),

            // Quick Actions Row 1 (2 primary cards)
            Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    context: context,
                    icon: Icons.chat_bubble_outline_rounded,
                    iconColor: Colors.purple,
                    title: 'Offline Chat',
                    onTap: onNavigateToChat,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildActionCard(
                    context: context,
                    icon: Icons.map_outlined,
                    iconColor: Colors.teal,
                    title: 'Map',
                    onTap: onNavigateToMap,
                    isDark: isDark,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Quick Actions Row 2 (3 secondary cards)
            Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    context: context,
                    icon: Icons.folder_shared_outlined,
                    iconColor: Colors.amber.shade800,
                    title: 'File Sharing',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('BLE/Wi-Fi Direct File Transfer Ready')),
                      );
                    },
                    isDark: isDark,
                    compact: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildActionCard(
                    context: context,
                    icon: Icons.mic_none_rounded,
                    iconColor: Colors.pink.shade600,
                    title: 'Voice Msg',
                    onTap: () {
                      _showVoiceModal(context);
                    },
                    isDark: isDark,
                    compact: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildActionCard(
                    context: context,
                    icon: Icons.campaign_outlined,
                    iconColor: Colors.deepOrange,
                    title: 'Broadcast',
                    onTap: () {
                      _showBroadcastModal(context);
                    },
                    isDark: isDark,
                    compact: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard(bool isDark) {
    return FutureBuilder<Position?>(
      future: LocationService.getCurrentPosition(),
      builder: (context, snapshot) {
        final position = snapshot.data;
        final text = position == null
            ? 'Locating...'
            : '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.headerBlue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.my_location_rounded,
                  color: AppColors.headerBlue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Location',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      text,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              if (isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.headerBlue),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String subtitle,
    required bool isDark,
    double valueFontSize = 24,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: valueFontSize,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required VoidCallback? onTap,
    required bool isDark,
    bool compact = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: compact ? 16 : 20,
          horizontal: compact ? 8 : 14,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: compact ? 26 : 30),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: compact ? 12 : 14,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showVoiceModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Voice Message Relay',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Icon(Icons.mic_rounded, size: 60, color: Colors.pink),
            const SizedBox(height: 12),
            const Text('Record an emergency voice note and broadcast its local file reference across mesh.'),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () async {
                final auth = context.read<AuthProvider>();
                final mesh = context.read<MeshChatProvider>();
                final user = auth.user;
                final recordingPath = await VoiceRecordingService.startRecording();
                await Future.delayed(const Duration(seconds: 5));
                final savedPath = await VoiceRecordingService.stopRecording() ?? recordingPath;
                Navigator.pop(ctx);
                final voicePayload = savedPath == null
                    ? null
                    : await VoiceRecordingService.readRecordingBase64(savedPath);
                if (user != null && voicePayload != null) {
                  await mesh.sendMessage(
                    senderId: user.id,
                    senderName: user.name,
                    receiverId: 'BROADCAST',
                    text: 'VOICE_MESSAGE_BASE64:$voicePayload',
                  );
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(voicePayload == null
                        ? 'Microphone permission needed for voice recording.'
                        : 'Voice message broadcast across Mesh.'),
                  ),
                );
              },
              icon: const Icon(Icons.send_rounded),
              label: const Text('Record & Broadcast'),
            ),
          ],
        ),
      ),
    );
  }

  void _showBroadcastModal(BuildContext context) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Emergency Broadcast Alert',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Sends an emergency push alert across all nearby BLE/Wi-Fi Direct mesh nodes.'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Enter emergency broadcast message...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: () async {
                  final text = controller.text.trim();
                  if (text.isEmpty) return;
                  final auth = context.read<AuthProvider>();
                  final mesh = context.read<MeshChatProvider>();
                  final user = auth.user;
                  Navigator.pop(ctx);
                  if (user != null) {
                    await mesh.sendMessage(
                      senderId: user.id,
                      senderName: user.name,
                      receiverId: 'BROADCAST',
                      text: 'EMERGENCY_BROADCAST:$text',
                    );
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Emergency Broadcast sent across Mesh Network!'),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                },
                icon: const Icon(Icons.campaign_rounded),
                label: const Text('Send Broadcast Alert'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
