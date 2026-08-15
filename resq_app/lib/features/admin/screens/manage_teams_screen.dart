import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class ManageTeamsScreen extends StatefulWidget {
  const ManageTeamsScreen({Key? key}) : super(key: key);

  @override
  State<ManageTeamsScreen> createState() => _ManageTeamsScreenState();
}

class _ManageTeamsScreenState extends State<ManageTeamsScreen> {
  final List<Map<String, dynamic>> _teams = [
    {'id': 'RT-ALPHA', 'name': 'Alpha Squad (Medical)', 'leader': 'Alex Rescuer', 'members': 5, 'status': 'On Duty', 'activeIncidents': 2},
    {'id': 'RT-BRAVO', 'name': 'Bravo Squad (Flood Rescue)', 'leader': 'Maria Garcia', 'members': 8, 'status': 'On Duty', 'activeIncidents': 4},
    {'id': 'RT-CHARLIE', 'name': 'Charlie Squad (Evac)', 'leader': 'David Miller', 'members': 4, 'status': 'Standby', 'activeIncidents': 0},
  ];

  void _showAddTeamDialog() {
    final nameCtrl = TextEditingController();
    final leaderCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deploy New Rescue Team'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Team Name (e.g. Delta Squad)')),
            const SizedBox(height: 10),
            TextField(controller: leaderCtrl, decoration: const InputDecoration(labelText: 'Team Leader Name')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty) {
                setState(() {
                  _teams.add({
                    'id': 'RT-${_teams.length + 1}',
                    'name': nameCtrl.text,
                    'leader': leaderCtrl.text.isEmpty ? 'Unassigned' : leaderCtrl.text,
                    'members': 3,
                    'status': 'On Duty',
                    'activeIncidents': 0,
                  });
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('Deploy Team'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Rescue Teams'),
        backgroundColor: AppColors.headerBlue,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.headerBlue,
        onPressed: _showAddTeamDialog,
        icon: const Icon(Icons.add),
        label: const Text('New Team'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _teams.length,
        itemBuilder: (ctx, idx) {
          final t = _teams[idx];
          return Card(
            margin: const EdgeInsets.only(bottom: 14),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(t['name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: t['status'] == 'On Duty' ? AppColors.success.withOpacity(0.15) : Colors.grey.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          t['status'],
                          style: TextStyle(
                            color: t['status'] == 'On Duty' ? AppColors.success : Colors.grey.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Team ID: ${t['id']} • Leader: ${t['leader']}'),
                  const SizedBox(height: 4),
                  Text('Roster: ${t['members']} Responders • Active Incidents: ${t['activeIncidents']}'),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
