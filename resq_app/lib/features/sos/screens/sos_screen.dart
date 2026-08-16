import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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

  final TextEditingController _messageController = TextEditingController();

  final ImagePicker _imagePicker = ImagePicker();

  bool _isRecordingVoice = false;
  bool _isSendingSos = false;

  String? _voiceRecordingPath;
  String? _voiceRecordingBase64;

  File? _capturedPhoto;
  String? _capturedPhotoBase64;

  Timer? _recordingTimer;
  Duration _recordingDuration = Duration.zero;

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _messageController.dispose();

    if (_isRecordingVoice) {
      VoiceRecordingService.stopRecording();
    }

    super.dispose();
  }

  // ============================================================
  // FORMAT RECORDING TIME
  // ============================================================

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');

    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');

    return '$minutes:$seconds';
  }

  // ============================================================
  // TAKE PHOTO
  // ============================================================

  Future<void> _takePhoto() async {
    if (_isSendingSos) {
      return;
    }

    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        maxWidth: 1600,
        maxHeight: 1600,
      );

      if (photo == null) {
        return;
      }

      final file = File(photo.path);

      if (!await file.exists()) {
        return;
      }

      final bytes = await file.readAsBytes();

      if (bytes.isEmpty) {
        throw Exception('Captured photo is empty.');
      }

      final base64Photo = base64Encode(bytes);

      if (!mounted) {
        return;
      }

      setState(() {
        _capturedPhoto = file;
        _capturedPhotoBase64 = base64Photo;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Photo captured and attached to SOS.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to capture photo: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // REMOVE PHOTO
  // ============================================================

  void _removePhoto() {
    setState(() {
      _capturedPhoto = null;
      _capturedPhotoBase64 = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Photo removed.'),
      ),
    );
  }

  // ============================================================
  // PHOTO PREVIEW
  // ============================================================

  Widget _buildPhotoPreview(bool isDark) {
    if (_capturedPhoto == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.headerBlue,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.photo_camera_rounded,
                color: AppColors.headerBlue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Photo attached to SOS',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              _capturedPhoto!,
              width: double.infinity,
              height: 220,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _takePhoto,
                  icon: const Icon(
                    Icons.camera_alt_rounded,
                  ),
                  label: const Text('Retake'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _removePhoto,
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                  ),
                  label: const Text('Remove'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // START VOICE RECORDING
  // ============================================================

  Future<void> _startVoiceRecording() async {
    if (_isRecordingVoice || _isSendingSos) {
      return;
    }

    final path = await VoiceRecordingService.startRecording();

    if (!mounted) {
      return;
    }

    if (path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Microphone permission is required for voice recording.',
          ),
          backgroundColor: Colors.red,
        ),
      );

      return;
    }

    _recordingTimer?.cancel();

    setState(() {
      _isRecordingVoice = true;
      _voiceRecordingPath = path;
      _voiceRecordingBase64 = null;
      _recordingDuration = Duration.zero;
    });

    _recordingTimer = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) {
        if (!mounted || !_isRecordingVoice) {
          return;
        }

        setState(() {
          _recordingDuration =
              VoiceRecordingService.getCurrentRecordingDuration();
        });
      },
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Recording... tap again to stop.',
        ),
      ),
    );
  }

  // ============================================================
  // STOP VOICE RECORDING
  // ============================================================

  Future<void> _stopVoiceRecording() async {
    if (!_isRecordingVoice) {
      return;
    }

    _recordingTimer?.cancel();
    _recordingTimer = null;

    final path = await VoiceRecordingService.stopRecording();

    if (!mounted) {
      return;
    }

    setState(() {
      _isRecordingVoice = false;
    });

    if (path == null) {
      setState(() {
        _voiceRecordingPath = null;
        _voiceRecordingBase64 = null;
        _recordingDuration = Duration.zero;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Voice recording could not be saved.',
          ),
          backgroundColor: Colors.red,
        ),
      );

      return;
    }

    final base64Audio = await VoiceRecordingService.readRecordingBase64(
      path,
    );

    if (!mounted) {
      return;
    }

    if (base64Audio == null || base64Audio.isEmpty) {
      setState(() {
        _voiceRecordingPath = null;
        _voiceRecordingBase64 = null;
        _recordingDuration = Duration.zero;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Voice recording is empty.',
          ),
          backgroundColor: Colors.red,
        ),
      );

      return;
    }

    setState(() {
      _voiceRecordingPath = path;
      _voiceRecordingBase64 = base64Audio;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Voice attached (${_formatDuration(_recordingDuration)}).',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  // ============================================================
  // TOGGLE VOICE
  // ============================================================

  Future<void> _toggleVoiceRecording() async {
    if (_isRecordingVoice) {
      await _stopVoiceRecording();
    } else {
      await _startVoiceRecording();
    }
  }

  // ============================================================
  // PREPARE SOS NOTES
  //
  // IMPORTANT:
  // This converts photo and voice into Base64 data so the
  // emergency packet can actually carry the attachments.
  // ============================================================

  Future<String> _prepareSosNotes() async {
    // ----------------------------------------------------------
    // If voice is still recording, stop it first.
    // ----------------------------------------------------------

    if (_isRecordingVoice) {
      await _stopVoiceRecording();
    }

    final List<String> parts = [];

    // ----------------------------------------------------------
    // TEXT
    // ----------------------------------------------------------

    final text = _messageController.text.trim();

    if (text.isNotEmpty) {
      parts.add(
        'SOS_MESSAGE:$text',
      );
    }

    // ----------------------------------------------------------
    // VOICE
    // ----------------------------------------------------------

    if (_voiceRecordingBase64 != null && _voiceRecordingBase64!.isNotEmpty) {
      final voiceData = {
        'version': 1,
        'mimeType': 'audio/mp4',
        'fileName': _voiceRecordingPath != null
            ? _voiceRecordingPath!.split(Platform.pathSeparator).last
            : 'sos_voice.m4a',
        'durationMs': _recordingDuration.inMilliseconds,
        'audio': _voiceRecordingBase64,
      };

      final encodedVoice = base64Encode(
        utf8.encode(
          jsonEncode(voiceData),
        ),
      );

      parts.add(
        'SOS_VOICE_BASE64:$encodedVoice',
      );
    }

    // ----------------------------------------------------------
    // PHOTO
    // ----------------------------------------------------------

    if (_capturedPhotoBase64 != null && _capturedPhotoBase64!.isNotEmpty) {
      final photoData = {
        'version': 1,
        'mimeType': 'image/jpeg',
        'fileName': 'sos_photo.jpg',
        'image': _capturedPhotoBase64,
      };

      final encodedPhoto = base64Encode(
        utf8.encode(
          jsonEncode(photoData),
        ),
      );

      parts.add(
        'SOS_PHOTO_BASE64:$encodedPhoto',
      );
    }

    // ----------------------------------------------------------
    // Return everything as one SOS notes string.
    // ----------------------------------------------------------

    return parts.join('\n');
  }

  // ============================================================
  // SEND SOS
  // ============================================================

  Future<void> _sendSos() async {
    if (_isSendingSos) {
      return;
    }

    final authProvider = Provider.of<AuthProvider>(
      context,
      listen: false,
    );

    final meshProvider = Provider.of<MeshChatProvider>(
      context,
      listen: false,
    );

    final sosProvider = Provider.of<SosProvider>(
      context,
      listen: false,
    );

    final user = authProvider.user;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'User information is not available.',
          ),
          backgroundColor: Colors.red,
        ),
      );

      return;
    }

    setState(() {
      _isSendingSos = true;
    });

    try {
      // --------------------------------------------------------
      // Prepare text + voice + photo.
      // --------------------------------------------------------

      final notes = await _prepareSosNotes();

      debugPrint(
        'SOS NOTES LENGTH: ${notes.length}',
      );

      debugPrint(
        'SOS HAS VOICE: '
        '${notes.contains('SOS_VOICE_BASE64:')}',
      );

      debugPrint(
        'SOS HAS PHOTO: '
        '${notes.contains('SOS_PHOTO_BASE64:')}',
      );

      // --------------------------------------------------------
      // Trigger SOS.
      // --------------------------------------------------------

      final sos = await sosProvider.triggerSos(
        userId: user.id,
        userName: user.name,
        userPhone: user.phone,
        emergencyContacts: user.emergencyContacts,
        broadcastMeshPacket: meshProvider.broadcastEmergencySos,
        notes: notes,
        severity: _selectedSeverity.toUpperCase(),
      );

      if (!mounted) {
        return;
      }

      if (sos != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'SOS Alert Broadcasted to Mesh Network!',
            ),
            backgroundColor: AppColors.primary,
            duration: Duration(seconds: 4),
          ),
        );

        // ------------------------------------------------------
        // Clear form after successful SOS.
        // ------------------------------------------------------

        setState(() {
          _messageController.clear();

          _capturedPhoto = null;
          _capturedPhotoBase64 = null;

          _voiceRecordingPath = null;
          _voiceRecordingBase64 = null;

          _isRecordingVoice = false;
          _recordingDuration = Duration.zero;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'SOS could not be sent. Please check location permission and GPS.',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'SOS could not be sent: $e',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSendingSos = false;
        });
      }
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final sosProvider = Provider.of<SosProvider>(context);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
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
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 24,
        ),
        child: Column(
          children: [
            // ==================================================
            // SOS BUTTON
            // ==================================================

            Center(
              child: GestureDetector(
                onTap: _isSendingSos ? null : _sendSos,
                child: AnimatedContainer(
                  duration: const Duration(
                    milliseconds: 300,
                  ),
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(
                          0.4,
                        ),
                        blurRadius: 36,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: Center(
                    child: _isSendingSos
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 42,
                                height: 42,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 4,
                                ),
                              ),
                              SizedBox(
                                height: 12,
                              ),
                              Text(
                                'SENDING...',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          )
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'SOS',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 42,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                ),
                              ),
                              SizedBox(
                                height: 4,
                              ),
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
            ),

            const SizedBox(height: 28),

            // ==================================================
            // SEVERITY
            // ==================================================

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

            // ==================================================
            // VOICE + CAMERA
            // ==================================================

            Row(
              children: [
                // VOICE
                Expanded(
                  child: GestureDetector(
                    onTap: _isSendingSos ? null : _toggleVoiceRecording,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : Colors.white,
                        borderRadius: BorderRadius.circular(
                          16,
                        ),
                        border: Border.all(
                          color: _isRecordingVoice
                              ? AppColors.headerBlue
                              : (isDark
                                  ? Colors.white12
                                  : const Color(
                                      0xFFE2E8F0,
                                    )),
                          width: _isRecordingVoice ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isRecordingVoice
                                ? Icons.mic_rounded
                                : Icons.mic_none_rounded,
                            color: AppColors.headerBlue,
                            size: 26,
                          ),
                          const SizedBox(
                            width: 10,
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Voice Recording',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                const SizedBox(
                                  height: 2,
                                ),
                                Text(
                                  _isRecordingVoice
                                      ? 'Recording ${_formatDuration(_recordingDuration)}'
                                      : (_voiceRecordingBase64 == null
                                          ? 'Tap to record'
                                          : 'Audio Attached'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? Colors.white60
                                        : Colors.black54,
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

                // PHOTO
                Expanded(
                  child: GestureDetector(
                    onTap: _isSendingSos ? null : _takePhoto,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : Colors.white,
                        borderRadius: BorderRadius.circular(
                          16,
                        ),
                        border: Border.all(
                          color: _capturedPhotoBase64 != null
                              ? AppColors.headerBlue
                              : (isDark
                                  ? Colors.white12
                                  : const Color(
                                      0xFFE2E8F0,
                                    )),
                          width: _capturedPhotoBase64 != null ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _capturedPhoto != null
                                ? Icons.camera_rounded
                                : Icons.camera_alt_outlined,
                            color: AppColors.headerBlue,
                            size: 26,
                          ),
                          const SizedBox(
                            width: 10,
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Take Photo',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                const SizedBox(
                                  height: 2,
                                ),
                                Text(
                                  _capturedPhoto != null
                                      ? 'Photo Captured'
                                      : 'Tap to capture',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? Colors.white60
                                        : Colors.black54,
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

            // PHOTO PREVIEW
            _buildPhotoPreview(
              isDark,
            ),

            const SizedBox(height: 20),

            // ==================================================
            // MESSAGE
            // ==================================================

            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(
                  16,
                ),
                border: Border.all(
                  color: isDark
                      ? Colors.white12
                      : const Color(
                          0xFFE2E8F0,
                        ),
                ),
              ),
              child: TextField(
                controller: _messageController,
                maxLines: 3,
                enabled: !_isSendingSos,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                ),
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

            // ==================================================
            // SEND SOS
            // ==================================================

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.primary.withOpacity(
                    0.5,
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 20,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      16,
                    ),
                  ),
                ),
                onPressed: _isSendingSos ? null : _sendSos,
                child: _isSendingSos
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          ),
                          SizedBox(
                            width: 12,
                          ),
                          Text(
                            'Sending SOS...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                          SizedBox(
                            width: 10,
                          ),
                          Column(
                            children: [
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

            const SizedBox(height: 20),

            // ==================================================
            // SOS STATUS
            // ==================================================

            if (sosProvider.isSosActive)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(
                  14,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(
                    14,
                  ),
                  border: Border.all(
                    color: Colors.red.withOpacity(
                      0.3,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_rounded,
                      color: Colors.red,
                    ),
                    const SizedBox(
                      width: 10,
                    ),
                    Expanded(
                      child: Text(
                        'An SOS alert is currently active.',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SEVERITY TILE
  // ============================================================

  Widget _buildSeverityTile({
    required String label,
    required IconData icon,
    required Color iconColor,
    required bool isDark,
  }) {
    final isSelected = _selectedSeverity == label;

    return Expanded(
      child: GestureDetector(
        onTap: _isSendingSos
            ? null
            : () {
                setState(() {
                  _selectedSeverity = label;
                });
              },
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: 14,
          ),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(
              16,
            ),
            border: Border.all(
              color: isSelected
                  ? (label == 'Medium'
                      ? const Color(
                          0xFFD97706,
                        )
                      : AppColors.primary)
                  : (isDark
                      ? Colors.white12
                      : const Color(
                          0xFFE2E8F0,
                        )),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: iconColor,
                size: 24,
              ),
              const SizedBox(
                height: 6,
              ),
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
