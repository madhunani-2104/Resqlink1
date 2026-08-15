const express = require('express');
const router = express.Router();
const {
  getMapLayers,
  createSafeZone,
  createShelter,
} = require('../controllers/mapController');
const { protect } = require('../middleware/authMiddleware');
const { authorize } = require('../middleware/roleMiddleware');

router.get('/layers', protect, getMapLayers);
router.post('/safe-zone', protect, authorize('admin', 'rescue_team'), createSafeZone);
router.post('/shelter', protect, authorize('admin', 'rescue_team'), createShelter);

module.exports = router;
