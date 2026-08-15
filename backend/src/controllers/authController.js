const User = require('../models/User');
const { generateToken } = require('../config/jwt');

const RESCUE_ACCESS_CODE = process.env.RESCUE_TEAM_ACCESS_CODE || 'RESQ-TEAM-2026';

const formatAuthUser = (user) => ({
  _id: user._id,
  name: user.name,
  email: user.email,
  phone: user.phone,
  role: user.role,
  meshId: user.meshId,
  emergencyContacts: user.emergencyContacts,
  medicalInfo: user.medicalInfo,
  helpPoints: user.helpPoints || 0,
  rescuesCompleted: user.rescuesCompleted || 0,
  token: generateToken(user._id),
});

// @desc    Register a new user
// @route   POST /api/auth/register
// @access  Public
const registerUser = async (req, res, next) => {
  try {
    const { name, email, phone, password, role } = req.body;

    const userExists = await User.findOne({ $or: [{ email }, { phone }] });
    if (userExists) {
      return res.status(400).json({
        success: false,
        message: 'User already exists with this email or phone number',
      });
    }

    const meshId = `RESQ-${Math.random().toString(36).substring(2, 8).toUpperCase()}`;

    const user = await User.create({
      name,
      email,
      phone,
      password,
      role: role === 'admin' ? 'admin' : 'user',
      meshId,
    });

    if (user) {
      res.status(201).json({
        success: true,
        data: formatAuthUser(user),
      });
    } else {
      res.status(400).json({ success: false, message: 'Invalid user data' });
    }
  } catch (error) {
    next(error);
  }
};

// @desc    Auth user & get token
// @route   POST /api/auth/login
// @access  Public
const loginUser = async (req, res, next) => {
  try {
    const { email, password } = req.body;

    const user = await User.findOne({ email });
    if (user && (await user.matchPassword(password))) {
      user.isOnline = true;
      await user.save();

      res.json({
        success: true,
        data: formatAuthUser(user),
      });
    } else {
      res.status(401).json({ success: false, message: 'Invalid email or password' });
    }
  } catch (error) {
    next(error);
  }
};

// @desc    Register a rescue team account with an access code
// @route   POST /api/auth/rescue-register
// @access  Public
const rescueRegister = async (req, res, next) => {
  try {
    const { name, email, phone, password, accessCode } = req.body;

    if (!accessCode || accessCode !== RESCUE_ACCESS_CODE) {
      return res.status(403).json({ success: false, message: 'Invalid rescue team access code' });
    }

    const userExists = await User.findOne({ $or: [{ email }, { phone }] });
    if (userExists) {
      return res.status(400).json({
        success: false,
        message: 'User already exists with this email or phone number',
      });
    }

    const meshId = `TEAM-${Math.random().toString(36).substring(2, 8).toUpperCase()}`;

    const user = await User.create({
      name,
      email,
      phone,
      password,
      role: 'rescue_team',
      meshId,
    });

    res.status(201).json({ success: true, data: formatAuthUser(user) });
  } catch (error) {
    next(error);
  }
};

// @desc    Auth rescue team user & get token
// @route   POST /api/auth/rescue-login
// @access  Public
const rescueLogin = async (req, res, next) => {
  try {
    const { email, password } = req.body;

    const user = await User.findOne({ email });
    if (!user || user.role !== 'rescue_team' || !(await user.matchPassword(password))) {
      return res.status(401).json({ success: false, message: 'Invalid rescue team credentials' });
    }

    user.isOnline = true;
    await user.save();

    res.json({ success: true, data: formatAuthUser(user) });
  } catch (error) {
    next(error);
  }
};

// @desc    Forgot Password - Reset trigger
// @route   POST /api/auth/forgot-password
// @access  Public
const forgotPassword = async (req, res, next) => {
  try {
    const { email } = req.body;
    const user = await User.findOne({ email });

    if (!user) {
      return res.status(404).json({ success: false, message: 'User not found with that email' });
    }

    const resetToken = Math.floor(100000 + Math.random() * 900000).toString(); // 6 digit OTP
    user.resetPasswordToken = resetToken;
    user.resetPasswordExpire = Date.now() + 10 * 60 * 1000; // 10 minutes
    await user.save();

    res.json({
      success: true,
      message: 'Password reset code sent (simulated OTP generated)',
      resetCode: resetToken, // Returned for dev/testing ease
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Reset Password
// @route   POST /api/auth/reset-password
// @access  Public
const resetPassword = async (req, res, next) => {
  try {
    const { email, resetCode, newPassword } = req.body;
    const user = await User.findOne({
      email,
      resetPasswordToken: resetCode,
      resetPasswordExpire: { $gt: Date.now() },
    });

    if (!user) {
      return res.status(400).json({ success: false, message: 'Invalid or expired reset code' });
    }

    user.password = newPassword;
    user.resetPasswordToken = undefined;
    user.resetPasswordExpire = undefined;
    await user.save();

    res.json({ success: true, message: 'Password reset successful. You can now log in.' });
  } catch (error) {
    next(error);
  }
};

// @desc    Get current user profile
// @route   GET /api/auth/me
// @access  Private
const getMe = async (req, res, next) => {
  try {
    const user = await User.findById(req.user._id).select('-password');
    res.json({ success: true, data: user });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  registerUser,
  loginUser,
  rescueRegister,
  rescueLogin,
  forgotPassword,
  resetPassword,
  getMe,
};
