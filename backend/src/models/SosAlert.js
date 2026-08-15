const mongoose = require('mongoose');

const SosAlertSchema = new mongoose.Schema(
  {
    sosId: { type: String, required: true, unique: true },
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    userName: { type: String, required: true },
    userPhone: { type: String, required: true },
    medicalInfoSummary: {
      bloodGroup: { type: String },
      allergies: [{ type: String }],
      chronicConditions: [{ type: String }],
      notes: { type: String },
    },
    location: {
      latitude: { type: Number, required: true },
      longitude: { type: Number, required: true },
      altitude: { type: Number, default: 0 },
      accuracy: { type: Number, default: 0 },
      address: { type: String, default: '' },
    },
    batteryLevel: { type: Number, default: 100 },
    status: {
      type: String,
      enum: ['ACTIVE', 'ACKNOWLEDGED', 'RESCUED', 'CANCELLED'],
      default: 'ACTIVE',
    },
    severity: {
      type: String,
      enum: ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'],
      default: 'CRITICAL',
    },
    riskLevel: {
      type: String,
      enum: ['LOW', 'MEDIUM', 'HIGH'],
      default: null,
    },
    riskScore: { type: Number, min: 0, max: 100, default: null },
    riskReason: { type: String, default: '' },
    riskPredictedAt: { type: Date },
    notes: { type: String, default: '' },
    respondedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    isMeshRelayed: { type: Boolean, default: false },
    relayHops: { type: Number, default: 0 },
    meshRelayNodes: [{ type: String }],
    acknowledgedAt: { type: Date },
    resolvedAt: { type: Date },
  },
  { timestamps: true }
);

SosAlertSchema.index({ 'location.latitude': 1, 'location.longitude': 1 });

module.exports = mongoose.model('SosAlert', SosAlertSchema);
