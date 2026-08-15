const User = require('../models/User');

// @desc    Update user profile & medical info & emergency contacts
// @route   PUT /api/user/profile
// @access  Private
const updateProfile = async (req, res, next) => {
  try {
    const user = await User.findById(req.user._id);
    if (!user) {
      return res.status(404).json({ success: false, message: 'User not found' });
    }

    const { name, phone, emergencyContacts, medicalInfo, avatar } = req.body;

    if (name) user.name = name;
    if (phone) user.phone = phone;
    if (avatar) user.avatar = avatar;
    if (emergencyContacts) user.emergencyContacts = emergencyContacts;
    if (medicalInfo) user.medicalInfo = { ...user.medicalInfo, ...medicalInfo };

    await user.save();

    res.json({
      success: true,
      message: 'Profile updated successfully',
      data: {
        _id: user._id,
        name: user.name,
        email: user.email,
        phone: user.phone,
        role: user.role,
        meshId: user.meshId,
        avatar: user.avatar,
        emergencyContacts: user.emergencyContacts,
        medicalInfo: user.medicalInfo,
      },
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Update user location
// @route   PUT /api/user/location
// @access  Private
const updateLocation = async (req, res, next) => {
  try {
    const { latitude, longitude } = req.body;
    if (latitude === undefined || longitude === undefined) {
      return res.status(400).json({ success: false, message: 'Latitude and Longitude are required' });
    }

    const user = await User.findByIdAndUpdate(
      req.user._id,
      {
        lastLocation: {
          latitude,
          longitude,
          updatedAt: new Date(),
        },
      },
      { new: true }
    ).select('-password');

    res.json({ success: true, data: user.lastLocation });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  updateProfile,
  updateLocation,
};
