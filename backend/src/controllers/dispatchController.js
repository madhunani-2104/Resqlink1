const User = require('../models/User');
const SosAlert = require('../models/SosAlert');
const { canTransition, isDispatchableStatus } = require('../utils/dispatchUtils');

const emitDispatchUpdate = (req, alert) => {
  const io = req.app.get('socketio');
  if (!io) return;
  const payload = alert.toObject ? alert.toObject() : alert;
  io.to('admin').emit('dispatch_updated', payload);
  io.to('rescue_team').emit('dispatch_updated', payload);
  if (alert.userId) io.to(`user:${alert.userId.toString()}`).emit('sos_status_updated', payload);
  if (alert.assignedResponder) {
    io.to(`user:${alert.assignedResponder.toString()}`).emit('dispatch_assigned', payload);
  }
};

const getDispatchQueue = async (req, res, next) => {
  try {
    const alerts = await SosAlert.find({ status: { $in: ['PENDING', 'ASSIGNED', 'ACKNOWLEDGED', 'ACTIVE'] } })
      .sort({ severity: -1, createdAt: 1 })
      .populate('assignedResponder', 'name phone role availabilityStatus isOnline')
      .populate('userId', 'name phone lastLocation medicalInfo');
    res.json({ success: true, count: alerts.length, data: alerts });
  } catch (error) {
    next(error);
  }
};

const getResponders = async (req, res, next) => {
  try {
    const responders = await User.find({ role: 'rescue_team', isActive: true })
      .select('_id name phone role availabilityStatus isOnline lastLocation helpPoints rescuesCompleted')
      .sort({ availabilityStatus: 1, name: 1 });
    res.json({ success: true, count: responders.length, data: responders });
  } catch (error) {
    next(error);
  }
};

const assignSos = async (req, res, next) => {
  try {
    const responderId = String(req.body.responderId || '');
    if (!responderId) return res.status(400).json({ success: false, message: 'responderId is required' });

    const responder = await User.findOneAndUpdate(
      { _id: responderId, role: 'rescue_team', isActive: true, availabilityStatus: 'AVAILABLE' },
      { availabilityStatus: 'BUSY', isOnline: true },
      { new: true },
    );
    if (!responder) return res.status(409).json({ success: false, message: 'Responder is not available' });

    const alert = await SosAlert.findOneAndUpdate(
      {
        $or: [{ _id: req.params.id }, { sosId: req.params.id }],
        status: { $in: ['PENDING', 'ACTIVE'] },
        assignedResponder: { $exists: false },
      },
      {
        $set: {
          assignedResponder: responder._id,
          respondedBy: responder._id,
          assignedAt: new Date(),
          dispatchUpdatedAt: new Date(),
          status: 'ASSIGNED',
        },
      },
      { new: true },
    );
    if (!alert) {
      await User.findByIdAndUpdate(responder._id, { availabilityStatus: 'AVAILABLE' });
      return res.status(409).json({ success: false, message: 'SOS cannot be assigned in its current state' });
    }
    emitDispatchUpdate(req, alert);
    res.json({ success: true, data: alert });
  } catch (error) {
    next(error);
  }
};

const updateDispatchStatus = async (req, res, next) => {
  try {
    const nextStatus = String(req.body.status || '').toUpperCase();
    if (!['ACKNOWLEDGED', 'RESOLVED', 'CANCELLED'].includes(nextStatus)) {
      return res.status(400).json({ success: false, message: 'Invalid dispatch status' });
    }

    const alert = await SosAlert.findOne({ $or: [{ _id: req.params.id }, { sosId: req.params.id }] });
    if (!alert) return res.status(404).json({ success: false, message: 'SOS alert not found' });
    if (!canTransition(alert.status, nextStatus)) {
      return res.status(409).json({ success: false, message: `Cannot transition from ${alert.status} to ${nextStatus}` });
    }

    const isResponder = req.user.role === 'rescue_team';
    if (isResponder && alert.assignedResponder && alert.assignedResponder.toString() !== req.user._id.toString()) {
      return res.status(403).json({ success: false, message: 'SOS is assigned to another responder' });
    }
    if (nextStatus === 'RESOLVED' && !alert.assignedResponder && isResponder) {
      return res.status(409).json({ success: false, message: 'SOS must be assigned before resolution' });
    }

    alert.status = nextStatus;
    alert.dispatchUpdatedAt = new Date();
    if (nextStatus === 'ACKNOWLEDGED') alert.acknowledgedAt = new Date();
    if (nextStatus === 'RESOLVED' || nextStatus === 'CANCELLED') alert.resolvedAt = new Date();
    await alert.save();

    if (alert.assignedResponder && ['RESOLVED', 'CANCELLED'].includes(nextStatus)) {
      await User.findByIdAndUpdate(alert.assignedResponder, { availabilityStatus: 'AVAILABLE' });
    }
    emitDispatchUpdate(req, alert);
    res.json({ success: true, data: alert });
  } catch (error) {
    next(error);
  }
};

const updateResponderAvailability = async (req, res, next) => {
  try {
    const availabilityStatus = String(req.body.availabilityStatus || '').toUpperCase();
    if (!['AVAILABLE', 'OFFLINE'].includes(availabilityStatus)) {
      return res.status(400).json({ success: false, message: 'Availability must be AVAILABLE or OFFLINE' });
    }
    const responder = await User.findOneAndUpdate(
      { _id: req.user._id, role: 'rescue_team' },
      { availabilityStatus, isOnline: availabilityStatus === 'AVAILABLE' },
      { new: true },
    ).select('_id name phone role availabilityStatus isOnline');
    if (!responder) return res.status(404).json({ success: false, message: 'Responder not found' });
    const io = req.app.get('socketio');
    if (io) io.to('admin').emit('responder_updated', responder);
    res.json({ success: true, data: responder });
  } catch (error) {
    next(error);
  }
};

module.exports = { getDispatchQueue, getResponders, assignSos, updateDispatchStatus, updateResponderAvailability };
