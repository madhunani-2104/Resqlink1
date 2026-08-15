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
  final _messageController = TextEditingController();

  Future<void> _sendFile() async {
    final picked = await FileAccessService.pickFile();
    if (!mounted) return;
    if (picked == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File selection was cancelled or unavailable.')),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final chatProvider = Provider.of<MeshChatProvider>(context, listen: false);
    final user = authProvider.user;
    final senderId = user?.id ?? chatProvider.currentUserId;
    final senderName = user?.name ?? 'Test User';

    final success = await chatProvider.sendFile(
      senderId: senderId,
      senderName: senderName,
      path: picked.path,
      receiverId: widget.receiverId,
      fileName: picked.name,
      mimeType: picked.mimeType,
      fileSize: picked.size,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(success ? 'File sent successfully.' : 'File transfer failed.')),
    );
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final chatProvider = Provider.of<MeshChatProvider>(context, listen: false);

    final user = authProvider.user;
    final senderId = user?.id ?? chatProvider.currentUserId;
    final senderName = user?.name ?? 'Test User';

    chatProvider.sendMessage(
      senderId: senderId,
      senderName: senderName,
      text: text,
      receiverId: widget.receiverId,
    );
    _messageController.clear();
  }

  Future<void> _openAttachment(ChatAttachment attachment) async {
    final chatProvider = Provider.of<MeshChatProvider>(context, listen: false);
    final path = await chatProvider.downloadFile(attachment.fileId, attachment.fileName, inlineBase64: attachment.inlineBase64);

    if (!mounted) return;
    if (path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to download this file.')),
      );
      return;
    }

    final opened = await FileAccessService.openFile(path, attachment.mimeType);
    if (!mounted || opened) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('The file was downloaded but could not be opened.')),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<MeshChatProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentId = authProvider.user?.id ?? chatProvider.currentUserId;
    final conversationMessages = chatProvider.messages.where((msg) {
      if (widget.receiverId == 'BROADCAST' || widget.receiverId == 'RESPONDERS_OPS') {
        return msg.receiverId == widget.receiverId;
      }
      return (msg.senderId == currentId && msg.receiverId == widget.receiverId) ||
          (msg.senderId == widget.receiverId && msg.receiverId == currentId);
    }).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final callProvider = Provider.of<CallProvider>(context, listen: false);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.channelName),
        actions: widget.receiverId == 'BROADCAST' || widget.receiverId == 'RESPONDERS_OPS'
            ? null
            : [
                IconButton(
                  tooltip: 'Audio call',
                  icon: const Icon(Icons.call_rounded),
                  onPressed: () => callProvider.startCall(
                    recipientId: widget.receiverId,
                    recipientName: widget.channelName,
                    type: CallType.audio,
                  ),
                ),
                IconButton(
                  tooltip: 'Video call',
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
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: conversationMessages.length,
              itemBuilder: (context, index) {
                final msg = conversationMessages[index];
                final isSos = msg.packetType == MeshPacketType.sosBeacon;
                final isMyMsg = msg.isMe || msg.senderId == currentId;
                final deliveryStatus = chatProvider.deliveryStatusByPacketId[msg.packetId] ?? 'Queued';
                final isVoice = msg.content.startsWith('VOICE_MESSAGE_BASE64:');
                final voicePayload = isVoice ? msg.content.replaceFirst('VOICE_MESSAGE_BASE64:', '') : null;
                final displayContent = isVoice
                    ? 'Voice message received'
                    : msg.content;

                return Align(
                  alignment: isMyMsg ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    decoration: BoxDecoration(
                      color: isSos
                          ? AppColors.primary.withOpacity(0.9)
                          : (isMyMsg ? AppColors.secondary : AppColors.darkCard),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg.senderName,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isMyMsg ? Colors.white70 : AppColors.bleActive,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (msg.attachment != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.insert_drive_file_rounded, color: Colors.white, size: 20),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      msg.attachment!.fileName,
                                      style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _formatFileSize(msg.attachment!.fileSize),
                                style: const TextStyle(fontSize: 11, color: Colors.white70),
                              ),
                              const SizedBox(height: 6),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                                onPressed: () => _openAttachment(msg.attachment!),
                                icon: const Icon(Icons.open_in_new, size: 16),
                                label: const Text('Open file'),
                              ),
                            ],
                          )
                        else if (isVoice)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.16),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () async {
                              if (voicePayload != null) {
                                await VoiceRecordingService.playBase64(voicePayload);
                              }
                            },
                            icon: const Icon(Icons.play_arrow_rounded, size: 18),
                            label: const Text('Play voice message'),
                          )
                        else
                          Text(
                            displayContent,
                            style: const TextStyle(fontSize: 14, color: Colors.white),
                          ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.cell_tower,
                              size: 11,
                              color: isMyMsg ? Colors.white60 : Colors.white38,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isMyMsg ? '$deliveryStatus - Hops: ${msg.hopCount}' : 'Hops: ${msg.hopCount}',
                              style: TextStyle(
                                fontSize: 10,
                                color: isMyMsg ? Colors.white60 : Colors.white38,
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
          Container(
            padding: const EdgeInsets.all(12),
            color: AppColors.darkSurface,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type mesh message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: AppColors.darkCard,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: AppColors.darkCard,
                  child: IconButton(
                    icon: const Icon(Icons.attach_file_rounded, color: Colors.white, size: 20),
                    onPressed: _sendFile,
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: AppColors.primary,
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
