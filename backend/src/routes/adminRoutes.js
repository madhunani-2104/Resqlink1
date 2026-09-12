const express = require('express');
const router = express.Router();
const {
  getAdminStats,
  getAllUsers,
  updateUserRole,
} = require('../controllers/adminController');
const { protect } = require('../middleware/authMiddleware');
const { authorize } = require('../middleware/roleMiddleware');
const {
  getDispatchQueue,
  getResponders,
  assignSos,
  updateDispatchStatus,
  updateResponderAvailability,
} = require('../controllers/dispatchController');

router.get('/stats', protect, authorize('admin', 'rescue_team'), getAdminStats);
router.get('/users', protect, authorize('admin'), getAllUsers);
router.put('/user/:id/role', protect, authorize('admin'), updateUserRole);
router.get('/dispatch', protect, authorize('admin', 'rescue_team'), getDispatchQueue);
router.get('/responders', protect, authorize('admin', 'rescue_team'), getResponders);
router.put('/dispatch/:id/assign', protect, authorize('admin'), assignSos);
router.put('/dispatch/:id/status', protect, authorize('admin', 'rescue_team'), updateDispatchStatus);
router.put('/responder/availability', protect, authorize('rescue_team'), updateResponderAvailability);

module.exports = router;
