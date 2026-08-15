import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../../../core/database/db_helper.dart';
import '../../../core/constants/app_colors.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings & Diagnostics')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text('Appearance', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryLight)),
          SwitchListTile(
            title: const Text('Dark Theme'),
            subtitle: const Text('High contrast OLED emergency palette'),
            value: settings.isDarkMode,
            onChanged: settings.toggleDarkMode,
          ),
          const Divider(),
          const Text('Mesh Networking', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryLight)),
          SwitchListTile(
            title: const Text('BLE & Wi-Fi Direct Mesh Service'),
            subtitle: const Text('Allow peer packet relay & store-and-forward'),
            value: settings.meshEnabled,
            onChanged: settings.toggleMeshEnabled,
          ),
          const Divider(),
          const Text('Offline Storage Diagnostics', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryLight)),
          ListTile(
            title: const Text('Purge SQLite Offline Cache'),
            subtitle: const Text('Deletes locally cached packets and sync queue'),
            trailing: const Icon(Icons.delete_forever, color: Colors.redAccent),
            onTap: () async {
              await DBHelper.instance.clearAllData();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Offline SQLite Database Purged Clean.')),
              );
            },
          ),
        ],
      ),
    );
  }
}
