const logger = require('../config/logger');
const jwt = require('jsonwebtoken');
const User = require('../models/User');

const JWT_SECRET = process.env.JWT_SECRET || 'resq_emergency_secret_key_2026_jwt_token';

const verifySocketRole = async (token, allowedRoles) => {
  if (!token) return null;
  const decoded = jwt.verify(token, JWT_SECRET);
  const user = await User.findById(decoded.id).select('role');
  return user && allowedRoles.includes(user.role) ? user : null;
};

const verifySocketUser = async (token) => {
  if (!token) return null;
  const decoded = jwt.verify(token, JWT_SECRET);
  return User.findById(decoded.id).select('_id role name');
};

const setupSockets = (io) => {
  const activeCalls = new Map();

  const getCall = (callId) => {
    if (!callId || typeof callId !== 'string') return null;
    return activeCalls.get(callId) || null;
  };

  const isCallParticipant = (call, userId) =>
    Boolean(call && userId && (call.callerId === userId || call.calleeId === userId));

  const otherParticipant = (call, userId) =>
    call.callerId === userId ? call.calleeId : call.callerId;

  const validateTarget = async (userId, senderId) => {
    if (!userId || !senderId || userId === senderId) return null;
    let user = await User.findById(userId).select('_id name role meshId');
    if (!user) user = await User.findOne({ meshId: userId }).select('_id name role meshId');
    if (!user || user._id.toString() === senderId) return null;
    return user;
  };

  io.on('connection', (socket) => {
    logger.info(`Socket Connected: ${socket.id}`);

    socket.on('join_room', (roomId) => {
      if (typeof roomId !== 'string' || !roomId.trim()) return;
      socket.join(roomId);
      logger.info(`Socket ${socket.id} joined room ${roomId}`);
    });

    socket.on('join_user', async (token) => {
      try {
        const user = await verifySocketUser(token);
        if (!user) return;
        socket.userId = user._id.toString();
        socket.join(`user:${socket.userId}`);
        logger.info(`Socket ${socket.id} joined user room ${socket.userId}`);
      } catch (error) {
        logger.warn(`Socket ${socket.id} failed user join authorization`);
      }
    });

    socket.on('join_rescue_team', async (token) => {
      try {
        const user = await verifySocketRole(token, ['rescue_team']);
        if (!user) return;
        socket.join('rescue_team');
        logger.info(`Socket ${socket.id} joined rescue_team room`);
      } catch (error) {
        logger.warn(`Socket ${socket.id} failed rescue_team join authorization`);
      }
    });

    socket.on('join_admin', async (token) => {
      try {
        const user = await verifySocketRole(token, ['admin']);
        if (!user) return;
        socket.join('admin');
        logger.info(`Socket ${socket.id} joined admin room`);
      } catch (error) {
        logger.warn(`Socket ${socket.id} failed admin join authorization`);
      }
    });

    // Authenticated one-to-one WebRTC signaling. Media never passes through Socket.IO.
    socket.on('call_invite', async (data = {}) => {
      try {
        if (!socket.userId) return;
        const recipientId = String(data.toUserId || '');
        const callId = String(data.callId || '');
        const callType = data.callType === 'video' ? 'video' : data.callType === 'audio' ? 'audio' : null;
        if (!callId || !callType) return;
        const recipient = await validateTarget(recipientId, socket.userId);
        if (!recipient) {
          socket.emit('call_rejected', { callId, reason: 'Invalid call recipient.' });
          return;
        }
        if (activeCalls.has(callId)) return;
        const recipientMongoId = recipient._id.toString();
        for (const call of activeCalls.values()) {
          if (call.callerId === socket.userId || call.calleeId === socket.userId || call.callerId === recipientMongoId || call.calleeId === recipientMongoId) {
            socket.emit('call_rejected', { callId, reason: 'User is already in another call.' });
            return;
          }
        }
        activeCalls.set(callId, { callerId: socket.userId, calleeId: recipientMongoId, callType });
        const caller = await User.findById(socket.userId).select('name');
        io.to(`user:${recipientMongoId}`).emit('call_invite', {
          callId,
          fromUserId: socket.userId,
          callerName: caller?.name || 'ResQ User',
          callType,
        });
      } catch (error) {
        logger.warn(`Call invite rejected: ${error.message}`);
      }
    });

    socket.on('call_response', (data = {}) => {
      if (!socket.userId) return;
      const callId = String(data.callId || '');
      const call = getCall(callId);
      if (!isCallParticipant(call, socket.userId)) return;
      const targetId = otherParticipant(call, socket.userId);
      if (data.accepted === true) {
        io.to(`user:${targetId}`).emit('call_response', { callId, accepted: true, fromUserId: socket.userId });
      } else {
        activeCalls.delete(callId);
        io.to(`user:${targetId}`).emit('call_rejected', { callId, reason: 'Call was rejected.' });
      }
    });

    const forwardSignal = (eventName) => (data = {}) => {
      if (!socket.userId) return;
      const callId = String(data.callId || '');
      const call = getCall(callId);
      if (!isCallParticipant(call, socket.userId)) return;
      const targetId = otherParticipant(call, socket.userId);
      if (!targetId) return;
      if (eventName === 'webrtc_ice_candidate' && !data.candidate) return;
      if (eventName !== 'webrtc_ice_candidate' && !data.sdp) return;
      io.to(`user:${targetId}`).emit(eventName, {
        ...data,
        callId,
        fromUserId: socket.userId,
      });
    };

    socket.on('webrtc_offer', forwardSignal('webrtc_offer'));
    socket.on('webrtc_answer', forwardSignal('webrtc_answer'));
    socket.on('webrtc_ice_candidate', forwardSignal('webrtc_ice_candidate'));

    socket.on('call_end', (data = {}) => {
      if (!socket.userId) return;
      const callId = String(data.callId || '');
      const call = getCall(callId);
      if (!isCallParticipant(call, socket.userId)) return;
      const targetId = otherParticipant(call, socket.userId);
      activeCalls.delete(callId);
      io.to(`user:${targetId}`).emit('call_end', { callId, fromUserId: socket.userId });
    });

    socket.on('update_location', (data) => {
      socket.broadcast.emit('user_location_updated', data);
    });

    socket.on('broadcast_mesh_packet', (packet) => {
      socket.broadcast.emit('mesh_packet_relayed', packet);
    });

    socket.on('disconnect', () => {
      if (socket.userId) {
        for (const [callId, call] of activeCalls.entries()) {
          if (!isCallParticipant(call, socket.userId)) continue;
          const targetId = otherParticipant(call, socket.userId);
          activeCalls.delete(callId);
          io.to(`user:${targetId}`).emit('call_peer_disconnected', { callId, fromUserId: socket.userId });
        }
      }
      logger.info(`Socket Disconnected: ${socket.id}`);
    });
  });
};

module.exports = setupSockets;
