const mongoose = require('mongoose');

const SyncQueueSchema = new mongoose.Schema(
  {
    deviceId: { type: String, required: true },
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    dataType: {
      type: String,
      enum: ['SOS_ALERT', 'MESH_MESSAGE', 'USER_LOCATION', 'PROFILE_UPDATE'],
      required: true,
    },
    payload: { type: mongoose.Schema.Types.Mixed, required: true },
    syncedAt: { type: Date, default: Date.now },
  },
  { timestamps: true }
);

module.exports = mongoose.model('SyncQueue', SyncQueueSchema);
