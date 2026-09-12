import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/file_access_service.dart';
import '../../sos/providers/sos_provider.dart';
import '../providers/admin_provider.dart';

class ReportsExportScreen extends StatelessWidget {
  const ReportsExportScreen({Key? key}) : super(key: key);

  Future<void> _exportFormat(BuildContext context, String format) async {
    final adminProvider = context.read<AdminProvider>();
    final sosProvider = context.read<SosProvider>();

    await Future.wait([
      adminProvider.fetchAdminStats(),
      sosProvider.fetchDispatchQueue(),
    ]);

    final stats = adminProvider.stats;
    final alerts = sosProvider.activeSosList;
    final reportData = {
      'generatedAt': DateTime.now().toIso8601String(),
      'summary': {
        'totalUsers': stats.totalUsers,
        'totalResponders': stats.totalResponders,
        'activeSosCount': stats.activeSosCount,
        'acknowledgedSosCount': stats.acknowledgedSosCount,
        'rescuedSosCount': stats.rescuedSosCount,
        'totalMeshPackets': stats.totalMeshPackets,
      },
      'activeSos': alerts.map((alert) => alert.toJson()).toList(),
    };

    final isJson = format == 'JSON';
    final content = isJson
        ? const JsonEncoder.withIndent('  ').convert(reportData)
        : _toCsv(reportData, alerts);
    final fileName = isJson
        ? 'resq_incident_report.json'
        : 'resq_incident_report.csv';
    final saved = await FileAccessService.saveTextFile(
      fileName: fileName,
      content: content,
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? 'Incident report saved successfully.'
              : 'Unable to save incident report.',
        ),
        backgroundColor: saved ? AppColors.success : Colors.red,
      ),
    );
  }

  String _toCsv(Map<String, dynamic> reportData, List<dynamic> alerts) {
    final summary = reportData['summary'] as Map<String, dynamic>;
    final rows = <String>[
      'Section,Metric,Value',
      ...summary.entries.map(
        (entry) => 'Summary,${entry.key},${_csvValue(entry.value)}',
      ),
      '',
      'SOS ID,Name,Phone,Status,Latitude,Longitude,Severity,Accuracy,Battery',
      ...alerts.map(
        (alert) => [
          alert.sosId,
          alert.userName,
          alert.userPhone,
          alert.status,
          alert.latitude,
          alert.longitude,
          alert.severity,
          alert.accuracy,
          alert.batteryLevel,
        ].map(_csvValue).join(','),
      ),
    ];
    return rows.join('\n');
  }

  String _csvValue(Object? value) {
    final text = value?.toString() ?? '';
    return '"${text.replaceAll('"', '""')}"';
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
                leading: const Icon(
                  Icons.picture_as_pdf,
                  color: AppColors.primary,
                  size: 32,
                ),
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
                leading: const Icon(
                  Icons.analytics_outlined,
                  color: AppColors.headerBlue,
                  size: 32,
                ),
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.headerBlue,
                    ),
                    onPressed: () => _exportFormat(context, 'CSV'),
                    icon: const Icon(Icons.table_chart_outlined),
                    label: const Text('Export CSV'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                    ),
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
