const User = require('../models/User');
const SosAlert = require('../models/SosAlert');
const MeshMessage = require('../models/MeshMessage');
const SafeZone = require('../models/SafeZone');
const Shelter = require('../models/Shelter');

// @desc    Get Admin Dashboard Stats & System Analytics
// @route   GET /api/admin/stats
// @access  Private (Admin/Responder)
const getAdminStats = async (req, res, next) => {
  try {
    const totalUsers = await User.countDocuments();
    const totalResponders = await User.countDocuments({ role: 'rescue_team' });
    const activeSosCount = await SosAlert.countDocuments({
      status: { $in: ['PENDING', 'ASSIGNED', 'ACTIVE', 'ACKNOWLEDGED'] },
    });
    const acknowledgedSosCount = await SosAlert.countDocuments({ status: 'ACKNOWLEDGED' });
    const rescuedSosCount = await SosAlert.countDocuments({
      status: { $in: ['RESOLVED', 'RESCUED'] },
    });
    const totalMeshPackets = await MeshMessage.countDocuments();
    const totalSafeZones = await SafeZone.countDocuments();
    const totalShelters = await Shelter.countDocuments();

    res.json({
      success: true,
      data: {
        totalUsers,
        totalResponders,
        activeSosCount,
        acknowledgedSosCount,
        rescuedSosCount,
        totalMeshPackets,
        totalSafeZones,
        totalShelters,
      },
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Get all users list for admin
// @route   GET /api/admin/users
// @access  Private (Admin)
const getAllUsers = async (req, res, next) => {
  try {
    const users = await User.find().select('-password').sort({ createdAt: -1 });
    res.json({ success: true, count: users.length, data: users });
  } catch (error) {
    next(error);
  }
};

// @desc    Change user role (e.g. promote to rescue_team/admin)
// @route   PUT /api/admin/user/:id/role
// @access  Private (Admin)
const updateUserRole = async (req, res, next) => {
  try {
    const { role } = req.body;
    if (!['user', 'rescue_team', 'admin'].includes(role)) {
      return res.status(400).json({ success: false, message: 'Invalid role' });
    }

    const user = await User.findByIdAndUpdate(req.params.id, { role }, { new: true }).select('-password');
    if (!user) {
      return res.status(404).json({ success: false, message: 'User not found' });
    }

    res.json({ success: true, data: user });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getAdminStats,
  getAllUsers,
  updateUserRole,
};
