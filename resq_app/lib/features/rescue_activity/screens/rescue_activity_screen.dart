import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../widgets/error_view.dart';
import '../../../widgets/loading_indicator.dart';
import '../models/rescue_activity_model.dart';
import '../providers/rescue_activity_provider.dart';

class RescueActivityScreen extends StatefulWidget {
  const RescueActivityScreen({Key? key}) : super(key: key);

  @override
  State<RescueActivityScreen> createState() => _RescueActivityScreenState();
}

class _RescueActivityScreenState extends State<RescueActivityScreen>
    with WidgetsBindingObserver {
  late final RescueActivityProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = RescueActivityProvider();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _provider.loadActivities();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _provider.loadActivities();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<RescueActivityProvider>.value(
      value: _provider,
      child: Consumer<RescueActivityProvider>(
        builder: (context, provider, _) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Rescue Activity'),
              actions: [
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: provider.isLoading
                      ? null
                      : provider.loadActivities,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            body: provider.isLoading && provider.activities.isEmpty
                ? const LoadingIndicator(message: 'Loading activity records...')
                : provider.errorMessage != null && provider.activities.isEmpty
                ? ErrorView(
                    errorMessage: provider.errorMessage!,
                    onRetry: provider.loadActivities,
                  )
                : RefreshIndicator(
                    onRefresh: provider.loadActivities,
                    child: provider.activities.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: const [
                              SizedBox(height: 180),
                              Center(
                                child: Text(
                                  'No completed rescue activity yet.',
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            itemCount: provider.activities.length,
                            itemBuilder: (context, index) => _ActivityCard(
                              activity: provider.activities[index],
                            ),
                          ),
                  ),
          );
        },
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final RescueActivityModel activity;

  const _ActivityCard({required this.activity});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.volunteer_activism, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${activity.emergencyType} rescue',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '+${activity.points} pts',
                  style: const TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _ActivityField('Rescuer', activity.rescuerName),
            _ActivityField('Victim helped', activity.victimName),
            _ActivityField('Emergency identified', activity.identifiedBy),
            _ActivityField('Actions taken', activity.actionsTaken),
            _ActivityField('Outcome', activity.outcome),
            _ActivityField(
              'Location',
              '${activity.latitude}, ${activity.longitude}'
                  '${activity.address.isEmpty ? '' : '\n${activity.address}'}',
            ),
            _ActivityField(
              'Hazard / risk',
              '${activity.severity}'
                  '${activity.riskLevel == null ? '' : ' • ${activity.riskLevel}'}'
                  '${activity.riskScore == null ? '' : ' • score ${activity.riskScore}'}',
            ),
            _ActivityField('Completed', _formatDate(activity.completedAt)),
            _ActivityField(
              'Feedback / rating',
              activity.feedback ?? 'Not available',
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    if (date.millisecondsSinceEpoch == 0) return 'Not available';
    final local = date.toLocal();
    final twoDigit = (int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${twoDigit(local.month)}-${twoDigit(local.day)} '
        '${twoDigit(local.hour)}:${twoDigit(local.minute)}';
  }
}

class _ActivityField extends StatelessWidget {
  final String label;
  final String value;

  const _ActivityField(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: RichText(
        text: TextSpan(
          style: DefaultTextStyle.of(context).style,
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
