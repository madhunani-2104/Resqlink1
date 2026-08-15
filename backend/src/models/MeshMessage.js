const mongoose = require('mongoose');

const MeshMessageSchema = new mongoose.Schema(
  {
    packetId: { type: String, required: true, unique: true },
    senderId: { type: String, required: true },
    senderName: { type: String, required: true },
    receiverId: { type: String, default: 'BROADCAST' }, // 'BROADCAST' or specific mesh node ID / User ID
    content: { type: String, required: true },
    packetType: {
      type: String,
      enum: ['CHAT', 'SOS_BEACON', 'LOCATION_UPDATE', 'ACK'],
      default: 'CHAT',
    },
    ttl: { type: Number, default: 7 },
    hopCount: { type: Number, default: 0 },
    relayedBy: [{ type: String }],
    location: {
      latitude: { type: Number },
      longitude: { type: Number },
    },
    attachment: {
      fileId: { type: String },
      fileName: { type: String },
      mimeType: { type: String },
      fileSize: { type: Number },
    },
    syncStatus: {
      type: String,
      enum: ['PENDING', 'SYNCED', 'FAILED'],
      default: 'SYNCED',
    },
    timestampSent: { type: Date, default: Date.now },
  },
  { timestamps: true }
);

module.exports = mongoose.model('MeshMessage', MeshMessageSchema);
