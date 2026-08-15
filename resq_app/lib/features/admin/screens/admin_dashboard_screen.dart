import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/admin_provider.dart';
import 'victim_list_screen.dart';
import 'manage_users_screen.dart';
import 'manage_teams_screen.dart';
import 'analytics_screen.dart';
import 'heat_maps_screen.dart';
import 'reports_export_screen.dart';
import '../../../core/constants/app_colors.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AdminProvider>(context, listen: false).fetchAdminStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    final adminProvider = Provider.of<AdminProvider>(context);
    final stats = adminProvider.stats;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Console'),
        backgroundColor: AppColors.headerBlue,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => adminProvider.fetchAdminStats(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Incident Command Metrics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStatCard(
                  title: 'Active SOS Alerts',
                  count: '${stats.activeSosCount}',
                  color: AppColors.primary,
                  icon: Icons.warning_amber_rounded,
                ),
                _buildStatCard(
                  title: 'Rescued Victims',
                  count: '${stats.rescuedSosCount}',
                  color: AppColors.success,
                  icon: Icons.check_circle_outline,
                ),
                _buildStatCard(
                  title: 'Field Responders',
                  count: '${stats.totalResponders}',
                  color: AppColors.headerBlue,
                  icon: Icons.shield_outlined,
                ),
                _buildStatCard(
                  title: 'Mesh Relays Sent',
                  count: '${stats.totalMeshPackets}',
                  color: AppColors.bleActive,
                  icon: Icons.cell_tower,
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Admin Management & Tools',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),

            // Quick Access List Cards for Admin Tasks
            _buildAdminMenuTile(
              context: context,
              icon: Icons.people_alt_outlined,
              color: Colors.blue.shade700,
              title: 'Manage Users',
              subtitle: 'User directory, roles & account activations',
              screen: const ManageUsersScreen(),
            ),
            const SizedBox(height: 10),
            _buildAdminMenuTile(
              context: context,
              icon: Icons.shield_outlined,
              color: Colors.indigo,
              title: 'Manage Rescue Teams',
              subtitle: 'Deploy squads, assign team leads & field roster',
              screen: const ManageTeamsScreen(),
            ),
            const SizedBox(height: 10),
            _buildAdminMenuTile(
              context: context,
              icon: Icons.analytics_outlined,
              color: Colors.teal,
              title: 'Analytics',
              subtitle: 'Response times, hop metrics & severity breakdown',
              screen: const AnalyticsScreen(),
            ),
            const SizedBox(height: 10),
            _buildAdminMenuTile(
              context: context,
              icon: Icons.map_outlined,
              color: Colors.deepOrange,
              title: 'Heat Maps',
              subtitle: 'GIS hazard overlays & victim density mapping',
              screen: const HeatMapsScreen(),
            ),
            const SizedBox(height: 10),
            _buildAdminMenuTile(
              context: context,
              icon: Icons.picture_as_pdf_outlined,
              color: Colors.purple,
              title: 'Reports & Export Data',
              subtitle: 'Generate summary PDFs, export raw CSV/JSON logs',
              screen: const ReportsExportScreen(),
            ),
            const SizedBox(height: 10),
            _buildAdminMenuTile(
              context: context,
              icon: Icons.list_alt_rounded,
              color: AppColors.primary,
              title: 'Victim Incident Dispatch Queue',
              subtitle: 'Real-time coordinates, medical profile & dispatch',
              screen: const VictimListScreen(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String count,
    required Color color,
    required IconData icon,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const Spacer(),
                Text(
                  count,
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminMenuTile({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required Widget screen,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.12),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => screen),
          );
        },
      ),
    );
  }
}
