import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({Key? key}) : super(key: key);

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  final List<Map<String, dynamic>> _users = [
    {'name': 'Test User', 'email': 'user@resq.org', 'role': 'Victim', 'active': true, 'nodeId': 'DEV-USER-1'},
    {'name': 'Alex Rescuer', 'email': 'alex@resq.org', 'role': 'Rescue Team', 'active': true, 'nodeId': 'TEAM-NODE-04'},
    {'name': 'Commander Sarah', 'email': 'sarah@resq.org', 'role': 'Admin', 'active': true, 'nodeId': 'ADMIN-NODE-01'},
    {'name': 'John Doe', 'email': 'john@resq.org', 'role': 'Victim', 'active': false, 'nodeId': 'DEV-USER-8'},
    {'name': 'Maria Garcia', 'email': 'maria@resq.org', 'role': 'Rescue Team', 'active': true, 'nodeId': 'TEAM-NODE-02'},
  ];

  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final filteredUsers = _users.where((u) {
      final name = u['name'].toString().toLowerCase();
      final email = u['email'].toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase()) || email.contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Users'),
        backgroundColor: AppColors.headerBlue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search user by name or email...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: filteredUsers.length,
                itemBuilder: (ctx, idx) {
                  final u = filteredUsers[idx];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: u['role'] == 'Admin'
                            ? Colors.purple.shade100
                            : u['role'] == 'Rescue Team'
                                ? Colors.blue.shade100
                                : Colors.red.shade100,
                        child: Icon(
                          u['role'] == 'Admin'
                              ? Icons.admin_panel_settings
                              : u['role'] == 'Rescue Team'
                                  ? Icons.shield
                                  : Icons.person,
                          color: u['role'] == 'Admin'
                              ? Colors.purple
                              : u['role'] == 'Rescue Team'
                                  ? AppColors.headerBlue
                                  : AppColors.primary,
                        ),
                      ),
                      title: Text(u['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${u['email']} • Node: ${u['nodeId']}'),
                      trailing: PopupMenuButton<String>(
                        onSelected: (action) {
                          if (action == 'toggle') {
                            setState(() => u['active'] = !u['active']);
                          } else if (action == 'make_rescue') {
                            setState(() => u['role'] = 'Rescue Team');
                          } else if (action == 'make_admin') {
                            setState(() => u['role'] = 'Admin');
                          } else if (action == 'make_victim') {
                            setState(() => u['role'] = 'Victim');
                          }
                        },
                        itemBuilder: (ctx) => [
                          PopupMenuItem(
                            value: 'toggle',
                            child: Text(u['active'] ? 'Deactivate User' : 'Activate User'),
                          ),
                          const PopupMenuItem(value: 'make_victim', child: Text('Role: Victim')),
                          const PopupMenuItem(value: 'make_rescue', child: Text('Role: Rescue Team')),
                          const PopupMenuItem(value: 'make_admin', child: Text('Role: Admin')),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
