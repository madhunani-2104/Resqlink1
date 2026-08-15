const mongoose = require('mongoose');

const SafeZoneSchema = new mongoose.Schema(
  {
    name: { type: String, required: true },
    description: { type: String, default: '' },
    latitude: { type: Number, required: true },
    longitude: { type: Number, required: true },
    radiusMeters: { type: Number, default: 500 },
    zoneType: {
      type: String,
      enum: ['SAFE_HAVEN', 'ASSEMBLY_POINT', 'MEDICAL_STATION', 'EVACUATION_ZONE'],
      default: 'SAFE_HAVEN',
    },
    status: { type: String, enum: ['OPEN', 'RESTRICTED', 'FULL'], default: 'OPEN' },
    contactPhone: { type: String, default: '' },
    capacity: { type: Number, default: 200 },
    currentOccupancy: { type: Number, default: 0 },
    createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  },
  { timestamps: true }
);

module.exports = mongoose.model('SafeZone', SafeZoneSchema);
