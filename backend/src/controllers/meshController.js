const MeshMessage = require('../models/MeshMessage');
const User = require('../models/User');
const uploadPath = require('path');
const fs = require('fs');
const SyncQueue = require('../models/SyncQueue');
const { processSyncedPayload } = require('../utils/syncUtils');

const uploadsDir = uploadPath.join(__dirname, '../../uploads');
const isSafeFileId = (fileId) => typeof fileId === 'string' && /^[a-zA-Z0-9-]+\.[a-zA-Z0-9]+$/.test(fileId);

const stripInlineData = (content) => {
  const prefix = 'FILE_ATTACHMENT:';
  if (typeof content !== 'string' || !content.startsWith(prefix)) return content;
  try {
    const data = JSON.parse(content.slice(prefix.length));
    if (!data || typeof data !== 'object') return content;
    delete data.inlineBase64;
    return `${prefix}${JSON.stringify(data)}`;
  } catch (_) {
    return content;
  }
};

const parseAttachment = (content) => {
  const prefix = 'FILE_ATTACHMENT:';
  if (typeof content !== 'string' || !content.startsWith(prefix)) return null;
  try {
    const data = JSON.parse(content.slice(prefix.length));
    if (!data || !isSafeFileId(data.fileId) || !data.fileName) return null;
    return {
      fileId: data.fileId,
      fileName: String(data.fileName).slice(0, 255),
      mimeType: String(data.mimeType || 'application/octet-stream').slice(0, 150),
      fileSize: Number(data.fileSize) || 0,
    };
  } catch (_) {
    return null;
  }
};

// @desc    Store/Sync Mesh Message from Client or Relay
// @route   POST /api/mesh/message
// @access  Private
const postMeshMessage = async (req, res, next) => {
  try {
    const { packetId, senderId, senderName, receiverId, content, packetType, ttl, hopCount, relayedBy, location } =
      req.body;

    let existing = await MeshMessage.findOne({ packetId });
    if (existing) {
      return res.json({ success: true, message: 'Message already received/deduplicated', data: existing });
    }

    const attachment = parseAttachment(content);
    const storedContent = attachment ? stripInlineData(content) : content;
    if (attachment) {
      const authenticatedIds = new Set([req.user._id.toString(), req.user.meshId].filter(Boolean));
      const effectiveSenderId = senderId || req.user.meshId || req.user._id.toString();
      if (!authenticatedIds.has(effectiveSenderId)) {
        return res.status(403).json({ success: false, message: 'Attachment sender does not match authenticated user' });
      }
      if (attachment.fileSize < 0 || attachment.fileSize > 5000000) {
        return res.status(400).json({ success: false, message: 'Invalid attachment size' });
      }
      const storedPath = uploadPath.join(uploadsDir, uploadPath.basename(attachment.fileId));
      if (!isSafeFileId(attachment.fileId) || !fs.existsSync(storedPath)) {
        return res.status(400).json({ success: false, message: 'Attachment is missing from storage' });
      }
    }

    const message = await MeshMessage.create({
      packetId: packetId || `PKT-${Date.now()}-${Math.floor(Math.random() * 1000)}`,
      senderId: senderId || req.user.meshId || req.user._id.toString(),
      senderName: senderName || req.user.name,
      receiverId: receiverId || 'BROADCAST',
      content: storedContent,
      packetType: typeof packetType === 'string' ? packetType.toUpperCase() : 'CHAT',
      ttl: ttl !== undefined ? ttl : 7,
      hopCount: hopCount || 0,
      relayedBy: relayedBy || [],
      location: location || undefined,
      attachment: attachment || undefined,
      syncStatus: 'SYNCED',
    });

    const io = req.app.get('socketio');
    if (io) {
      io.emit('mesh_message_received', message);
    }

    res.status(201).json({ success: true, data: message });
  } catch (error) {
    next(error);
  }
};

// @desc    Get recent broadcast mesh messages
// @route   GET /api/mesh/messages
// @access  Private
const getMeshMessages = async (req, res, next) => {
  try {
    const limit = parseInt(req.query.limit) || 50;
    const messages = await MeshMessage.find()
      .sort({ createdAt: -1 })
      .limit(limit);

    res.json({ success: true, count: messages.length, data: messages.reverse() });
  } catch (error) {
    next(error);
  }
};

// @desc    Upload a file for an authenticated mesh conversation
// @route   POST /api/mesh/files
// @access  Private
const uploadMeshFile = async (req, res, next) => {
  try {
    if (!req.file) {
      return res.status(400).json({ success: false, message: 'No file selected' });
    }

    const receiverId = typeof req.body.receiverId === 'string' ? req.body.receiverId.trim() : '';
    if (!receiverId) {
      fs.unlink(req.file.path, () => {});
      return res.status(400).json({ success: false, message: 'Receiver is required' });
    }

    if (!['BROADCAST', 'RESPONDERS_OPS'].includes(receiverId)) {
      let receiver = null;
      if (/^[a-fA-F0-9]{24}$/.test(receiverId)) {
        receiver = await User.findById(receiverId).select('_id meshId');
      }
      if (!receiver) receiver = await User.findOne({ meshId: receiverId }).select('_id meshId');
      if (!receiver) {
        fs.unlink(req.file.path, () => {});
        return res.status(400).json({ success: false, message: 'Invalid recipient' });
      }
    }

    res.status(201).json({
      success: true,
      data: {
        fileId: req.file.filename,
        name: req.file.originalname,
        mimeType: req.file.mimetype,
        size: req.file.size,
        downloadPath: `/api/mesh/files/${encodeURIComponent(req.file.filename)}`,
      },
    });
  } catch (error) {
    if (req.file?.path) fs.unlink(req.file.path, () => {});
    next(error);
  }
};

// @desc    Download a file only when the authenticated user belongs to its message
// @route   GET /api/mesh/files/:fileId
// @access  Private
const downloadMeshFile = async (req, res, next) => {
  try {
    const fileId = req.params.fileId;
    if (!isSafeFileId(fileId)) {
      return res.status(400).json({ success: false, message: 'Invalid file id' });
    }

    const message = await MeshMessage.findOne({ 'attachment.fileId': fileId }).select('senderId receiverId attachment');
    if (!message) return res.status(404).json({ success: false, message: 'File record not found' });

    const currentUserId = req.user._id.toString();
    const currentMeshId = req.user.meshId || '';
    const isSender = message.senderId === currentUserId || message.senderId === currentMeshId;
    const isDirectRecipient = message.receiverId === currentUserId || message.receiverId === currentMeshId;
    const isBroadcastRecipient = message.receiverId === 'BROADCAST';
    const isOpsRecipient = message.receiverId === 'RESPONDERS_OPS' && ['rescue_team', 'admin'].includes(req.user.role);
    if (!isSender && !isDirectRecipient && !isBroadcastRecipient && !isOpsRecipient) {
      return res.status(403).json({ success: false, message: 'Not authorized to access this file' });
    }

    const safeFileName = uploadPath.basename(fileId);
    const filePath = uploadPath.join(uploadsDir, safeFileName);
    if (!filePath.startsWith(uploadsDir + uploadPath.sep) || !fs.existsSync(filePath)) {
      return res.status(404).json({ success: false, message: 'File not found on storage' });
    }

    res.setHeader('Content-Type', message.attachment.mimeType || 'application/octet-stream');
    res.download(filePath, message.attachment.fileName, (error) => {
      if (error && !res.headersSent) next(error);
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Batch sync offline packets (automatic sync on internet recovery)
// @route   POST /api/mesh/sync-batch
// @access  Private
const syncBatch = async (req, res, next) => {
  try {
    const { items, deviceId } = req.body;
    if (!Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ success: false, message: 'No items provided for sync' });
    }

    const results = [];
    for (const item of items) {
      try {
        const processed = await processSyncedPayload(item.dataType, item.payload, req.user._id);
        
        await SyncQueue.create({
          deviceId: deviceId || 'UNKNOWN_DEVICE',
          userId: req.user._id,
          dataType: item.dataType,
          payload: item.payload,
        });

        results.push({ id: item.id || item.payload?.packetId || item.payload?.sosId, status: 'SUCCESS' });
      } catch (err) {
        results.push({ id: item.id || 'UNKNOWN', status: 'FAILED', error: err.message });
      }
    }

    res.json({
      success: true,
      message: `Batch processed ${items.length} sync items`,
      results,
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  postMeshMessage,
  getMeshMessages,
  uploadMeshFile,
  downloadMeshFile,
  syncBatch,
};
