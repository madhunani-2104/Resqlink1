const SosAlert = require('../models/SosAlert');
const User = require('../models/User');
const HelpReward = require('../models/HelpReward');
const { predictEmergencyRisk } = require('../utils/riskPredictor');

const findSosAlertByParam = async (idOrSosId) => {
  const query = idOrSosId.match(/^[0-9a-fA-F]{24}$/)
    ? { $or: [{ _id: idOrSosId }, { sosId: idOrSosId }] }
    : { sosId: idOrSosId };
  return SosAlert.findOne(query);
};

// @desc    Trigger/Create new SOS Alert
// @route   POST /api/sos
// @access  Private
const createSosAlert = async (req, res, next) => {
  try {
    const {
      sosId,
      latitude,
      longitude,
      altitude,
      accuracy,
      address,
      batteryLevel,
      severity,
      notes,
      isMeshRelayed,
      relayHops,
      meshRelayNodes,
    } = req.body;

    const user = await User.findById(req.user._id);
    if (!user) {
      return res.status(404).json({ success: false, message: 'User not found' });
    }

    const hasValidCoordinate = (value, min, max) =>
      typeof value === 'number' && Number.isFinite(value) && value >= min && value <= max;

    if (!hasValidCoordinate(latitude, -90, 90) || !hasValidCoordinate(longitude, -180, 180)) {
      return res.status(400).json({
        success: false,
        message: 'A valid current GPS latitude and longitude are required for SOS.',
      });
    }

    const normalizedAltitude = typeof altitude === 'number' && Number.isFinite(altitude) ? altitude : 0;
    const normalizedAccuracy = typeof accuracy === 'number' && Number.isFinite(accuracy) && accuracy >= 0
      ? accuracy
      : 0;

    const generatedSosId = sosId || `SOS-${Date.now()}-${Math.floor(Math.random() * 1000)}`;

    // The client may retry after an intermittent connection failure. Reuse the
    // existing SOS record instead of creating a duplicate emergency event.
    const existingAlert = await SosAlert.findOne({ sosId: generatedSosId });
    if (existingAlert) {
      return res.status(200).json({ success: true, data: existingAlert, duplicate: true });
    }

    // Run the local deterministic risk heuristic on the server. No external AI
    // service or internet connection is required for this calculation.
    const riskPrediction = predictEmergencyRisk({
      severity: severity || 'CRITICAL',
      riskLevel: riskPrediction.riskLevel,
      riskScore: riskPrediction.riskScore,
      riskReason: riskPrediction.riskReason,
      riskPredictedAt: riskPrediction.predictedAt,
      notes: notes || '',
      latitude,
      longitude,
      accuracy: normalizedAccuracy,
    });

    const sosAlert = await SosAlert.create({
      sosId: generatedSosId,
      userId: user._id,
      userName: user.name,
      userPhone: user.phone,
      medicalInfoSummary: {
        bloodGroup: user.medicalInfo?.bloodGroup || 'Unknown',
        allergies: user.medicalInfo?.allergies || [],
        chronicConditions: user.medicalInfo?.chronicConditions || [],
        notes: user.medicalInfo?.notes || '',
      },
      location: {
        latitude,
        longitude,
        altitude: normalizedAltitude,
        accuracy: normalizedAccuracy,
        address: address || '',
      },
      batteryLevel: batteryLevel || 100,
      severity: severity || 'CRITICAL',
      riskLevel: riskPrediction.riskLevel,
      riskScore: riskPrediction.riskScore,
      riskReason: riskPrediction.riskReason,
      riskPredictedAt: riskPrediction.predictedAt,
      notes: notes || '',
      isMeshRelayed: isMeshRelayed || false,
      relayHops: relayHops || 0,
      meshRelayNodes: meshRelayNodes || [],
    });

    // Update user location
    if (hasValidCoordinate(latitude, -90, 90) && hasValidCoordinate(longitude, -180, 180)) {
      user.lastLocation = { latitude, longitude, updatedAt: new Date() };
      await user.save();
    }

    // Emit the emergency event through the existing Socket.IO infrastructure.
    // Rescue/admin users receive every active SOS; registered emergency contacts
    // receive only the SOS addressed to them. Non-app contacts continue to use
    // the existing device SMS notification service on the client.
    const io = req.app.get('socketio');
    if (io) {
      io.to('rescue_team').emit('new_sos_alert', sosAlert);
      io.to('admin').emit('new_sos_alert', sosAlert);

      const contactPhones = (user.emergencyContacts || [])
        .map((contact) => contact.phone)
        .filter(Boolean);

      if (contactPhones.length > 0) {
        const contactUsers = await User.find({
          phone: { $in: contactPhones },
          _id: { $ne: user._id },
          isActive: true,
        }).select('_id');

        for (const contactUser of contactUsers) {
          io.to(`user:${contactUser._id.toString()}`).emit('sos_emergency_alert', sosAlert);
        }
      }
    }

    res.status(201).json({
      success: true,
      data: sosAlert,
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Get all active SOS alerts
// @route   GET /api/sos/active
// @access  Private (Responder/Admin/User)
const getActiveSosAlerts = async (req, res, next) => {
  try {
    const alerts = await SosAlert.find({ status: { $in: ['ACTIVE', 'ACKNOWLEDGED'] } })
      .sort({ riskScore: -1, createdAt: -1 })
      .populate('userId', 'name phone medicalInfo');

    res.json({
      success: true,
      count: alerts.length,
      data: alerts,
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Acknowledge SOS Alert (by Responder/Admin)
// @route   PUT /api/sos/:id/acknowledge
// @access  Private (Responder/Admin)
const acknowledgeSosAlert = async (req, res, next) => {
  try {
    const alert = await findSosAlertByParam(req.params.id);
    if (!alert) {
      return res.status(404).json({ success: false, message: 'SOS Alert not found' });
    }

    alert.status = 'ACKNOWLEDGED';
    alert.respondedBy = req.user._id;
    alert.acknowledgedAt = new Date();
    await alert.save();

    const io = req.app.get('socketio');
    if (io) {
      io.to('rescue_team').emit('sos_status_updated', alert);
      io.to('admin').emit('sos_status_updated', alert);
    }

    res.json({ success: true, data: alert });
  } catch (error) {
    next(error);
  }
};

// @desc    Resolve/Mark Rescued SOS Alert
// @route   PUT /api/sos/:id/resolve
// @access  Private (Responder/Admin/Owner)
const resolveSosAlert = async (req, res, next) => {
  try {
    const alert = await findSosAlertByParam(req.params.id);
    if (!alert) {
      return res.status(404).json({ success: false, message: 'SOS Alert not found' });
    }

    // The existing responder workflow is the authoritative help/rescue action.
    // If nobody acknowledged first, the authenticated resolver becomes the helper.
    if (!alert.respondedBy) {
      alert.respondedBy = req.user._id;
      alert.acknowledgedAt = alert.acknowledgedAt || new Date();
    }

    const helperId = alert.respondedBy;
    if (helperId.toString() === alert.userId.toString()) {
      return res.status(403).json({ success: false, message: 'A user cannot receive rescue points for their own SOS' });
    }

    const wasAlreadyRescued = alert.status === 'RESCUED';
    alert.status = 'RESCUED';
    alert.resolvedAt = alert.resolvedAt || new Date();
    await alert.save();

    // Reward creation is idempotent through the unique (SOS, helper) index.
    // The point value is configurable centrally and is never supplied by the client.
    const configuredPoints = Number.parseInt(process.env.RESCUE_HELP_POINTS || '10', 10);
    const rewardPoints = Number.isFinite(configuredPoints) && configuredPoints > 0 ? configuredPoints : 10;
    let rewardCreated = false;

    if (!wasAlreadyRescued) {
      try {
        await HelpReward.create({
          sosId: alert._id,
          helperId,
          points: rewardPoints,
        });
        await User.findByIdAndUpdate(helperId, {
          $inc: { helpPoints: rewardPoints, rescuesCompleted: 1 },
        });
        rewardCreated = true;
      } catch (rewardError) {
        // Duplicate reward requests are expected during retries/reconnects.
        if (rewardError?.code !== 11000) throw rewardError;
      }
    }

    const helper = await User.findById(helperId).select('_id name helpPoints rescuesCompleted');
    const io = req.app.get('socketio');
    if (io) {
      io.to('rescue_team').emit('sos_status_updated', alert);
      io.to('admin').emit('sos_status_updated', alert);
      io.to(`user:${helperId.toString()}`).emit('leaderboard_updated', {
        userId: helperId,
        helpPoints: helper?.helpPoints || 0,
        rescuesCompleted: helper?.rescuesCompleted || 0,
        rewardCreated,
        pointsAwarded: rewardCreated ? rewardPoints : 0,
        sosId: alert.sosId,
      });
    }

    res.json({
      success: true,
      data: alert,
      reward: {
        awarded: rewardCreated,
        points: rewardCreated ? rewardPoints : 0,
        helperId,
        helpPoints: helper?.helpPoints || 0,
        rescuesCompleted: helper?.rescuesCompleted || 0,
      },
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Cancel SOS Alert (by Owner)
// @route   PUT /api/sos/:id/cancel
// @access  Private
const cancelSosAlert = async (req, res, next) => {
  try {
    const alert = await findSosAlertByParam(req.params.id);
    if (!alert) {
      return res.status(404).json({ success: false, message: 'SOS Alert not found' });
    }

    if (alert.userId.toString() !== req.user._id.toString() && req.user.role === 'user') {
      return res.status(403).json({ success: false, message: 'Not authorized to cancel this alert' });
    }

    alert.status = 'CANCELLED';
    alert.resolvedAt = new Date();
    await alert.save();

    const io = req.app.get('socketio');
    if (io) {
      io.to('rescue_team').emit('sos_status_updated', alert);
      io.to('admin').emit('sos_status_updated', alert);
    }

    res.json({ success: true, data: alert });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  createSosAlert,
  getActiveSosAlerts,
  acknowledgeSosAlert,
  resolveSosAlert,
  cancelSosAlert,
};
