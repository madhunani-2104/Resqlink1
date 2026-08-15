const SafeZone = require('../models/SafeZone');
const Shelter = require('../models/Shelter');
const SosAlert = require('../models/SosAlert');
const User = require('../models/User');

// @desc    Get all map layers data (Safe Zones, Shelters, Active SOS Victims, Responders)
// @route   GET /api/map/layers
// @access  Private
const getMapLayers = async (req, res, next) => {
  try {
    const safeZones = await SafeZone.find();
    const shelters = await Shelter.find();
    const activeSos = await SosAlert.find({ status: { $in: ['ACTIVE', 'ACKNOWLEDGED'] } });
    
    // Responders active location
    const responders = await User.find({
      role: { $in: ['rescue_team', 'admin'] },
      'lastLocation.latitude': { $ne: null },
    }).select('name phone role lastLocation isOnline');

    res.json({
      success: true,
      data: {
        safeZones,
        shelters,
        victims: activeSos,
        responders,
      },
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Create new Safe Zone
// @route   POST /api/map/safe-zone
// @access  Private (Admin/Responder)
const createSafeZone = async (req, res, next) => {
  try {
    const { name, description, latitude, longitude, radiusMeters, zoneType, status, contactPhone, capacity } =
      req.body;

    const safeZone = await SafeZone.create({
      name,
      description,
      latitude,
      longitude,
      radiusMeters: radiusMeters || 500,
      zoneType: zoneType || 'SAFE_HAVEN',
      status: status || 'OPEN',
      contactPhone,
      capacity: capacity || 200,
      createdBy: req.user._id,
    });

    res.status(201).json({ success: true, data: safeZone });
  } catch (error) {
    next(error);
  }
};

// @desc    Create new Shelter
// @route   POST /api/map/shelter
// @access  Private (Admin/Responder)
const createShelter = async (req, res, next) => {
  try {
    const { name, address, latitude, longitude, phone, capacity, amenities, status, contactPerson } = req.body;

    const shelter = await Shelter.create({
      name,
      address,
      latitude,
      longitude,
      phone,
      capacity,
      amenities: amenities || ['Food', 'Water', 'First Aid'],
      status: status || 'OPERATIONAL',
      contactPerson,
    });

    res.status(201).json({ success: true, data: shelter });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getMapLayers,
  createSafeZone,
  createShelter,
};
