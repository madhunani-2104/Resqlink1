import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/sos_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../mesh_chat/providers/mesh_chat_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/voice_recording_service.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({Key? key}) : super(key: key);

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  String _selectedSeverity = 'Medium';
  final _messageController = TextEditingController();
  bool _isRecordingVoice = false;
  String? _voiceRecordingPath;
  String? _voiceRecordingBase64;
  bool _hasPhoto = false;

  @override
  Widget build(BuildContext context) {
    final sosProvider = Provider.of<SosProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final meshProvider = Provider.of<MeshChatProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: const Text(
          'Emergency SOS',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
        child: Column(
          children: [
            // Big Glowing Circular SOS Button
            Center(
              child: GestureDetector(
                onTap: () async {
                  final user = authProvider.user;
                  if (user != null) {
                    final notes = await _prepareSosNotes();
                    await sosProvider.triggerSos(
                      userId: user.id,
                      userName: user.name,
                      userPhone: user.phone,
                      emergencyContacts: user.emergencyContacts,
                      broadcastMeshPacket: meshProvider.broadcastEmergencySos,
                      notes: notes,
                      severity: _selectedSeverity.toUpperCase(),
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Distress Beacon Sent across Mesh Network!'),
                          backgroundColor: AppColors.primary,
                        ),
                      );
                    }
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.4),
                        blurRadius: 36,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text(
                        'SOS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'TAP TO SEND',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 28),

            // Select Severity Section
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Select Severity',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                _buildSeverityTile(
                  label: 'Low',
                  icon: Icons.check_circle_outline_rounded,
                  iconColor: AppColors.severityLow,
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildSeverityTile(
                  label: 'Medium',
                  icon: Icons.warning_amber_rounded,
                  iconColor: AppColors.severityMedium,
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildSeverityTile(
                  label: 'High',
                  icon: Icons.error_outline_rounded,
                  iconColor: AppColors.severityHigh,
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildSeverityTile(
                  label: 'Critical',
                  icon: Icons.cancel_outlined,
                  iconColor: AppColors.severityCritical,
                  isDark: isDark,
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Action Cards Row (Voice Recording & Take Photo)
            Row(
              children: [
                // Voice Recording Card
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      if (_isRecordingVoice) {
                        final path = await VoiceRecordingService.stopRecording();
                        final payload = path == null
                            ? null
                            : await VoiceRecordingService.readRecordingBase64(path);
                        setState(() {
                          _isRecordingVoice = false;
                          _voiceRecordingPath = path ?? _voiceRecordingPath;
                          _voiceRecordingBase64 = payload ?? _voiceRecordingBase64;
                        });
                      } else {
                        final path = await VoiceRecordingService.startRecording();
                        setState(() {
                          _isRecordingVoice = path != null;
                          _voiceRecordingPath = path;
                        });
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            _isRecordingVoice
                                ? 'Recording voice note... tap again to stop.'
                                : (_voiceRecordingPath == null
                                    ? 'Microphone permission needed.'
                                    : 'Voice note attached to SOS.'),
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _isRecordingVoice
                              ? AppColors.headerBlue
                              : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                          width: _isRecordingVoice ? 2 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isRecordingVoice ? Icons.mic_rounded : Icons.mic_none_rounded,
                            color: AppColors.headerBlue,
                            size: 26,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Voice Recording',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _isRecordingVoice
                                      ? 'Recording...'
                                      : (_voiceRecordingPath == null ? 'Tap to record' : 'Audio Attached'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? Colors.white60 : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Take Photo Card
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _hasPhoto = !_hasPhoto);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            _hasPhoto
                                ? 'Photo captured successfully.'
                                : 'Photo attachment cleared.',
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _hasPhoto
                              ? AppColors.headerBlue
                              : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                          width: _hasPhoto ? 2 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _hasPhoto ? Icons.camera_rounded : Icons.camera_alt_outlined,
                            color: AppColors.headerBlue,
                            size: 26,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Take Photo',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _hasPhoto ? 'Photo Captured' : 'Tap to capture',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? Colors.white60 : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Additional Message (Optional) Input
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _messageController,
                maxLines: 3,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  hintText: 'Additional Message (Optional)',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white38 : Colors.black38,
                    fontSize: 15,
                  ),
                  border: InputBorder.none,
                  filled: false,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Send SOS Alert Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 6,
                  shadowColor: AppColors.primary.withOpacity(0.4),
                ),
                onPressed: () async {
                  final user = authProvider.user;
                  if (user != null) {
                    final notes = await _prepareSosNotes();
                    await sosProvider.triggerSos(
                      userId: user.id,
                      userName: user.name,
                      userPhone: user.phone,
                      emergencyContacts: user.emergencyContacts,
                      broadcastMeshPacket: meshProvider.broadcastEmergencySos,
                      notes: notes,
                      severity: _selectedSeverity.toUpperCase(),
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('SOS Alert Broadcasted to Mesh Network!'),
                          backgroundColor: AppColors.primary,
                        ),
                      );
                    }
                  }
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.send_rounded, color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                    Column(
                      children: const [
                        Text(
                          'Send SOS Alert',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Will be sent via Mesh Network',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
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

  Future<String> _prepareSosNotes() async {
    if (_isRecordingVoice) {
      final path = await VoiceRecordingService.stopRecording();
      final payload = path == null ? null : await VoiceRecordingService.readRecordingBase64(path);
      setState(() {
        _isRecordingVoice = false;
        _voiceRecordingPath = path ?? _voiceRecordingPath;
        _voiceRecordingBase64 = payload ?? _voiceRecordingBase64;
      });
    }

    final parts = <String>[];
    final text = _messageController.text.trim();
    if (text.isNotEmpty) parts.add(text);
    if (_voiceRecordingBase64 != null) parts.add('VOICE_MESSAGE_BASE64:$_voiceRecordingBase64');
    if (_hasPhoto) parts.add('PHOTO_ATTACHED');
    return parts.join('\n');
  }

  Widget _buildSeverityTile({
    required String label,
    required IconData icon,
    required Color iconColor,
    required bool isDark,
  }) {
    final isSelected = _selectedSeverity == label;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedSeverity = label);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? (label == 'Medium' ? const Color(0xFFD97706) : AppColors.primary)
                  : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? (label == 'Medium'
                        ? const Color(0xFFD97706).withOpacity(0.15)
                        : AppColors.primary.withOpacity(0.15))
                    : Colors.black.withOpacity(0.03),
                blurRadius: isSelected ? 8 : 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(icon, color: iconColor, size: 24),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
