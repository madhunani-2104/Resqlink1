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
      Provider.of<SosProvider>(context, listen: false).fetchActiveSosAlerts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final sosProvider = Provider.of<SosProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Victim Distress Dispatch')),
      body: sosProvider.activeSosList.isEmpty
          ? const Center(
              child: Text('No active victim distress alerts at this time.', style: TextStyle(color: Colors.white70)),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: sosProvider.activeSosList.length,
              itemBuilder: (context, index) {
                final victim = sosProvider.activeSosList[index];

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              victim.userName,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                victim.severity,
                                style: const TextStyle(color: AppColors.primaryLight, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Phone: ${victim.userPhone}',
                          style: const TextStyle(fontSize: 13, color: Colors.white70),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Location: (${victim.latitude.toStringAsFixed(5)}, ${victim.longitude.toStringAsFixed(5)})',
                          style: const TextStyle(fontSize: 13, color: AppColors.bleActive),
                        ),
                        if (victim.notes.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Notes: ${victim.notes}',
                            style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
