import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/providers/auth_provider.dart';
import '../../auth/models/user_model.dart';
import 'medical_info_screen.dart';
import 'emergency_contacts_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../../scoreboard/screens/scoreboard_screen.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/preference_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _emergencyContactCount = 0;

  @override
  void initState() {
    super.initState();
    _loadEmergencyContactCount();
  }

  Future<void> _loadEmergencyContactCount() async {
    final userData = await PreferenceService.getUserData();
    if (!mounted || userData == null) return;

    final user = UserModel.fromJson(userData);
    setState(() {
      _emergencyContactCount = user.emergencyContacts.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    return Scaffold(
      appBar: AppBar(title: const Text('User Profile & Medical ID')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: AppColors.primary.withOpacity(0.2),
                    child: Text(
                      user?.name.isNotEmpty == true
                          ? user!.name[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user?.name ?? 'ResQ User',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Mesh Node ID: ${user?.meshId ?? "RESQ-001"} • Role: ${user?.role.toUpperCase()}',
                    style: const TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            _buildOptionCard(
              context,
              title: 'Emergency Medical Info',
              subtitle:
                  'Blood Group: ${user?.medicalInfo.bloodGroup ?? "Unknown"} • Allergies & Conditions',
              icon: Icons.medical_services_outlined,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MedicalInfoScreen()),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildOptionCard(
              context,
              title: 'Emergency Contacts',
              subtitle: '$_emergencyContactCount Contacts Configured',
              icon: Icons.contact_phone_outlined,
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const EmergencyContactsScreen(),
                  ),
                );
                _loadEmergencyContactCount();
              },
            ),
            const SizedBox(height: 12),
            _buildOptionCard(
              context,
              title: 'Help Scoreboard',
              subtitle: 'View your help points and rescue leaderboard',
              icon: Icons.leaderboard_outlined,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ScoreboardScreen()),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildOptionCard(
              context,
              title: 'Settings & Diagnostics',
              subtitle: 'Dark Mode, Mesh Nodes & Storage Controls',
              icon: Icons.settings_outlined,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.withOpacity(0.15),
                foregroundColor: Colors.redAccent,
                minimumSize: const Size(double.infinity, 50),
              ),
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out'),
              onPressed: () => authProvider.logout(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary, size: 28),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: Colors.white70),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
        onTap: onTap,
      ),
    );
  }
}
