import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class ReportsExportScreen extends StatelessWidget {
  const ReportsExportScreen({Key? key}) : super(key: key);

  void _exportFormat(BuildContext context, String format) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Exported Incident Logs as $format file to Downloads.'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Export Data'),
        backgroundColor: AppColors.headerBlue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Automated Capstone & Incident Reports',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            Card(
              child: ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: AppColors.primary, size: 32),
                title: const Text('Daily Incident Summary PDF'),
                subtitle: const Text('Generated July 31, 2026 • 2.4 MB'),
                trailing: IconButton(
                  icon: const Icon(Icons.download),
                  onPressed: () => _exportFormat(context, 'PDF'),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: ListTile(
                leading: const Icon(Icons.analytics_outlined, color: AppColors.headerBlue, size: 32),
                title: const Text('Mesh Network Packet Audit Log'),
                subtitle: const Text('Comprehensive P2P relay hop analytics'),
                trailing: IconButton(
                  icon: const Icon(Icons.download),
                  onPressed: () => _exportFormat(context, 'CSV'),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Export Raw System Data',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.headerBlue),
                    onPressed: () => _exportFormat(context, 'CSV'),
                    icon: const Icon(Icons.table_chart_outlined),
                    label: const Text('Export CSV'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                    onPressed: () => _exportFormat(context, 'JSON'),
                    icon: const Icon(Icons.code_rounded),
                    label: const Text('Export JSON'),
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
