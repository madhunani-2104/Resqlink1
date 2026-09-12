import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../sos/providers/sos_provider.dart';
import '../../../core/constants/app_colors.dart';

class VictimListScreen extends StatefulWidget {
  const VictimListScreen({Key? key}) : super(key: key);

  @override
  State<VictimListScreen> createState() => _VictimListScreenState();
}

class _VictimListScreenState extends State<VictimListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<SosProvider>();
      provider.fetchDispatchQueue();
      provider.fetchResponders();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SosProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Dispatch Queue')),
      body: RefreshIndicator(
        onRefresh: () async {
          await provider.fetchDispatchQueue();
          await provider.fetchResponders();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildResponderRoster(provider),
            const SizedBox(height: 20),
            const Text(
              'Active SOS Queue',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (provider.activeSosList.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'No active victim distress alerts at this time.',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              )
            else
              ...provider.activeSosList.map(
                (alert) => _buildAlertCard(provider, alert),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponderRoster(SosProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Responder Availability',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (provider.responders.isEmpty)
          const Text(
            'No responder roster available.',
            style: TextStyle(color: Colors.white70),
          )
        else
          ...provider.responders.map(
            (responder) => ListTile(
              dense: true,
              leading: Icon(
                Icons.shield_outlined,
                color: responder['availabilityStatus'] == 'AVAILABLE'
                    ? Colors.green
                    : Colors.orange,
              ),
              title: Text(responder['name']?.toString() ?? 'Responder'),
              subtitle: Text(
                '${responder['availabilityStatus'] ?? 'OFFLINE'}'
                '${responder['isOnline'] == true ? ' • online' : ''}',
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAlertCard(SosProvider provider, dynamic alert) {
    final available = provider.responders
        .where((responder) => responder['availabilityStatus'] == 'AVAILABLE')
        .toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    alert.userName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  alert.severity,
                  style: const TextStyle(
                    color: AppColors.primaryLight,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('Phone: ${alert.userPhone}'),
            const SizedBox(height: 4),
            Text(
              'Location: (${alert.latitude.toStringAsFixed(5)}, '
              '${alert.longitude.toStringAsFixed(5)})',
              style: const TextStyle(color: AppColors.bleActive),
            ),
            const SizedBox(height: 4),
            Text('Status: ${alert.status}'),
            if (alert.assignedResponderName != null)
              Text('Responder: ${alert.assignedResponderName}'),
            _buildTrackingSummary(alert),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (alert.assignedResponderId == null && available.isNotEmpty)
                  DropdownButton<String>(
                    hint: const Text('Assign responder'),
                    dropdownColor: AppColors.darkCard,
                    items: available.map((responder) {
                      final id = responder['_id']?.toString() ?? '';
                      return DropdownMenuItem(
                        value: id,
                        child: Text(
                          responder['name']?.toString() ?? 'Responder',
                        ),
                      );
                    }).toList(),
                    onChanged: (responderId) {
                      if (responderId != null) {
                        provider.assignResponder(alert.sosId, responderId);
                      }
                    },
                  ),
                if (alert.status == 'ASSIGNED')
                  FilledButton.tonal(
                    onPressed: () => provider.updateDispatchStatus(
                      alert.sosId,
                      'ACKNOWLEDGED',
                    ),
                    child: const Text('Acknowledge'),
                  ),
                if (alert.status == 'ACKNOWLEDGED')
                  FilledButton.tonal(
                    onPressed: () =>
                        provider.updateDispatchStatus(alert.sosId, 'RESOLVED'),
                    child: const Text('Resolve'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackingSummary(dynamic alert) {
    final details = <String>[
      'Status: ${alert.status}',
      'Victim: (${alert.latitude.toStringAsFixed(5)}, '
          '${alert.longitude.toStringAsFixed(5)})',
      'Created: ${_formatTrackingTime(alert.createdAt)}',
    ];

    if (alert.assignedResponderName?.toString().trim().isNotEmpty == true) {
      details.add('Responder: ${alert.assignedResponderName}');
    }
    if (alert.accuracy > 0) {
      details.add('Accuracy: ${alert.accuracy.toStringAsFixed(1)} m');
    }
    if (alert.assignedAt != null) {
      details.add('Assigned: ${_formatTrackingTime(alert.assignedAt)}');
    }
    if (alert.batteryLevel >= 0) {
      details.add('Battery: ${alert.batteryLevel}%');
    } else if (alert.riskLevel?.toString().trim().isNotEmpty == true) {
      details.add('Risk: ${alert.riskLevel}');
    }

    return Text(
      details.join(' • '),
      style: const TextStyle(color: AppColors.bleActive, fontSize: 12),
    );
  }

  String _formatTrackingTime(DateTime time) {
    final local = time.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$month-$day $hour:$minute';
  }
}
