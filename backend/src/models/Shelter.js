const mongoose = require('mongoose');

const ShelterSchema = new mongoose.Schema(
  {
    name: { type: String, required: true },
    address: { type: String, required: true },
    latitude: { type: Number, required: true },
    longitude: { type: Number, required: true },
    phone: { type: String, default: '' },
    capacity: { type: Number, required: true },
    currentOccupants: { type: Number, default: 0 },
    amenities: [{ type: String }], // e.g. ["Food", "Water", "First Aid", "Power", "Beds"]
    status: { type: String, enum: ['OPERATIONAL', 'FULL', 'CLOSED'], default: 'OPERATIONAL' },
    contactPerson: { type: String, default: '' },
  },
  { timestamps: true }
);

module.exports = mongoose.model('Shelter', ShelterSchema);
