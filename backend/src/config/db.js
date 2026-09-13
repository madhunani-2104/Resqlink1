const mongoose = require('mongoose');
const logger = require('./logger');

const connectDB = async () => {
  const mongoUri = process.env.MONGO_URI || process.env.MONGODB_URI;

  if (!mongoUri) {
    const error = new Error(
      'MongoDB connection string is not configured. Set MONGO_URI in the environment.'
    );
    logger.error(`[STARTUP] ${error.message}`);
    throw error;
  }

  try {
    const conn = await mongoose.connect(mongoUri, {
      serverSelectionTimeoutMS: 10000,
      connectTimeoutMS: 10000,
    });
    logger.info(`[STARTUP] MongoDB connected: ${conn.connection.host}`);
    return conn;
  } catch (error) {
    logger.error(`[STARTUP] MongoDB connection failed: ${error.message}`);
    throw error;
  }
};

module.exports = connectDB;
