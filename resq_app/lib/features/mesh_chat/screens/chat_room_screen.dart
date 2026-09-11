import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/mesh_chat_provider.dart';
import '../models/chat_message.dart';

import '../../auth/providers/auth_provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/voice_recording_service.dart';
import '../../../core/services/file_access_service.dart';
import '../../../core/utils/mesh_packet.dart';

import '../../calling/call_service.dart';

class ChatRoomScreen extends StatefulWidget {
  final String channelName;
  final String receiverId;

  const ChatRoomScreen({
    Key? key,
    required this.channelName,
    required this.receiverId,
  }) : super(key: key);

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  // ============================================================
  // CONTROLLERS
  // ============================================================

  final TextEditingController _messageController = TextEditingController();

  // ============================================================
  // RECORDING
  // ============================================================

  Timer? _recordingTimer;

  bool _isRecording = false;

  Duration _recordingDuration = Duration.zero;

  // ============================================================
  // PLAYBACK
  // ============================================================

  String? _playingMessageId;

  Duration _playbackPosition = Duration.zero;

  Duration _playbackDuration = Duration.zero;

  StreamSubscription<Duration>? _playbackPositionSubscription;

  StreamSubscription<Duration>? _playbackDurationSubscription;

  StreamSubscription<void>? _playbackCompleteSubscription;

  @override
  void initState() {
    super.initState();

    _playbackPositionSubscription = VoiceRecordingService.playbackPositionStream
        .listen((position) {
          if (!mounted) return;
          setState(() => _playbackPosition = position);
        });

    _playbackDurationSubscription = VoiceRecordingService.playbackDurationStream
        .listen((duration) {
          if (!mounted) return;
          setState(() => _playbackDuration = duration);
        });

    _playbackCompleteSubscription = VoiceRecordingService.playbackCompleteStream
        .listen((_) {
          if (!mounted) return;
          setState(() {
            _playingMessageId = null;
            _playbackPosition = Duration.zero;
            _playbackDuration = Duration.zero;
          });
        });
  }

  // ============================================================
  // FORMAT DURATION
  // ============================================================

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');

    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');

    return '$minutes:$seconds';
  }

  // ============================================================
  // START RECORDING
  // ============================================================

  Future<void> _startVoiceRecording() async {
    debugPrint('CHAT MIC: _startVoiceRecording CALLED');

    if (_isRecording) {
      debugPrint('CHAT MIC: Already recording');
      return;
    }

    debugPrint('CHAT MIC: Calling VoiceRecordingService.startRecording()');

    final path = await VoiceRecordingService.startRecording();

    debugPrint('CHAT MIC: Recording path = $path');

    if (!mounted) {
      return;
    }

    if (path == null) {
      debugPrint('CHAT MIC: RECORDING FAILED - no path returned');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission is required.')),
      );

      return;
    }

    setState(() {
      _isRecording = true;
      _recordingDuration = Duration.zero;
    });

    debugPrint('CHAT MIC: RECORDING STARTED');

    _recordingTimer?.cancel();

    _recordingTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted || !_isRecording) {
        return;
      }

      setState(() {
        _recordingDuration =
            VoiceRecordingService.getCurrentRecordingDuration();
      });
    });
  }

  // ============================================================
  // STOP RECORDING
  // ============================================================

  Future<void> _stopVoiceRecording({bool send = true}) async {
    debugPrint('CHAT MIC: _stopVoiceRecording CALLED - send=$send');

    if (!_isRecording) {
      debugPrint('CHAT MIC: Not currently recording');
      return;
    }

    _recordingTimer?.cancel();
    _recordingTimer = null;

    final duration = _recordingDuration;

    debugPrint(
      'CHAT MIC: Stopping after '
      '${duration.inMilliseconds}ms',
    );

    final path = await VoiceRecordingService.stopRecording();

    debugPrint('CHAT MIC: Recording stopped. path=$path');

    if (!mounted) {
      return;
    }

    setState(() {
      _isRecording = false;
    });

    // ----------------------------------------------------------
    // RECORDING FAILED
    // ----------------------------------------------------------

    if (path == null) {
      debugPrint('CHAT MIC: STOP FAILED');

      setState(() {
        _recordingDuration = Duration.zero;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Voice recording failed.')));

      return;
    }

    // ----------------------------------------------------------
    // CANCEL
    // ----------------------------------------------------------

    if (!send) {
      debugPrint('CHAT MIC: Recording cancelled');

      setState(() {
        _recordingDuration = Duration.zero;
      });

      return;
    }

    // ----------------------------------------------------------
    // MINIMUM DURATION
    // ----------------------------------------------------------

    if (duration.inMilliseconds < 500) {
      debugPrint(
        'CHAT MIC: Recording too short: '
        '${duration.inMilliseconds}ms',
      );

      setState(() {
        _recordingDuration = Duration.zero;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please hold the microphone longer.')),
      );

      return;
    }

    // ----------------------------------------------------------
    // CREATE VOICE PAYLOAD
    // ----------------------------------------------------------

    debugPrint('CHAT MIC: Creating voice payload');

    final payload = await VoiceRecordingService.createVoiceMessagePayload(
      path,
      duration: duration,
    );

    if (!mounted) {
      return;
    }

    if (payload == null || payload.isEmpty) {
      debugPrint('CHAT MIC: PAYLOAD CREATION FAILED');

      setState(() {
        _recordingDuration = Duration.zero;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not create voice message.')),
      );

      return;
    }

    debugPrint('CHAT MIC: Voice payload created');

    // ----------------------------------------------------------
    // PROVIDERS
    // ----------------------------------------------------------

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final chatProvider = Provider.of<MeshChatProvider>(context, listen: false);

    final user = authProvider.user;

    final senderId = user?.id ?? chatProvider.currentUserId;

    final senderName = user?.name ?? 'Test User';

    // ----------------------------------------------------------
    // SEND
    // ----------------------------------------------------------

    bool success = false;

    try {
      debugPrint('CHAT MIC: Sending voice message');

      debugPrint('CHAT MIC: receiverId=${widget.receiverId}');

      success = await chatProvider.sendVoiceMessage(
        senderId: senderId,
        senderName: senderName,
        voicePayload: payload,
        receiverId: widget.receiverId,
      );

      debugPrint('CHAT MIC: SEND RESULT = $success');
    } catch (e) {
      debugPrint('CHAT VOICE SEND ERROR: $e');
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _recordingDuration = Duration.zero;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Voice message sent '
                    '(${_formatDuration(duration)})'
              : 'Voice message could not be sent.',
        ),
      ),
    );
  }

  // ============================================================
  // SEND TEXT
  // ============================================================

  Future<void> _sendMessage() async {
    if (_isRecording) {
      return;
    }

    final text = _messageController.text.trim();

    if (text.isEmpty) {
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final chatProvider = Provider.of<MeshChatProvider>(context, listen: false);

    final user = authProvider.user;

    final senderId = user?.id ?? chatProvider.currentUserId;

    final senderName = user?.name ?? 'Test User';

    try {
      await chatProvider.sendMessage(
        senderId: senderId,
        senderName: senderName,
        text: text,
        receiverId: widget.receiverId,
      );

      if (!mounted) {
        return;
      }

      _messageController.clear();
    } catch (e) {
      debugPrint('CHAT TEXT SEND ERROR: $e');

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message could not be sent.')),
      );
    }
  }

  // ============================================================
  // SEND FILE
  // ============================================================

  Future<void> _sendFile() async {
    if (_isRecording) {
      return;
    }

    final picked = await FileAccessService.pickFile();

    if (!mounted || picked == null) {
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final chatProvider = Provider.of<MeshChatProvider>(context, listen: false);

    final user = authProvider.user;

    final senderId = user?.id ?? chatProvider.currentUserId;

    final senderName = user?.name ?? 'Test User';

    bool success = false;

    try {
      success = await chatProvider.sendFile(
        senderId: senderId,
        senderName: senderName,
        path: picked.path,
        receiverId: widget.receiverId,
        fileName: picked.name,
        mimeType: picked.mimeType,
        fileSize: picked.size,
      );
    } catch (e) {
      debugPrint('FILE SEND ERROR: $e');
    }

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? 'File sent successfully.' : 'File transfer failed.',
        ),
      ),
    );
  }

  // ============================================================
  // PLAY VOICE
  // ============================================================

  Future<void> _playVoice(String payload, String messageId) async {
    if (_playingMessageId == messageId) {
      await VoiceRecordingService.stopPlayback();

      if (mounted) {
        setState(() {
          _playingMessageId = null;
          _playbackPosition = Duration.zero;
          _playbackDuration = Duration.zero;
        });
      }

      return;
    }

    await VoiceRecordingService.stopPlayback();

    if (mounted) {
      setState(() {
        _playingMessageId = null;
        _playbackPosition = Duration.zero;
        _playbackDuration = Duration.zero;
      });
    }

    final success = await VoiceRecordingService.playBase64(
      payload,
      playbackId: messageId,
    );

    if (!mounted) {
      return;
    }

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to play voice message.')),
      );

      return;
    }

    setState(() {
      _playingMessageId = messageId;
      _playbackPosition = Duration.zero;
      _playbackDuration = Duration.zero;
    });
  }

  // ============================================================
  // VOICE BUBBLE
  // ============================================================

  Widget _buildVoiceBubble({
    required ChatVoiceMessage voice,
    required String messageId,
  }) {
    final isPlaying = _playingMessageId == messageId;

    final duration = voice.durationMs > 0 ? voice.formattedDuration : 'Voice';
    final maxMillis = _playbackDuration.inMilliseconds > 0
        ? _playbackDuration.inMilliseconds
        : voice.durationMs;
    final progress = maxMillis > 0
        ? (_playbackPosition.inMilliseconds / maxMillis).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () => _playVoice(voice.base64Audio, messageId),
            icon: Icon(
              isPlaying
                  ? Icons.stop_circle_rounded
                  : Icons.play_circle_fill_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const Icon(Icons.mic_rounded, color: Colors.white70, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(
                  value: isPlaying ? progress : 0,
                  minHeight: 3,
                  backgroundColor: Colors.white24,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 4),
                Text(
                  isPlaying && _playbackPosition > Duration.zero
                      ? '${VoiceRecordingService.formatDuration(_playbackPosition)} / $duration'
                      : duration,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FILE SIZE
  // ============================================================

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }

    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }

    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }

    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  // ============================================================
  // FILE BUBBLE
  // ============================================================

  Widget _buildFileBubble(ChatAttachment attachment) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.insert_drive_file_rounded, color: Colors.white),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                attachment.fileName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          _formatFileSize(attachment.fileSize),
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
        const SizedBox(height: 5),
        OutlinedButton.icon(
          onPressed: () => _openAttachment(attachment),
          icon: const Icon(Icons.open_in_new, size: 16),
          label: const Text('Open file'),
          style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
        ),
      ],
    );
  }

  // ============================================================
  // OPEN FILE
  // ============================================================

  Future<void> _openAttachment(ChatAttachment attachment) async {
    final chatProvider = Provider.of<MeshChatProvider>(context, listen: false);

    final path = await chatProvider.downloadFile(
      attachment.fileId,
      attachment.fileName,
      inlineBase64: attachment.inlineBase64,
    );

    if (!mounted) {
      return;
    }

    if (path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to download this file.')),
      );

      return;
    }

    final opened = await FileAccessService.openFile(path, attachment.mimeType);

    if (!mounted || opened) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('The file was downloaded but could not be opened.'),
      ),
    );
  }

  // ============================================================
  // RECORDING BAR
  // ============================================================

  Widget _buildRecordingBar() {
    if (!_isRecording) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.primary.withOpacity(0.12),
      child: Row(
        children: [
          const Icon(
            Icons.fiber_manual_record,
            color: AppColors.primary,
            size: 14,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Recording '
              '${_formatDuration(_recordingDuration)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(
            onPressed: () => _stopVoiceRecording(send: false),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MESSAGE FILTER
  // ============================================================

  List<ChatMessage> _getVisibleMessages(
    MeshChatProvider chatProvider,
    String currentId,
  ) {
    final messages = chatProvider.messages.where((msg) {
      if (widget.receiverId == 'BROADCAST' ||
          widget.receiverId == 'RESPONDERS_OPS') {
        return msg.receiverId == widget.receiverId;
      }

      final sentByMe =
          msg.senderId == currentId && msg.receiverId == widget.receiverId;

      final receivedFromUser =
          msg.senderId == widget.receiverId && msg.receiverId == currentId;

      return sentByMe || receivedFromUser;
    }).toList();

    messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return messages;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<MeshChatProvider>(context);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final currentId = authProvider.user?.id ?? chatProvider.currentUserId;

    final messages = _getVisibleMessages(chatProvider, currentId);

    final isBroadcast =
        widget.receiverId == 'BROADCAST' ||
        widget.receiverId == 'RESPONDERS_OPS';

    final callProvider = Provider.of<CallProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.channelName),
        actions: isBroadcast
            ? null
            : [
                IconButton(
                  icon: const Icon(Icons.call_rounded),
                  onPressed: () => callProvider.startCall(
                    recipientId: widget.receiverId,
                    recipientName: widget.channelName,
                    type: CallType.audio,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.videocam_rounded),
                  onPressed: () => callProvider.startCall(
                    recipientId: widget.receiverId,
                    recipientName: widget.channelName,
                    type: CallType.video,
                  ),
                ),
              ],
      ),
      body: Column(
        children: [
          // ======================================================
          // MESSAGES
          // ======================================================

          Expanded(
            child: messages.isEmpty
                ? const Center(
                    child: Text(
                      'No messages yet.',
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];

                      final isMyMsg = msg.isMe || msg.senderId == currentId;

                      final isSos = msg.packetType == MeshPacketType.sosBeacon;

                      final status =
                          chatProvider.deliveryStatusByPacketId[msg.packetId] ??
                          'Queued';

                      return Align(
                        alignment: isMyMsg
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.78,
                          ),
                          decoration: BoxDecoration(
                            color: isSos
                                ? AppColors.primary.withOpacity(0.9)
                                : isMyMsg
                                ? AppColors.secondary
                                : AppColors.darkCard,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                msg.senderName,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(height: 5),

                              if (msg.attachment != null)
                                _buildFileBubble(msg.attachment!)
                              else if (msg.voiceMessage != null)
                                _buildVoiceBubble(
                                  voice: msg.voiceMessage!,
                                  messageId: msg.packetId,
                                )
                              else
                                Text(
                                  msg.content,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),

                              const SizedBox(height: 5),

                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.cell_tower,
                                    size: 11,
                                    color: Colors.white54,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isMyMsg
                                        ? '$status • Hops: ${msg.hopCount}'
                                        : 'Hops: ${msg.hopCount}',
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // ======================================================
          // RECORDING BAR
          // ======================================================
          _buildRecordingBar(),

          // ======================================================
          // INPUT BAR
          // ======================================================
          Container(
            padding: const EdgeInsets.all(12),
            color: AppColors.darkSurface,
            child: Row(
              children: [
                // =================================================
                // VOICE BUTTON
                // =================================================

                GestureDetector(
                  behavior: HitTestBehavior.opaque,

                  onLongPressStart: (_) {
                    debugPrint('CHAT MIC UI: LONG PRESS START');

                    _startVoiceRecording();
                  },

                  onLongPressEnd: (_) {
                    debugPrint('CHAT MIC UI: LONG PRESS END');

                    _stopVoiceRecording();
                  },

                  onLongPressCancel: () {
                    debugPrint('CHAT MIC UI: LONG PRESS CANCEL');

                    _stopVoiceRecording();
                  },

                  child: Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _isRecording
                          ? AppColors.primary
                          : AppColors.darkCard,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isRecording ? Icons.mic_rounded : Icons.mic_none_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // =================================================
                // TEXT FIELD
                // =================================================
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    enabled: !_isRecording,
                    textInputAction: TextInputAction.send,
                    decoration: InputDecoration(
                      hintText: _isRecording
                          ? 'Recording...'
                          : 'Type mesh message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: AppColors.darkCard,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),

                const SizedBox(width: 8),

                // =================================================
                // FILE
                // =================================================
                CircleAvatar(
                  backgroundColor: AppColors.darkCard,
                  child: IconButton(
                    icon: const Icon(
                      Icons.attach_file_rounded,
                      color: Colors.white,
                    ),
                    onPressed: _isRecording ? null : _sendFile,
                  ),
                ),

                const SizedBox(width: 8),

                // =================================================
                // SEND
                // =================================================
                CircleAvatar(
                  backgroundColor: AppColors.primary,
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded, color: Colors.white),
                    onPressed: _isRecording ? null : _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _playbackPositionSubscription?.cancel();
    _playbackDurationSubscription?.cancel();
    _playbackCompleteSubscription?.cancel();
    _recordingTimer?.cancel();

    if (_isRecording) {
      VoiceRecordingService.stopRecording();
    }

    _messageController.dispose();

    VoiceRecordingService.stopPlayback();

    super.dispose();
  }
}
