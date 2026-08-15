const express = require('express');
const router = express.Router();
const {
  createSosAlert,
  getActiveSosAlerts,
  acknowledgeSosAlert,
  resolveSosAlert,
  cancelSosAlert,
} = require('../controllers/sosController');
const { protect } = require('../middleware/authMiddleware');
const { authorize } = require('../middleware/roleMiddleware');

router.post('/', protect, createSosAlert);
router.get('/active', protect, getActiveSosAlerts);
router.put('/:id/acknowledge', protect, authorize('rescue_team', 'admin'), acknowledgeSosAlert);
router.put('/:id/resolve', protect, authorize('rescue_team', 'admin'), resolveSosAlert);
router.put('/:id/cancel', protect, cancelSosAlert);

module.exports = router;
