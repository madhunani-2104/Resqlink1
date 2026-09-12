import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/file_access_service.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Disaster Response Analytics'),
        backgroundColor: AppColors.headerBlue,
        actions: [
          IconButton(
            tooltip: 'Download analytics report',
            icon: const Icon(Icons.download),
            onPressed: () => _downloadReport(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Incident Metrics & System Health',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    label: 'Avg Response Time',
                    value: '4.2 min',
                    color: AppColors.headerBlue,
                    icon: Icons.timer_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricTile(
                    label: 'Mesh Delivery Rate',
                    value: '99.4%',
                    color: AppColors.success,
                    icon: Icons.cell_tower,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    label: 'Total SOS Relays',
                    value: '1,420',
                    color: AppColors.primary,
                    icon: Icons.warning_amber_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricTile(
                    label: 'Active Hop Nodes',
                    value: '48',
                    color: AppColors.accentAlert,
                    icon: Icons.hub_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'SOS Severity Distribution',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildProgressBar(
                      'Critical Severity',
                      0.15,
                      AppColors.severityCritical,
                    ),
                    const SizedBox(height: 12),
                    _buildProgressBar(
                      'High Severity',
                      0.35,
                      AppColors.severityHigh,
                    ),
                    const SizedBox(height: 12),
                    _buildProgressBar(
                      'Medium Severity',
                      0.30,
                      AppColors.severityMedium,
                    ),
                    const SizedBox(height: 12),
                    _buildProgressBar(
                      'Low Severity',
                      0.20,
                      AppColors.severityLow,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadReport(BuildContext context) async {
    const report = '''Metric,Value
Average Response Time,4.2 min
Mesh Delivery Rate,99.4%
Total SOS Relays,"1,420"
Active Hop Nodes,48
Critical Severity,15%
High Severity,35%
Medium Severity,30%
Low Severity,20%
''';

    final saved = await FileAccessService.saveTextFile(
      fileName: 'resq_analytics_report.csv',
      content: report,
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? 'Analytics report saved successfully.'
              : 'Unable to save analytics report.',
        ),
        backgroundColor: saved ? AppColors.success : Colors.red,
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(String label, double ratio, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('${(ratio * 100).toInt()}%'),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: ratio,
          color: color,
          backgroundColor: color.withOpacity(0.15),
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }
}
