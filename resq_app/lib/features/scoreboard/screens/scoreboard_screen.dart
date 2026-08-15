import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../widgets/error_view.dart';
import '../../../widgets/loading_indicator.dart';
import '../providers/scoreboard_provider.dart';

class ScoreboardScreen extends StatefulWidget {
  const ScoreboardScreen({Key? key}) : super(key: key);

  @override
  State<ScoreboardScreen> createState() => _ScoreboardScreenState();
}

class _ScoreboardScreenState extends State<ScoreboardScreen> with WidgetsBindingObserver {
  late final ScoreboardProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = ScoreboardProvider();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _provider.loadScoreboard();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _provider.loadScoreboard();
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
    return ChangeNotifierProvider<ScoreboardProvider>.value(
      value: _provider,
      child: Consumer<ScoreboardProvider>(
        builder: (context, provider, _) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Help Scoreboard'),
              actions: [
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: provider.isLoading ? null : provider.loadScoreboard,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            body: provider.isLoading && provider.leaderboard.isEmpty
                ? const LoadingIndicator(message: 'Loading scoreboard...')
                : provider.errorMessage != null && provider.leaderboard.isEmpty
                    ? ErrorView(
                        errorMessage: provider.errorMessage!,
                        onRetry: provider.loadScoreboard,
                      )
                    : RefreshIndicator(
                        onRefresh: provider.loadScoreboard,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(20),
                          children: [
                            _buildScoreSummary(provider),
                            const SizedBox(height: 24),
                            const Text(
                              'Leaderboard',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            if (provider.leaderboard.isEmpty)
                              const Card(
                                child: Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Center(child: Text('No leaderboard data available yet.')),
                                ),
                              )
                            else
                              ...provider.leaderboard.map(_buildLeaderboardTile),
                            if (provider.errorMessage != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                provider.errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: AppColors.accentAlert),
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

  Widget _buildScoreSummary(ScoreboardProvider provider) {
    return Row(
      children: [
        Expanded(
          child: _buildScoreCard(
            icon: Icons.stars_rounded,
            label: 'Help Points',
            value: provider.helpPoints.toString(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildScoreCard(
            icon: Icons.volunteer_activism_outlined,
            label: 'Rescues Completed',
            value: provider.rescuesCompleted.toString(),
          ),
        ),
      ],
    );
  }

  Widget _buildScoreCard({required IconData icon, required String label, required String value}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 30),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderboardTile(LeaderboardEntry entry) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: entry.rank <= 3 ? AppColors.primary.withOpacity(0.15) : AppColors.secondary.withOpacity(0.12),
          child: Text(
            '${entry.rank}',
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
        ),
        title: Text(entry.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${entry.rescuesCompleted} rescues completed'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${entry.helpPoints}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const Text('points', style: TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}
