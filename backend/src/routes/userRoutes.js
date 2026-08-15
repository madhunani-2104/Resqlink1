const express = require('express');
const router = express.Router();
const { updateProfile, updateLocation } = require('../controllers/userController');
const { getMyScore, getLeaderboard } = require('../controllers/scoreController');
const { protect } = require('../middleware/authMiddleware');

router.put('/profile', protect, updateProfile);
router.put('/location', protect, updateLocation);
router.get('/score', protect, getMyScore);
router.get('/leaderboard', protect, getLeaderboard);

module.exports = router;
