const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const EmergencyContactSchema = new mongoose.Schema({
  name: { type: String, required: true },
  phone: { type: String, required: true },
  relationship: { type: String, default: 'Family' },
});

const MedicalInfoSchema = new mongoose.Schema({
  bloodGroup: { type: String, enum: ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-', 'Unknown'], default: 'Unknown' },
  allergies: [{ type: String }],
  chronicConditions: [{ type: String }],
  medications: [{ type: String }],
  notes: { type: String, default: '' },
});

const UserSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true },
    email: { type: String, required: true, unique: true, lowercase: true, trim: true },
    phone: { type: String, required: true, unique: true, trim: true },
    password: { type: String, required: true, minlength: 6 },
    role: { type: String, enum: ['user', 'rescue_team', 'admin'], default: 'user' },
    meshId: { type: String, unique: true, sparse: true },
    avatar: { type: String, default: '' },
    emergencyContacts: [EmergencyContactSchema],
    medicalInfo: { type: MedicalInfoSchema, default: () => ({}) },
    lastLocation: {
      latitude: { type: Number },
      longitude: { type: Number },
      updatedAt: { type: Date },
    },
    isOnline: { type: Boolean, default: false },
    availabilityStatus: {
      type: String,
      enum: ['AVAILABLE', 'BUSY', 'OFFLINE'],
      default: 'OFFLINE',
    },
    helpPoints: { type: Number, default: 0, min: 0 },
    rescuesCompleted: { type: Number, default: 0, min: 0 },
    isActive: { type: Boolean, default: true },
    resetPasswordToken: String,
    resetPasswordExpire: Date,
  },
  { timestamps: true }
);

// Encrypt password using bcrypt before saving
UserSchema.pre('save', async function (next) {
  if (!this.isModified('password')) {
    return next();
  }
  const salt = await bcrypt.genSalt(10);
  this.password = await bcrypt.hash(this.password, salt);
  next();
});

// Match user entered password to hashed password in database
UserSchema.methods.matchPassword = async function (enteredPassword) {
  return await bcrypt.compare(enteredPassword, this.password);
};

module.exports = mongoose.model('User', UserSchema);
