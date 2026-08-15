const mongoose = require('mongoose');

const HelpRewardSchema = new mongoose.Schema(
  {
    sosId: { type: mongoose.Schema.Types.ObjectId, ref: 'SosAlert', required: true },
    helperId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    points: { type: Number, required: true, min: 0 },
    rewardedAt: { type: Date, default: Date.now },
  },
  { timestamps: true }
);

// One helper can receive one reward for one emergency only.
HelpRewardSchema.index({ sosId: 1, helperId: 1 }, { unique: true });

module.exports = mongoose.model('HelpReward', HelpRewardSchema);
