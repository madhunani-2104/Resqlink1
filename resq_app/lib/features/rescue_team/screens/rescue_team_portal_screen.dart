import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../map/screens/live_map_screen.dart';
import '../../mesh_chat/screens/mesh_chat_screen.dart';
import '../../sos/models/sos_model.dart';
import '../../sos/providers/sos_provider.dart';
import 'live_tracking_screen.dart';

class RescueTeamPortalScreen extends StatefulWidget {
  const RescueTeamPortalScreen({Key? key}) : super(key: key);

  @override
  State<RescueTeamPortalScreen> createState() => _RescueTeamPortalScreenState();
}

class _RescueTeamPortalScreenState extends State<RescueTeamPortalScreen> {
  String _activeFilter = 'All';

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final auth = context.read<AuthProvider>();
      final sosProvider = context.read<SosProvider>();

      final role = auth.user?.role ?? 'user';

      if (role == 'rescue_team' || role == 'admin') {
        sosProvider.connectRescueAlertStream(role: role);
      }

      sosProvider.fetchActiveSosAlerts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final sosProvider = Provider.of<SosProvider>(context);

    final alerts = sosProvider.activeSosList.where((alert) {
      if (_activeFilter == 'All') {
        return true;
      }

      return alert.severity == _activeFilter || alert.status == _activeFilter;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Rescue Team Field Command',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                context.read<AuthProvider>().logout();
                return;
              }

              setState(() {
                _activeFilter = value;
              });
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'All', child: Text('All Alerts')),
              PopupMenuItem(value: 'CRITICAL', child: Text('Critical')),
              PopupMenuItem(value: 'HIGH', child: Text('High')),
              PopupMenuItem(value: 'MEDIUM', child: Text('Medium')),
              PopupMenuItem(value: 'LOW', child: Text('Low')),
              PopupMenuItem(value: 'ACKNOWLEDGED', child: Text('Responding')),
              PopupMenuDivider(),
              PopupMenuItem(value: 'logout', child: Text('Sign Out')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: sosProvider.fetchActiveSosAlerts,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _buildDutyHeader(auth),
            const SizedBox(height: 18),
            _buildQuickActions(context),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Incoming SOS (${alerts.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _activeFilter,
                  style: const TextStyle(
                    color: AppColors.headerBlue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (sosProvider.isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (alerts.isEmpty)
              _buildEmptyState()
            else
              ...alerts.map((alert) => _AlertCard(alert: alert)),
          ],
        ),
      ),
    );
  }

  Widget _buildDutyHeader(AuthProvider auth) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.headerBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.headerBlue.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.shield_rounded,
            color: AppColors.headerBlue,
            size: 36,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${auth.user?.name ?? 'Rescue Team'} On Duty',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Live SOS alerts, GPS tracking, and mesh relay active',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          const Icon(Icons.circle, color: Colors.green, size: 12),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.headerBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LiveMapScreen()),
              );
            },
            icon: const Icon(Icons.map_outlined),
            label: const Text('Live Map'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MeshChatScreen()),
              );
            },
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('Team Chat'),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Column(
        children: const [
          Icon(Icons.notifications_none_rounded, size: 70, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No active SOS alerts right now.',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          SizedBox(height: 8),
          Text(
            'New emergency alerts will appear here automatically.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ALERT CARD
// ============================================================================

class _AlertCard extends StatelessWidget {
  final SosModel alert;

  const _AlertCard({required this.alert});

  @override
  Widget build(BuildContext context) {
    final isCritical = alert.severity == 'CRITICAL';
    final isHigh = alert.severity == 'HIGH';
    final isLow = alert.severity == 'LOW';

    final severityColor = isCritical
        ? AppColors.severityCritical
        : isHigh
        ? AppColors.severityHigh
        : isLow
        ? AppColors.severityLow
        : AppColors.severityMedium;

    final locationText =
        '${alert.latitude.toStringAsFixed(5)}, '
        '${alert.longitude.toStringAsFixed(5)}';

    final backendId = alert.id.isNotEmpty ? alert.id : alert.sosId;

    final attachments = _parseAttachments(alert.notes);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ------------------------------------------------------------
            // TOP ROW
            // ------------------------------------------------------------

            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: severityColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${alert.severity} SOS',
                    style: TextStyle(
                      color: severityColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
                const Spacer(),
                _buildStatusBadge(alert.status),
              ],
            ),

            const SizedBox(height: 12),

            // ------------------------------------------------------------
            // VICTIM
            // ------------------------------------------------------------
            Text(
              alert.userName,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 5),

            _infoRow(
              Icons.phone_outlined,
              'Phone',
              alert.userPhone.isEmpty ? 'Not available' : alert.userPhone,
            ),

            _infoRow(Icons.location_on_outlined, 'Location', locationText),

            if (alert.accuracy > 0)
              _infoRow(
                Icons.gps_fixed,
                'GPS Accuracy',
                '${alert.accuracy.toStringAsFixed(1)} m',
              ),

            if (alert.batteryLevel >= 0)
              _infoRow(Icons.battery_std, 'Battery', '${alert.batteryLevel}%'),

            // ------------------------------------------------------------
            // RISK
            // ------------------------------------------------------------
            if (alert.riskLevel != null)
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: severityColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: severityColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Priority: ${alert.riskLevel} '
                        '(${alert.riskScore?.toStringAsFixed(0) ?? '—'}/100)',
                        style: TextStyle(
                          color: severityColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            if (alert.riskReason.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Risk reason: ${alert.riskReason}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),

            // ------------------------------------------------------------
            // NOTES / MESSAGE
            // ------------------------------------------------------------
            if (attachments.message.isNotEmpty)
              _buildMessageBox(attachments.message),

            // ------------------------------------------------------------
            // PHOTO
            // ------------------------------------------------------------
            if (attachments.photoBase64 != null)
              _buildPhotoSection(context, attachments.photoBase64!),

            // ------------------------------------------------------------
            // AUDIO
            // ------------------------------------------------------------
            if (attachments.audioBase64 != null)
              _AudioPlayerCard(
                audioBase64: attachments.audioBase64!,
                durationMs: attachments.audioDurationMs,
              ),

            const SizedBox(height: 14),

            // ------------------------------------------------------------
            // ACTION BUTTONS
            // ------------------------------------------------------------
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LiveTrackingScreen(
                            sosId: alert.sosId,
                            victimName: alert.userName,
                            coordinates: locationText,
                            victimLatitude: alert.latitude,
                            victimLongitude: alert.longitude,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.navigation_outlined, size: 18),
                    label: const Text('Track'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.headerBlue,
                      foregroundColor: Colors.white,
                    ),
                    onPressed:
                        alert.status == 'ACTIVE' || alert.status == 'PENDING'
                        ? () async {
                            final success = await context
                                .read<SosProvider>()
                                .markResponding(backendId);

                            if (!context.mounted) return;

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  success
                                      ? 'SOS marked as Responding.'
                                      : 'Could not update SOS status.',
                                ),
                                backgroundColor: success
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            );
                          }
                        : null,
                    child: const Text('Responding'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: alert.status != 'RESCUED'
                        ? () async {
                            final success = await context
                                .read<SosProvider>()
                                .markResolved(backendId);

                            if (!context.mounted) return;

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  success
                                      ? 'SOS marked as Resolved.'
                                      : 'Could not resolve SOS.',
                                ),
                                backgroundColor: success
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            );
                          }
                        : null,
                    child: const Text('Resolved'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;

    switch (status.toUpperCase()) {
      case 'ACTIVE':
        color = Colors.red;
        break;

      case 'ACKNOWLEDGED':
        color = Colors.orange;
        break;

      case 'RESCUED':
        color = Colors.green;
        break;

      case 'CANCELLED':
        color = Colors.grey;
        break;

      default:
        color = Colors.blue;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: AppColors.headerBlue),
          const SizedBox(width: 7),
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildMessageBox(String message) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.message_outlined, color: Colors.orange),
          const SizedBox(width: 9),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  Widget _buildPhotoSection(BuildContext context, String photoBase64) {
    try {
      final bytes = base64Decode(photoBase64);

      return Container(
        margin: const EdgeInsets.only(top: 12),
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.headerBlue.withOpacity(0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.photo_camera_rounded, color: AppColors.headerBlue),
                SizedBox(width: 8),
                Text(
                  'Emergency Photo',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) {
                    return Dialog(
                      child: InteractiveViewer(
                        child: Image.memory(bytes, fit: BoxFit.contain),
                      ),
                    );
                  },
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(
                  bytes,
                  width: double.infinity,
                  height: 220,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) {
                    return const SizedBox(
                      height: 150,
                      child: Center(child: Text('Unable to display photo')),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tap the photo to view full size',
              style: TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ],
        ),
      );
    } catch (_) {
      return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(12),
        child: const Text(
          'Emergency photo was received but could not be decoded.',
          style: TextStyle(color: Colors.red),
        ),
      );
    }
  }

  // ==========================================================================
  // ATTACHMENT PARSER
  // ==========================================================================

  static _SosAttachments _parseAttachments(String notes) {
    if (notes.trim().isEmpty) {
      return const _SosAttachments();
    }

    String message = '';

    String? photoBase64;
    String? audioBase64;

    int audioDurationMs = 0;

    final lines = notes.split('\n');

    for (final line in lines) {
      if (line.startsWith('SOS_MESSAGE:')) {
        final value = line.substring('SOS_MESSAGE:'.length);

        if (message.isEmpty) {
          message = value.trim();
        } else {
          message = '$message\n${value.trim()}';
        }
      } else if (line.startsWith('SOS_PHOTO_BASE64:')) {
        final encoded = line.substring('SOS_PHOTO_BASE64:'.length);

        try {
          final decodedJson = utf8.decode(base64Decode(encoded));

          final Map<String, dynamic> data = jsonDecode(decodedJson);

          photoBase64 = data['image']?.toString();
        } catch (_) {
          photoBase64 = null;
        }
      } else if (line.startsWith('SOS_VOICE_BASE64:')) {
        final encoded = line.substring('SOS_VOICE_BASE64:'.length);

        try {
          final decodedJson = utf8.decode(base64Decode(encoded));

          final Map<String, dynamic> data = jsonDecode(decodedJson);

          audioBase64 = data['audio']?.toString();

          audioDurationMs = (data['durationMs'] as num?)?.toInt() ?? 0;
        } catch (_) {
          audioBase64 = null;
        }
      }
    }

    return _SosAttachments(
      message: message,
      photoBase64: photoBase64,
      audioBase64: audioBase64,
      audioDurationMs: audioDurationMs,
    );
  }
}

// ============================================================================
// ATTACHMENT MODEL
// ============================================================================

class _SosAttachments {
  final String message;
  final String? photoBase64;
  final String? audioBase64;
  final int audioDurationMs;

  const _SosAttachments({
    this.message = '',
    this.photoBase64,
    this.audioBase64,
    this.audioDurationMs = 0,
  });
}

// ============================================================================
// AUDIO PLAYER
// ============================================================================

class _AudioPlayerCard extends StatefulWidget {
  final String audioBase64;
  final int durationMs;

  const _AudioPlayerCard({required this.audioBase64, required this.durationMs});

  @override
  State<_AudioPlayerCard> createState() => _AudioPlayerCardState();
}

class _AudioPlayerCardState extends State<_AudioPlayerCard> {
  final AudioPlayer _audioPlayer = AudioPlayer();

  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;

  PlayerState _playerState = PlayerState.stopped;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();

    _playerStateSubscription = _audioPlayer.onPlayerStateChanged.listen((
      state,
    ) {
      if (!mounted) return;

      setState(() {
        _playerState = state;
      });
    });

    _positionSubscription = _audioPlayer.onPositionChanged.listen((position) {
      if (!mounted) return;

      setState(() {
        _position = position;
      });
    });

    _durationSubscription = _audioPlayer.onDurationChanged.listen((duration) {
      if (!mounted) return;

      setState(() {
        _duration = duration;
      });
    });
  }

  @override
  void dispose() {
    _playerStateSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();

    _audioPlayer.dispose();

    super.dispose();
  }

  Future<void> _toggleAudio() async {
    try {
      if (_playerState == PlayerState.playing) {
        await _audioPlayer.pause();
        return;
      }

      if (_playerState == PlayerState.paused) {
        await _audioPlayer.resume();
        return;
      }

      final bytes = base64Decode(widget.audioBase64);

      if (bytes.isEmpty) {
        throw Exception('Audio data is empty.');
      }

      await _audioPlayer.play(BytesSource(bytes));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to play emergency audio: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');

    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');

    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final totalDuration = _duration.inMilliseconds > 0
        ? _duration
        : Duration(milliseconds: widget.durationMs);

    final maxMilliseconds = totalDuration.inMilliseconds > 0
        ? totalDuration.inMilliseconds.toDouble()
        : 1.0;

    final currentMilliseconds = _position.inMilliseconds
        .clamp(
          0,
          totalDuration.inMilliseconds > 0 ? totalDuration.inMilliseconds : 1,
        )
        .toDouble();

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.purple.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.mic_rounded, color: Colors.purple),
              SizedBox(width: 8),
              Text(
                'Emergency Voice Recording',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                onPressed: _toggleAudio,
                iconSize: 34,
                color: Colors.purple,
                icon: Icon(
                  _playerState == PlayerState.playing
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_fill,
                ),
              ),
              Expanded(
                child: Slider(
                  value: currentMilliseconds,
                  max: maxMilliseconds,
                  onChanged: (value) {
                    _audioPlayer.seek(Duration(milliseconds: value.toInt()));
                  },
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(_position),
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
                Text(
                  _formatDuration(totalDuration),
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
