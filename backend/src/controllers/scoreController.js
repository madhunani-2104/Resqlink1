const User = require('../models/User');

const getMyScore = async (req, res, next) => {
  try {
    const user = await User.findById(req.user._id).select('name role helpPoints rescuesCompleted');
    if (!user) return res.status(404).json({ success: false, message: 'User not found' });

    res.json({
      success: true,
      data: {
        userId: user._id,
        name: user.name,
        role: user.role,
        helpPoints: user.helpPoints || 0,
        rescuesCompleted: user.rescuesCompleted || 0,
      },
    });
  } catch (error) {
    next(error);
  }
};

const getLeaderboard = async (req, res, next) => {
  try {
    const users = await User.find({ isActive: true })
      .select('name role helpPoints rescuesCompleted')
      .sort({ helpPoints: -1, rescuesCompleted: -1, name: 1 });

    res.json({
      success: true,
      data: users.map((user, index) => ({
        rank: index + 1,
        userId: user._id,
        name: user.name,
        role: user.role,
        helpPoints: user.helpPoints || 0,
        rescuesCompleted: user.rescuesCompleted || 0,
      })),
    });
  } catch (error) {
    next(error);
  }
};

module.exports = { getMyScore, getLeaderboard };
