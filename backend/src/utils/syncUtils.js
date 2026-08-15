const SosAlert = require('../models/SosAlert');
const MeshMessage = require('../models/MeshMessage');
const User = require('../models/User');

async function processSyncedPayload(dataType, payload, userId) {
  switch (dataType) {
    case 'SOS_ALERT': {
      const existing = await SosAlert.findOne({ sosId: payload.sosId });
      if (!existing) {
        const newSos = new SosAlert({
          ...payload,
          userId: userId || payload.userId,
        });
        await newSos.save();
        return newSos;
      }
      return existing;
    }
    case 'MESH_MESSAGE': {
      const existing = await MeshMessage.findOne({ packetId: payload.packetId });
      if (!existing) {
        const newMsg = new MeshMessage(payload);
        await newMsg.save();
        return newMsg;
      }
      return existing;
    }
    case 'USER_LOCATION': {
      if (userId && payload.latitude && payload.longitude) {
        await User.findByIdAndUpdate(userId, {
          lastLocation: {
            latitude: payload.latitude,
            longitude: payload.longitude,
            updatedAt: new Date(),
          },
        });
      }
      return { success: true };
    }
    default:
      throw new Error(`Unsupported sync dataType: ${dataType}`);
  }
}

module.exports = { processSyncedPayload };
