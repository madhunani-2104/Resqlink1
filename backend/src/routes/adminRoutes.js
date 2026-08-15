const express = require('express');
const router = express.Router();
const {
  getAdminStats,
  getAllUsers,
  updateUserRole,
} = require('../controllers/adminController');
const { protect } = require('../middleware/authMiddleware');
const { authorize } = require('../middleware/roleMiddleware');

router.get('/stats', protect, authorize('admin', 'rescue_team'), getAdminStats);
router.get('/users', protect, authorize('admin'), getAllUsers);
router.put('/user/:id/role', protect, authorize('admin'), updateUserRole);

module.exports = router;
