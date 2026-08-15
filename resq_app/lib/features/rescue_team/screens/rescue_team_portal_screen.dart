import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../map/screens/live_map_screen.dart';
import '../../mesh_chat/screens/mesh_chat_screen.dart';
import '../../sos/models/sos_model.dart';
import '../../sos/providers/sos_provider.dart';
import 'live_tracking_screen.dart';

class RescueTeamPortalScreen extends StatefulWidget {
  const RescueTeamPortalScreen({Key? key}) : super(key: key);

  @override
  State<RescueTeamPortalScreen> createState() => _RescueTeamPortalScreenState();
}

class _RescueTeamPortalScreenState extends State<RescueTeamPortalScreen> {
  String _activeFilter = 'All';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      final sosProvider = context.read<SosProvider>();
      sosProvider.connectRescueAlertStream(role: auth.user?.role ?? 'user');
      sosProvider.fetchActiveSosAlerts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final sosProvider = Provider.of<SosProvider>(context);
    final alerts = sosProvider.activeSosList.where((alert) {
      if (_activeFilter == 'All') return true;
      return alert.severity == _activeFilter || alert.status == _activeFilter;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rescue Team Field Command'),
        backgroundColor: AppColors.primary,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                context.read<AuthProvider>().logout();
              } else {
                setState(() => _activeFilter = value);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'All', child: Text('All Alerts')),
              PopupMenuItem(value: 'CRITICAL', child: Text('Critical')),
              PopupMenuItem(value: 'HIGH', child: Text('High')),
              PopupMenuItem(value: 'ACKNOWLEDGED', child: Text('Responding')),
              PopupMenuDivider(),
              PopupMenuItem(value: 'logout', child: Text('Sign Out')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: sosProvider.fetchActiveSosAlerts,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.headerBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.headerBlue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_rounded, color: AppColors.headerBlue, size: 36),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${auth.user?.name ?? 'Rescue Team'} On Duty',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Live SOS alerts, GPS tracking, and mesh relay active',
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.headerBlue),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LiveMapScreen()),
                    ),
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Live Map'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MeshChatScreen()),
                    ),
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Team Chat'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Incoming SOS (${alerts.length})',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  _activeFilter,
                  style: const TextStyle(color: AppColors.headerBlue, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (sosProvider.isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
            else if (alerts.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: Text('No active SOS alerts right now.')),
              )
            else
              ...alerts.map((alert) => _AlertCard(alert: alert)).toList(),
          ],
        ),
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final SosModel alert;

  const _AlertCard({required this.alert});

  @override
  Widget build(BuildContext context) {
    final isCritical = alert.severity == 'CRITICAL';
    final isHigh = alert.severity == 'HIGH';
    final severityColor = isCritical
        ? AppColors.severityCritical
        : (isHigh ? AppColors.severityHigh : AppColors.severityMedium);
    final locationText = '${alert.latitude.toStringAsFixed(5)}, ${alert.longitude.toStringAsFixed(5)}';
    final backendId = alert.id.isNotEmpty ? alert.id : alert.sosId;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: severityColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${alert.severity} SOS',
                    style: TextStyle(color: severityColor, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
                const Spacer(),
                Text(alert.status, style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 10),
            Text(alert.userName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Phone: ${alert.userPhone}'),
            Text('Location: $locationText'),
            if (alert.riskLevel != null)
              Text('Priority: ${alert.riskLevel} (${alert.riskScore?.toStringAsFixed(0) ?? '—'}/100)'),
            if (alert.notes.isNotEmpty) Text('Notes: ${alert.notes}'),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LiveTrackingScreen(
                          victimName: alert.userName,
                          coordinates: locationText,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.navigation_outlined, size: 18),
                    label: const Text('Track'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.headerBlue),
                    onPressed: alert.status == 'ACTIVE'
                        ? () => context.read<SosProvider>().markResponding(backendId)
                        : null,
                    child: const Text('Responding'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                    onPressed: alert.status != 'RESCUED'
                        ? () => context.read<SosProvider>().markResolved(backendId)
                        : null,
                    child: const Text('Resolved'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}