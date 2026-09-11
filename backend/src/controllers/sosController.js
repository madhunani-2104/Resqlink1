const SosAlert = require('../models/SosAlert');
const User = require('../models/User');
const HelpReward = require('../models/HelpReward');
const { predictEmergencyRisk } = require('../utils/riskPredictor');

const emitSosStatus = (io, alert) => {
  if (!io || !alert) return;

  const payload = alert.toObject ? alert.toObject() : alert;
  const victimId = alert.userId?._id || alert.userId;

  io.to('rescue_team').emit('sos_status_updated', payload);
  io.to('admin').emit('sos_status_updated', payload);

  if (victimId) {
    io.to(`user:${victimId.toString()}`).emit(
      'sos_status_updated',
      payload,
    );
  }
};

const findSosAlertByParam = async (idOrSosId) => {
  const query = idOrSosId.match(/^[0-9a-fA-F]{24}$/)
    ? {
        $or: [
          { _id: idOrSosId },
          { sosId: idOrSosId },
        ],
      }
    : {
        sosId: idOrSosId,
      };

  return SosAlert.findOne(query);
};

// ============================================================
// CREATE SOS
// POST /api/sos
// ============================================================

const createSosAlert = async (req, res, next) => {
  try {
    const {
      sosId,
      eventId,
      messageId,
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
      return res.status(404).json({
        success: false,
        message: 'User not found',
      });
    }

    // ----------------------------------------------------------
    // Validate GPS
    // ----------------------------------------------------------

    const hasValidCoordinate = (
      value,
      min,
      max,
    ) =>
      typeof value === 'number' &&
      Number.isFinite(value) &&
      value >= min &&
      value <= max;

    if (
      !hasValidCoordinate(latitude, -90, 90) ||
      !hasValidCoordinate(longitude, -180, 180)
    ) {
      return res.status(400).json({
        success: false,
        message:
          'A valid current GPS latitude and longitude are required for SOS.',
      });
    }

    // ----------------------------------------------------------
    // Normalize values
    // ----------------------------------------------------------

    const normalizedAltitude =
      typeof altitude === 'number' &&
      Number.isFinite(altitude)
        ? altitude
        : 0;

    const normalizedAccuracy =
      typeof accuracy === 'number' &&
      Number.isFinite(accuracy) &&
      accuracy >= 0
        ? accuracy
        : 0;

    const generatedSosId =
      sosId ||
      `SOS-${Date.now()}-${Math.floor(
        Math.random() * 1000,
      )}`;

    const generatedEventId = eventId || generatedSosId;
    const generatedMessageId = messageId || generatedEventId;

    // ----------------------------------------------------------
    // Prevent duplicate SOS
    // ----------------------------------------------------------

    const existingAlert =
      await SosAlert.findOne({
        $or: [
          { sosId: generatedSosId },
          { eventId: generatedEventId },
          { messageId: generatedMessageId },
        ],
      });

    if (existingAlert) {
      return res.status(200).json({
        success: true,
        data: existingAlert,
        duplicate: true,
      });
    }

    // ----------------------------------------------------------
    // Risk prediction
    // ----------------------------------------------------------

    const riskPrediction =
      predictEmergencyRisk({
        severity: severity || 'CRITICAL',
        notes: notes || '',
        latitude,
        longitude,
        accuracy: normalizedAccuracy,
      });

    // ----------------------------------------------------------
    // Create SOS
    // ----------------------------------------------------------

    const sosAlert = await SosAlert.create({
      sosId: generatedSosId,

      eventId: generatedEventId,

      messageId: generatedMessageId,

      userId: user._id,

      userName: user.name,

      userPhone: user.phone,

      medicalInfoSummary: {
        bloodGroup:
          user.medicalInfo?.bloodGroup ||
          'Unknown',

        allergies:
          user.medicalInfo?.allergies ||
          [],

        chronicConditions:
          user.medicalInfo?.chronicConditions ||
          [],

        notes:
          user.medicalInfo?.notes ||
          '',
      },

      location: {
        latitude,
        longitude,
        altitude: normalizedAltitude,
        accuracy: normalizedAccuracy,
        address: address || '',
      },

      batteryLevel:
        typeof batteryLevel === 'number'
          ? batteryLevel
          : 100,

      severity:
        severity || 'CRITICAL',

      riskLevel:
        riskPrediction.riskLevel,

      riskScore:
        riskPrediction.riskScore,

      riskReason:
        riskPrediction.reason,

      riskPredictedAt:
        riskPrediction.predictedAt,

      notes:
        notes || '',

      isMeshRelayed:
        Boolean(isMeshRelayed),

      relayHops:
        relayHops || 0,

      meshRelayNodes:
        meshRelayNodes || [],
    });

    // ----------------------------------------------------------
    // Update user location
    // ----------------------------------------------------------

    user.lastLocation = {
      latitude,
      longitude,
      updatedAt: new Date(),
    };

    await user.save();

    // ----------------------------------------------------------
    // Socket.IO
    // ----------------------------------------------------------

    const io = req.app.get('socketio');

    if (io) {
      // Rescue teams
      io.to('rescue_team').emit(
        'new_sos_alert',
        sosAlert,
      );

      // Admin
      io.to('admin').emit(
        'new_sos_alert',
        sosAlert,
      );

      // --------------------------------------------------------
      // Emergency contacts who also have ResQ accounts
      // --------------------------------------------------------

      const contactPhones =
        (user.emergencyContacts || [])
          .map(
            (contact) => contact.phone,
          )
          .filter(Boolean);

      if (contactPhones.length > 0) {
        const contactUsers =
          await User.find({
            phone: {
              $in: contactPhones,
            },

            _id: {
              $ne: user._id,
            },

            isActive: true,
          }).select('_id');

        for (
          const contactUser of contactUsers
        ) {
          io.to(
            `user:${contactUser._id.toString()}`,
          ).emit(
            'sos_emergency_alert',
            sosAlert,
          );
        }
      }
    }

    // ----------------------------------------------------------
    // Response
    // ----------------------------------------------------------

    return res.status(201).json({
      success: true,
      data: sosAlert,
    });
  } catch (error) {
    next(error);
  }
};

// ============================================================
// GET ACTIVE SOS
// GET /api/sos/active
// ============================================================

const getActiveSosAlerts = async (
  req,
  res,
  next,
) => {
  try {
    const alerts =
      await SosAlert.find({
        status: {
          $in: [
            'ACTIVE',
            'ACKNOWLEDGED',
          ],
        },
      })
        .sort({
          riskScore: -1,
          createdAt: -1,
        })
        .populate(
          'userId',
          'name phone medicalInfo',
        );

    return res.json({
      success: true,
      count: alerts.length,
      data: alerts,
    });
  } catch (error) {
    next(error);
  }
};

// ============================================================
// ACKNOWLEDGE SOS
// PUT /api/sos/:id/acknowledge
// ============================================================

const acknowledgeSosAlert = async (
  req,
  res,
  next,
) => {
  try {
    const alert =
      await findSosAlertByParam(
        req.params.id,
      );

    if (!alert) {
      return res.status(404).json({
        success: false,
        message: 'SOS Alert not found',
      });
    }

    alert.status = 'ACKNOWLEDGED';

    alert.respondedBy =
      req.user._id;

    alert.acknowledgedAt =
      new Date();

    await alert.save();

    const io =
      req.app.get('socketio');

    emitSosStatus(io, alert);

    return res.json({
      success: true,
      data: alert,
    });
  } catch (error) {
    next(error);
  }
};

// ============================================================
// RESOLVE SOS
// PUT /api/sos/:id/resolve
// ============================================================

const resolveSosAlert = async (
  req,
  res,
  next,
) => {
  try {
    const alert =
      await findSosAlertByParam(
        req.params.id,
      );

    if (!alert) {
      return res.status(404).json({
        success: false,
        message: 'SOS Alert not found',
      });
    }

    // ----------------------------------------------------------
    // Assign helper if nobody acknowledged yet
    // ----------------------------------------------------------

    if (!alert.respondedBy) {
      alert.respondedBy =
        req.user._id;

      alert.acknowledgedAt =
        alert.acknowledgedAt ||
        new Date();
    }

    const helperId =
      alert.respondedBy;

    // ----------------------------------------------------------
    // Prevent self reward
    // ----------------------------------------------------------

    if (
      helperId.toString() ===
      alert.userId.toString()
    ) {
      return res.status(403).json({
        success: false,
        message:
          'A user cannot receive rescue points for their own SOS',
      });
    }

    const wasAlreadyRescued =
      alert.status === 'RESCUED';

    alert.status = 'RESCUED';

    alert.resolvedAt =
      alert.resolvedAt ||
      new Date();

    await alert.save();

    // ----------------------------------------------------------
    // Reward
    // ----------------------------------------------------------

    const configuredPoints =
      Number.parseInt(
        process.env.RESCUE_HELP_POINTS ||
          '10',
        10,
      );

    const rewardPoints =
      Number.isFinite(
        configuredPoints,
      ) &&
      configuredPoints > 0
        ? configuredPoints
        : 10;

    let rewardCreated = false;

    if (!wasAlreadyRescued) {
      try {
        await HelpReward.create({
          sosId: alert._id,
          helperId,
          points: rewardPoints,
        });

        await User.findByIdAndUpdate(
          helperId,
          {
            $inc: {
              helpPoints:
                rewardPoints,

              rescuesCompleted: 1,
            },
          },
        );

        rewardCreated = true;
      } catch (rewardError) {
        if (
          rewardError?.code !==
          11000
        ) {
          throw rewardError;
        }
      }
    }

    // ----------------------------------------------------------
    // Get helper
    // ----------------------------------------------------------

    const helper =
      await User.findById(
        helperId,
      ).select(
        '_id name helpPoints rescuesCompleted',
      );

    // ----------------------------------------------------------
    // Socket update
    // ----------------------------------------------------------

    const io =
      req.app.get('socketio');

    if (io) {
      emitSosStatus(io, alert);
      io.to(
        `user:${helperId.toString()}`,
      ).emit(
        'leaderboard_updated',
        {
          userId: helperId,

          helpPoints:
            helper?.helpPoints || 0,

          rescuesCompleted:
            helper?.rescuesCompleted ||
            0,

          rewardCreated,

          pointsAwarded:
            rewardCreated
              ? rewardPoints
              : 0,

          sosId: alert.sosId,
        },
      );
    }

    return res.json({
      success: true,

      data: alert,

      reward: {
        awarded: rewardCreated,

        points:
          rewardCreated
            ? rewardPoints
            : 0,

        helperId,

        helpPoints:
          helper?.helpPoints || 0,

        rescuesCompleted:
          helper?.rescuesCompleted || 0,
      },
    });
  } catch (error) {
    next(error);
  }
};

// ============================================================
// CANCEL SOS
// PUT /api/sos/:id/cancel
// ============================================================

const cancelSosAlert = async (
  req,
  res,
  next,
) => {
  try {
    const alert =
      await findSosAlertByParam(
        req.params.id,
      );

    if (!alert) {
      return res.status(404).json({
        success: false,
        message: 'SOS Alert not found',
      });
    }

    // ----------------------------------------------------------
    // User can cancel only their own SOS
    // ----------------------------------------------------------

    if (
      alert.userId.toString() !==
        req.user._id.toString() &&
      req.user.role === 'user'
    ) {
      return res.status(403).json({
        success: false,
        message:
          'Not authorized to cancel this alert',
      });
    }

    alert.status = 'CANCELLED';

    alert.resolvedAt =
      new Date();

    await alert.save();

    // ----------------------------------------------------------
    // Socket update
    // ----------------------------------------------------------

    const io =
      req.app.get('socketio');

    emitSosStatus(io, alert);

    return res.json({
      success: true,
      data: alert,
    });
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